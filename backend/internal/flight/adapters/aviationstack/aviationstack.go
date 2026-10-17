// Package aviationstack adapts the aviationstack real-time flights API.
// Its live feed only covers flights around their departure day.
package aviationstack

import (
	"context"
	"encoding/json"
	"net/http"
	"net/url"
	"strings"
	"time"

	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
)

type Provider struct {
	key     string
	baseURL string
	http    *http.Client
}

func New(apiKey string, client *http.Client) *Provider {
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	return &Provider{key: apiKey, baseURL: "https://api.aviationstack.com/v1", http: client}
}

// WithBaseURL points at a test server.
func (p *Provider) WithBaseURL(u string) *Provider { p.baseURL = u; return p }

func (p *Provider) Name() string     { return "aviationstack" }
func (p *Provider) FutureData() bool { return false }

func (p *Provider) Lookup(ctx context.Context, code string, icao bool, _ kernel.Date) ([]domain.Status, error) {
	q := url.Values{"access_key": {p.key}}
	if icao {
		q.Set("flight_icao", code)
	} else {
		q.Set("flight_iata", code)
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, p.baseURL+"/flights?"+q.Encode(), nil)
	if err != nil {
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	res, err := p.http.Do(req)
	if err != nil {
		// The error text contains the URL (and so the key): never return it.
		return nil, &app.ProviderError{Failure: app.FailureNetwork}
	}
	defer res.Body.Close()
	var body map[string]any
	if err := json.NewDecoder(http.MaxBytesReader(nil, res.Body, 4<<20)).Decode(&body); err != nil {
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	return Parse(body, p.Name())
}

// Parse reads a /flights answer (exported for tests).
func Parse(body map[string]any, provider string) ([]domain.Status, error) {
	if e, ok := body["error"].(map[string]any); ok {
		switch str(e["code"]) {
		case "invalid_access_key", "missing_access_key", "inactive_user":
			return nil, &app.ProviderError{Failure: app.FailureInvalidKey}
		case "usage_limit_reached", "rate_limit_reached":
			return nil, &app.ProviderError{Failure: app.FailureQuota}
		case "function_access_restricted", "https_access_restricted":
			return nil, &app.ProviderError{Failure: app.FailureNotInPlan}
		}
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	data, _ := body["data"].([]any)
	var out []domain.Status
	for _, x := range data {
		f, ok := x.(map[string]any)
		if !ok {
			continue
		}
		date := str(f["flight_date"])
		if _, err := kernel.ParseDate(date); err != nil {
			continue
		}
		fl, _ := f["flight"].(map[string]any)
		al, _ := f["airline"].(map[string]any)
		out = append(out, domain.Status{
			Code:      str(fl["iata"]),
			Date:      date,
			Phase:     phase(str(f["flight_status"])),
			Detail:    str(f["flight_status"]),
			Airline:   str(al["name"]),
			Departure: end(f["departure"]),
			Arrival:   end(f["arrival"]),
			Provider:  provider,
		})
	}
	return out, nil
}

func phase(s string) domain.Phase {
	switch s {
	case "scheduled", "active", "landed", "cancelled", "incident", "diverted":
		return domain.Phase(s)
	}
	return domain.PhaseUnknown
}

func end(v any) domain.End {
	m, _ := v.(map[string]any)
	e := domain.End{
		Airport: str(m["airport"]), IATA: str(m["iata"]), Terminal: str(m["terminal"]),
		Gate: str(m["gate"]), Baggage: str(m["baggage"]),
		Scheduled: wall(m["scheduled"]), Estimated: wall(m["estimated"]), Actual: wall(m["actual"]),
	}
	if d, ok := m["delay"].(float64); ok {
		n := int(d)
		e.Delay = &n
	}
	return e
}

// wall keeps the airport's wall-clock time ("2026-12-12T15:55"); aviationstack
// labels local times "+00:00", so the offset is ignored.
func wall(v any) string {
	s := str(v)
	if len(s) < 16 {
		return ""
	}
	return strings.Replace(s[:16], " ", "T", 1)
}

func str(v any) string {
	if s, ok := v.(string); ok {
		return strings.TrimSpace(s)
	}
	return ""
}
