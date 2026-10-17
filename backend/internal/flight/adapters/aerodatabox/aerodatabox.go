// Package aerodatabox adapts AeroDataBox "Flight Status (single day)":
// GET /flights/number/{flight}/{dateLocal}. It returns schedules for future
// dates too, so schedule changes are seen days ahead. Reachable through
// API.market (x-api-market-key) or RapidAPI (X-RapidAPI-Key).
package aerodatabox

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

type Marketplace string

const (
	APIMarket Marketplace = "apimarket"
	RapidAPI  Marketplace = "rapidapi"
)

type Provider struct {
	key     string
	via     Marketplace
	baseURL string
	http    *http.Client
}

func New(apiKey string, via Marketplace, client *http.Client) *Provider {
	if client == nil {
		client = &http.Client{Timeout: 20 * time.Second}
	}
	base := "https://prod.api.market/api/v1/aedbx/aerodatabox"
	if via == RapidAPI {
		base = "https://aerodatabox.p.rapidapi.com"
	}
	return &Provider{key: apiKey, via: via, baseURL: base, http: client}
}

func (p *Provider) WithBaseURL(u string) *Provider { p.baseURL = u; return p }
func (p *Provider) Name() string                   { return "aerodatabox" }
func (p *Provider) FutureData() bool               { return true }

func (p *Provider) Lookup(ctx context.Context, code string, _ bool, date kernel.Date) ([]domain.Status, error) {
	u := p.baseURL + "/flights/number/" + url.PathEscape(code) + "/" + date.String() + "?dateLocalRole=Departure&withAircraftImage=false&withLocation=false"
	req, err := http.NewRequestWithContext(ctx, http.MethodGet, u, nil)
	if err != nil {
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	if p.via == RapidAPI {
		req.Header.Set("X-RapidAPI-Key", p.key)
		req.Header.Set("X-RapidAPI-Host", "aerodatabox.p.rapidapi.com")
	} else {
		req.Header.Set("x-api-market-key", p.key)
	}
	res, err := p.http.Do(req)
	if err != nil {
		return nil, &app.ProviderError{Failure: app.FailureNetwork}
	}
	defer res.Body.Close()
	switch {
	case res.StatusCode == http.StatusNoContent || res.StatusCode == http.StatusNotFound:
		return nil, nil // no such flight on that date
	case res.StatusCode == http.StatusUnauthorized || res.StatusCode == http.StatusForbidden:
		return nil, &app.ProviderError{Failure: app.FailureInvalidKey}
	case res.StatusCode == http.StatusTooManyRequests:
		return nil, &app.ProviderError{Failure: app.FailureQuota}
	case res.StatusCode >= 300:
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	var flights []map[string]any
	if err := json.NewDecoder(http.MaxBytesReader(nil, res.Body, 4<<20)).Decode(&flights); err != nil {
		return nil, &app.ProviderError{Failure: app.FailureUnknown}
	}
	return Parse(flights, date, p.Name()), nil
}

// Parse reads FlightContract items (exported for tests).
func Parse(flights []map[string]any, date kernel.Date, provider string) []domain.Status {
	var out []domain.Status
	for _, f := range flights {
		al, _ := f["airline"].(map[string]any)
		dep, arr := end(f["departure"]), end(f["arrival"])
		d := date.String()
		if len(dep.Scheduled) >= 10 {
			d = dep.Scheduled[:10] // departure local date
		}
		out = append(out, domain.Status{
			Code:      strings.ReplaceAll(str(f["number"]), " ", ""),
			Date:      d,
			Phase:     phase(str(f["status"])),
			Detail:    str(f["status"]),
			Airline:   str(al["name"]),
			Departure: dep,
			Arrival:   arr,
			Provider:  provider,
		})
	}
	return out
}

func phase(s string) domain.Phase {
	switch s {
	case "Expected", "CheckIn", "Boarding", "GateClosed", "Delayed":
		return domain.PhaseScheduled
	case "EnRoute", "Departed", "Approaching":
		return domain.PhaseActive
	case "Arrived":
		return domain.PhaseLanded
	case "Canceled":
		return domain.PhaseCancelled
	case "Diverted":
		return domain.PhaseDiverted
	}
	return domain.PhaseUnknown // incl. CanceledUncertain: shown with its detail
}

func end(v any) domain.End {
	m, _ := v.(map[string]any)
	ap, _ := m["airport"].(map[string]any)
	e := domain.End{
		Airport: str(ap["name"]), IATA: str(ap["iata"]), Terminal: str(m["terminal"]),
		Gate: str(m["gate"]), Baggage: str(m["baggageBelt"]),
		Scheduled: local(m["scheduledTime"]),
		Estimated: firstOf(local(m["revisedTime"]), local(m["predictedTime"])),
		Actual:    local(m["runwayTime"]),
	}
	if e.Scheduled != "" && e.Estimated != "" {
		if s, err1 := time.Parse("2006-01-02T15:04", e.Scheduled); err1 == nil {
			if r, err2 := time.Parse("2006-01-02T15:04", e.Estimated); err2 == nil {
				n := int(r.Sub(s).Minutes())
				e.Delay = &n
			}
		}
	}
	return e
}

// local reads DateTimeContract.local ("2026-12-05 10:05+08:00") as wall time.
func local(v any) string {
	m, _ := v.(map[string]any)
	s := str(m["local"])
	if len(s) < 16 {
		return ""
	}
	return strings.Replace(s[:16], " ", "T", 1)
}

func firstOf(a, b string) string {
	if a != "" {
		return a
	}
	return b
}

func str(v any) string {
	if s, ok := v.(string); ok {
		return strings.TrimSpace(s)
	}
	return ""
}
