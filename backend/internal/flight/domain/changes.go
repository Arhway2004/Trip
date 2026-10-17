package domain

import "time"

// ChangeKind names what changed between two answers.
type ChangeKind string

const (
	ChangeStatus            ChangeKind = "status"
	ChangeDepartureTime     ChangeKind = "departureTime"
	ChangeArrivalTime       ChangeKind = "arrivalTime"
	ChangeDepartureTerminal ChangeKind = "departureTerminal"
	ChangeDepartureGate     ChangeKind = "departureGate"
	ChangeArrivalTerminal   ChangeKind = "arrivalTerminal"
	ChangeArrivalGate       ChangeKind = "arrivalGate"
	ChangeBaggage           ChangeKind = "baggageBelt"
)

type Change struct {
	Kind       ChangeKind `json:"kind"`
	From       string     `json:"from,omitempty"`
	To         string     `json:"to"`
	DetectedAt time.Time  `json:"detectedAt"`
}

// SignificantMinutes: smaller time shifts aren't worth telling anyone.
const SignificantMinutes = 10

func minutesBetween(a, b string) (int, bool) {
	const layout = "2006-01-02T15:04"
	ta, errA := time.Parse(layout, a)
	tb, errB := time.Parse(layout, b)
	if errA != nil || errB != nil {
		return 0, false
	}
	return int(tb.Sub(ta).Minutes()), true
}

// Diff lists what the traveller should hear about. Without an earlier
// answer only bad news counts (cancelled/diverted or a significant delay).
func Diff(before *Status, now Status, at time.Time) []Change {
	var out []Change
	add := func(k ChangeKind, from, to string) {
		out = append(out, Change{Kind: k, From: from, To: to, DetectedAt: at})
	}
	if before == nil {
		if now.Phase == PhaseCancelled || now.Phase == PhaseDiverted {
			add(ChangeStatus, "", string(now.Phase))
		}
		if m, ok := minutesBetween(now.Departure.Scheduled, now.Departure.Best()); ok && m >= SignificantMinutes {
			add(ChangeDepartureTime, now.Departure.Scheduled, now.Departure.Best())
		}
		return out
	}
	if before.Phase != now.Phase {
		add(ChangeStatus, string(before.Phase), string(now.Phase))
	}
	timeChange := func(k ChangeKind, a, b string) {
		if m, ok := minutesBetween(a, b); ok && (m >= SignificantMinutes || m <= -SignificantMinutes) {
			add(k, a, b)
		}
	}
	textChange := func(k ChangeKind, a, b string) {
		if b != "" && a != b {
			add(k, a, b)
		}
	}
	timeChange(ChangeDepartureTime, before.Departure.Best(), now.Departure.Best())
	timeChange(ChangeArrivalTime, before.Arrival.Best(), now.Arrival.Best())
	textChange(ChangeDepartureTerminal, before.Departure.Terminal, now.Departure.Terminal)
	textChange(ChangeDepartureGate, before.Departure.Gate, now.Departure.Gate)
	textChange(ChangeArrivalTerminal, before.Arrival.Terminal, now.Arrival.Terminal)
	textChange(ChangeArrivalGate, before.Arrival.Gate, now.Arrival.Gate)
	textChange(ChangeBaggage, before.Arrival.Baggage, now.Arrival.Baggage)
	return out
}
