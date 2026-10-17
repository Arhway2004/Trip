package domain

import (
	"encoding/json"
	"fmt"
	"math"
	"path"
	"strings"
)

// Plan is the editable web document. ImportedPackage remains the original,
// independent snapshot; a plan has its own optimistic concurrency version.
type Plan struct {
	Version int64 `json:"version"`
	ImportedPackage
}

func ValidatePlan(p *ImportedPackage) error {
	if _, err := ValidateImport(p); err != nil {
		return err
	}
	raw, err := json.Marshal(p.Document)
	if err != nil || len(raw) > 5<<20 {
		return ImportError("plan", "document must be at most 5 MB")
	}
	if len(p.Media) > 999 {
		return ImportError("media", "use at most 999 media files")
	}
	total := len(raw) + 1024*(len(p.Media)+1) // Reserve ZIP headers so exported files remain importable.
	for name, data := range p.Media {
		if !strings.HasPrefix(name, "media/") || path.Clean(name) != name || strings.Contains(name, "\\") || name == "media/" {
			return ImportError("media", "unsafe media path")
		}
		total += len(data)
	}
	if total > 20<<20 {
		return ImportError("media", "plan and photos must be at most 20 MB combined")
	}
	for _, section := range []string{"activities", "todos", "expenses", "exchangeRates", "places", "destinations", "photos"} {
		for _, value := range p.Document[section].([]any) {
			row := value.(map[string]any)
			for _, key := range []string{"isDone", "isLocked", "isOptional", "isPaid", "isShared", "isFavorite"} {
				if v := row[key]; v != nil {
					if _, ok := v.(bool); !ok {
						return ImportError(section+"."+key, "must be true or false")
					}
				}
			}
			for _, key := range []string{"title", "name", "notes", "caption", "country", "city", "category", "kind", "currency", "provider", "serviceNumber", "bookingReference", "bookingUrl", "ref", "activityRef", "address"} {
				if v := row[key]; v != nil {
					if _, ok := v.(string); !ok {
						return ImportError(section+"."+key, "must be text")
					}
				}
			}
			if section == "exchangeRates" {
				currency, _ := row["currency"].(string)
				rate, ok := row["rate"].(float64)
				if !currencyRe.MatchString(currency) || !ok || rate <= 0 || math.IsInf(rate, 0) || math.IsNaN(rate) {
					return ImportError("exchangeRates", "use a 3-letter currency and a positive exchange rate")
				}
			}
			if section == "photos" {
				name, ok := row["file"].(string)
				if !ok || p.Media[name] == nil {
					return ImportError("photos.file", "photo is missing from the media package")
				}
			}
		}
	}
	if banner, ok := p.Document["banner"].(map[string]any); ok {
		if name, ok := banner["image"].(string); ok && name != "" && p.Media[name] == nil {
			return ImportError("banner.image", "cover photo is missing")
		}
	}
	for _, section := range []string{"actuals", "connections"} {
		if p.Document[section] == nil {
			continue
		}
		rows, ok := p.Document[section].([]any)
		if !ok {
			return ImportError(section, "must be an array")
		}
		for i, value := range rows {
			row, ok := value.(map[string]any)
			field := fmt.Sprintf("%s[%d]", section, i)
			if !ok {
				return ImportError(field, "must be an object")
			}
			if section == "actuals" {
				if err := requiredText(row, "activityRef", field); err != nil {
					return err
				}
				date, err := requiredDate(row, "date", field)
				if err != nil {
					return err
				}
				endDate := date
				if row["endDate"] != nil {
					endDate, err = requiredDate(row, "endDate", field)
					if err != nil {
						return err
					}
				}
				if endDate.Before(date) {
					return ImportError(field+".endDate", "must not be before date")
				}
				start, a := importMinute(row["start"], false)
				end, b := importMinute(row["end"], true)
				if row["start"] != nil && !a || row["end"] != nil && !b {
					return ImportError(field, "use HH:mm for actual times")
				}
				if a && b && date.DaysUntil(endDate)*1440+end <= start {
					return ImportError(field+".end", "must be after arrival")
				}
				if notes := row["notes"]; notes != nil {
					if _, ok := notes.(string); !ok {
						return ImportError(field+".notes", "must be text")
					}
				}
			} else {
				for _, key := range []string{"key", "fromRef", "toRef", "signature", "mode"} {
					if err := requiredText(row, key, field); err != nil {
						return err
					}
				}
				mode := row["mode"].(string)
				if mode != "walking" && mode != "cycling" && mode != "driving" && mode != "train" && mode != "flight" && mode != "bus" {
					return ImportError(field+".mode", "unsupported travel mode")
				}
				for _, key := range []string{"durationMinutes", "bufferMinutes"} {
					if err := nonnegative(row, key, true, field); err != nil {
						return err
					}
				}
				if geometry := row["geometry"]; geometry != nil {
					points, ok := geometry.([]any)
					if !ok || len(points) > 3000 {
						return ImportError(field+".geometry", "use at most 3000 coordinate pairs")
					}
					for _, entry := range points {
						pair, ok := entry.([]any)
						if !ok || len(pair) != 2 {
							return ImportError(field+".geometry", "invalid coordinate pair")
						}
						if err := coordinates(map[string]any{"lat": pair[0], "lng": pair[1]}, true, field+".geometry"); err != nil {
							return err
						}
					}
				}
			}
		}
	}
	return nil
}
