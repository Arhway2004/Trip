package domain

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"wanderplan/backend/internal/kernel"
)

// ImportedPackage preserves the mobile document and media as the original snapshot.
// Editable web plans use a separate versioned copy; device sync is not enabled.
type ImportedPackage struct {
	Document map[string]any    `json:"document"`
	Media    map[string][]byte `json:"media"`
}

func ImportError(field, message string) error {
	return kernel.Validation("import.invalid", field+": "+message, kernel.FieldError{Field: field, Message: message})
}

// ValidateImport applies mobile's package rules before any data is written.
func ValidateImport(p *ImportedPackage) (Fields, error) {
	d := p.Document
	if d["format"] != "wanderplan.trip" {
		return Fields{}, ImportError("format", "not a WanderPlan trip")
	}
	v, ok := d["schemaVersion"].(float64)
	if !ok || v != float64(int(v)) || v < 1 {
		return Fields{}, ImportError("schemaVersion", "must be an integer from 1 to 3")
	}
	if v > 3 {
		return Fields{}, kernel.Validation("import.too_new", "This file was made by a newer version of WanderPlan")
	}
	t, ok := d["trip"].(map[string]any)
	if !ok {
		return Fields{}, ImportError("trip", "must be an object")
	}
	// Decode typed trip fields; malformed types must never silently become defaults.
	raw, _ := json.Marshal(t)
	var input struct {
		Title          string       `json:"title"`
		Description    *string      `json:"description"`
		StartDate      *string      `json:"startDate"`
		EndDate        *string      `json:"endDate"`
		DepartureTime  *string      `json:"departureTime"`
		DatesConfirmed bool         `json:"datesConfirmed"`
		TimeZone       string       `json:"timeZone"`
		TravelerCount  *int         `json:"travelerCount"`
		Currency       *string      `json:"currency"`
		TotalBudget    *float64     `json:"totalBudget"`
		TravelStyle    *TravelStyle `json:"travelStyle"`
		Stage          Stage        `json:"stage"`
	}
	if err := json.Unmarshal(raw, &input); err != nil {
		return Fields{}, ImportError("trip", "invalid field type: "+err.Error())
	}
	f := Fields{Title: input.Title, Description: input.Description, DepartureTime: input.DepartureTime, DatesConfirmed: input.DatesConfirmed, TimeZone: input.TimeZone, TravelerCount: 1, Currency: input.Currency, TotalBudget: input.TotalBudget, TravelStyle: input.TravelStyle, Stage: input.Stage}
	if input.TravelerCount != nil {
		f.TravelerCount = *input.TravelerCount
		if f.TravelerCount < 1 {
			return f, ImportError("trip.travelerCount", "must be between 1 and 999")
		}
	}
	for _, entry := range []struct {
		name  string
		value *string
		out   **kernel.Date
	}{{"startDate", input.StartDate, &f.StartDate}, {"endDate", input.EndDate, &f.EndDate}} {
		if entry.value != nil && *entry.value != "" {
			date, err := kernel.ParseDate(*entry.value)
			if err != nil {
				return f, ImportError("trip."+entry.name, "must be YYYY-MM-DD")
			}
			*entry.out = &date
		}
	}
	// Mobile ignores end dates when the start is undecided and defaults unknown enums.
	if f.StartDate == nil {
		f.EndDate = nil
	}
	if f.Stage != StageDreaming {
		f.Stage = StagePlanning
	}
	if f.TravelStyle != nil && !travelStyles[*f.TravelStyle] {
		f.TravelStyle = nil
	}
	f, err := Normalize(f)
	if err != nil {
		return f, err
	}
	// Validate child records before either repository writes the new aggregate.
	for _, section := range []string{"destinations", "photos", "todos", "activities", "expenses", "exchangeRates", "places"} {
		value := d[section]
		if value == nil {
			d[section] = []any{}
			continue
		}
		list, ok := value.([]any)
		if !ok {
			return f, ImportError(section, "must be an array")
		}
		for i, value := range list {
			row, ok := value.(map[string]any)
			path := fmt.Sprintf("%s[%d]", section, i)
			if !ok {
				return f, ImportError(path, "must be an object")
			}
			label, _ := row["title"].(string)
			if label == "" {
				label, _ = row["name"].(string)
			}
			if label != "" {
				path += " (" + label + ")"
			}
			switch section {
			case "activities":
				if err := requiredText(row, "title", path); err != nil {
					return f, err
				}
				date, err := requiredDate(row, "date", path)
				if err != nil {
					return f, err
				}
				endDate := date
				if row["endDate"] != nil {
					endDate, err = requiredDate(row, "endDate", path)
					if err != nil {
						return f, err
					}
					if endDate.Before(date) {
						return f, ImportError(path+".endDate", "must not be before date")
					}
				}
				if row["start"] != nil || row["end"] != nil {
					start, a := importMinute(row["start"], false)
					end, b := importMinute(row["end"], true)
					if !a || !b {
						return f, ImportError(path, "give both start and end as HH:mm, or leave both out when the time is undecided")
					}
					if date.DaysUntil(endDate)*1440+end <= start {
						return f, ImportError(path+".end", "must be after start (use endDate for overnight travel)")
					}
				}
				for _, key := range []string{"location", "destination"} {
					if place, ok := row[key].(map[string]any); ok {
						if err := coordinates(place, false, path+"."+key); err != nil {
							return f, err
						}
					}
				}
				if err := nonnegative(row, "cost", false, path); err != nil {
					return f, err
				}
			case "expenses":
				if err := requiredText(row, "title", path); err != nil {
					return f, err
				}
				if err := nonnegative(row, "amount", true, path); err != nil {
					return f, err
				}
				currency, _ := row["currency"].(string)
				if currency == "" && f.Currency != nil {
					currency = *f.Currency
				}
				if !currencyRe.MatchString(strings.ToUpper(currency)) {
					return f, ImportError(path+".currency", "a 3-letter currency is required")
				}
			case "todos":
				if err := requiredText(row, "title", path); err != nil {
					return f, err
				}
			case "places":
				if err := requiredText(row, "name", path); err != nil {
					return f, err
				}
				if err := coordinates(row, true, path); err != nil {
					return f, err
				}
			case "destinations":
				city, _ := row["city"].(string)
				country, _ := row["country"].(string)
				if strings.TrimSpace(city+country) == "" {
					return f, ImportError(path, "city or country is required")
				}
			}
			if section == "expenses" && row["date"] != nil {
				if _, err := requiredDate(row, "date", path); err != nil {
					return f, err
				}
			}
			for _, key := range []string{"dueDate"} {
				if row[key] != nil {
					if _, err := requiredDate(row, key, path); err != nil {
						return f, err
					}
				}
			}
		}
	}
	return f, nil
}
func requiredText(row map[string]any, key, path string) error {
	s, ok := row[key].(string)
	if !ok || strings.TrimSpace(s) == "" {
		return ImportError(path+"."+key, "is required")
	}
	return nil
}
func requiredDate(row map[string]any, key, path string) (kernel.Date, error) {
	s, _ := row[key].(string)
	d, err := kernel.ParseDate(s)
	if err != nil {
		return d, ImportError(path+"."+key, "must be YYYY-MM-DD")
	}
	return d, nil
}
func nonnegative(row map[string]any, key string, required bool, path string) error {
	if row[key] == nil && !required {
		return nil
	}
	n, ok := row[key].(float64)
	if !ok || n < 0 {
		return ImportError(path+"."+key, "must be a non-negative number")
	}
	return nil
}
func coordinates(row map[string]any, required bool, path string) error {
	if !required && row["lat"] == nil && row["lng"] == nil {
		return nil
	}
	lat, a := row["lat"].(float64)
	lng, b := row["lng"].(float64)
	if !a || !b || lat < -90 || lat > 90 || lng < -180 || lng > 180 {
		return ImportError(path, "lat and lng must be real WGS84 coordinates in range")
	}
	return nil
}
func importMinute(v any, end bool) (int, bool) {
	s, ok := v.(string)
	if !ok {
		return 0, false
	}
	if end && s == "24:00" {
		return 1440, true
	}
	t, err := time.Parse("15:04", s)
	return t.Hour()*60 + t.Minute(), err == nil
}
