// Package httpapi exposes bookings and monitored flights over HTTP.
package httpapi

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"wanderplan/backend/internal/flight/app"
	"wanderplan/backend/internal/flight/domain"
	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
)

type Handler struct{ svc *app.Service }

func New(svc *app.Service) *Handler { return &Handler{svc: svc} }

func (h *Handler) Register(g *gin.RouterGroup) {
	g.POST("/bookings", h.createBooking)
	g.GET("/bookings", h.listBookings)
	g.GET("/bookings/:bookingId", h.getBooking)
	g.DELETE("/bookings/:bookingId", h.deleteBooking)
	g.GET("/flights/:flightId", h.getFlight)
	g.POST("/flights/:flightId/refresh", h.refresh)
	g.GET("/flight-changes", h.changes)
}

type segmentRequest struct {
	Flight string `json:"flight"`
	Date   string `json:"date"`
}

type bookingRequest struct {
	TripID   *string          `json:"tripId"`
	Traveler string           `json:"traveler"`
	Segments []segmentRequest `json:"segments"`
}

type flightResponse struct {
	ID            string          `json:"id"`
	Flight        string          `json:"flight"`
	Date          string          `json:"date"`
	Status        *domain.Status  `json:"status"`
	LastCheckedAt *string         `json:"lastCheckedAt"`
	LastSuccessAt *string         `json:"lastSuccessAt"`
	NextCheckAt   *string         `json:"nextCheckAt"`
	Stale         bool            `json:"stale"`
	Changes       []domain.Change `json:"changes"`
}

type bookingResponse struct {
	ID        string           `json:"id"`
	TripID    *string          `json:"tripId"`
	Traveler  string           `json:"traveler"`
	CreatedAt string           `json:"createdAt"`
	Flights   []flightResponse `json:"flights"`
}

type changeResponse struct {
	FlightID   string `json:"flightId"`
	Flight     string `json:"flight"`
	Date       string `json:"date"`
	Kind       string `json:"kind"`
	From       string `json:"from,omitempty"`
	To         string `json:"to"`
	DetectedAt string `json:"detectedAt"`
}

func ts(t *time.Time) *string {
	if t == nil {
		return nil
	}
	s := t.UTC().Format(time.RFC3339)
	return &s
}

func toFlight(v app.FlightView) flightResponse {
	changes := v.Changes
	if changes == nil {
		changes = []domain.Change{}
	}
	return flightResponse{
		ID: v.ID.String(), Flight: v.Code, Date: v.Date.String(), Status: v.Status,
		LastCheckedAt: ts(v.LastCheckedAt), LastSuccessAt: ts(v.LastSuccessAt), NextCheckAt: ts(v.NextCheckAt),
		Stale: v.Stale, Changes: changes,
	}
}

func toBooking(v app.BookingView) bookingResponse {
	r := bookingResponse{ID: v.ID.String(), Traveler: v.Traveler, CreatedAt: v.CreatedAt.UTC().Format(time.RFC3339), Flights: []flightResponse{}}
	if v.TripID != nil {
		s := v.TripID.String()
		r.TripID = &s
	}
	for _, f := range v.Flights {
		r.Flights = append(r.Flights, toFlight(f))
	}
	return r
}

func pathID(c *gin.Context, name, code string) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param(name))
	if err != nil {
		httpx.WriteError(c, kernel.NotFound(code, "not found"))
		return uuid.Nil, false
	}
	return id, true
}

func (h *Handler) createBooking(c *gin.Context) {
	var req bookingRequest
	if !httpx.BindJSON(c, &req) {
		return
	}
	in := app.BookingInput{Traveler: req.Traveler}
	if req.TripID != nil {
		id, err := uuid.Parse(*req.TripID)
		if err != nil {
			httpx.WriteError(c, kernel.Validation("booking.invalid", "tripId must be a UUID", kernel.FieldError{Field: "tripId", Message: "not a UUID"}))
			return
		}
		in.TripID = &id
	}
	for _, s := range req.Segments {
		in.Segments = append(in.Segments, domain.SegmentInput{Flight: s.Flight, Date: s.Date})
	}
	v, err := h.svc.CreateBooking(c.Request.Context(), auth.UserID(c), in)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("Location", "/v1/bookings/"+v.ID.String())
	c.JSON(http.StatusCreated, toBooking(v))
}

func (h *Handler) listBookings(c *gin.Context) {
	vs, err := h.svc.ListBookings(c.Request.Context(), auth.UserID(c))
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	out := make([]bookingResponse, 0, len(vs))
	for _, v := range vs {
		out = append(out, toBooking(v))
	}
	c.JSON(http.StatusOK, gin.H{"items": out})
}

func (h *Handler) getBooking(c *gin.Context) {
	id, ok := pathID(c, "bookingId", "booking.not_found")
	if !ok {
		return
	}
	v, err := h.svc.GetBooking(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.JSON(http.StatusOK, toBooking(v))
}

func (h *Handler) deleteBooking(c *gin.Context) {
	id, ok := pathID(c, "bookingId", "booking.not_found")
	if !ok {
		return
	}
	if err := h.svc.DeleteBooking(c.Request.Context(), auth.UserID(c), id); err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) getFlight(c *gin.Context) {
	id, ok := pathID(c, "flightId", "flight.not_found")
	if !ok {
		return
	}
	v, err := h.svc.GetFlight(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.JSON(http.StatusOK, toFlight(v))
}

func (h *Handler) refresh(c *gin.Context) {
	id, ok := pathID(c, "flightId", "flight.not_found")
	if !ok {
		return
	}
	v, err := h.svc.RefreshNow(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.JSON(http.StatusOK, toFlight(v))
}

func (h *Handler) changes(c *gin.Context) {
	var since time.Time
	if s := c.Query("since"); s != "" {
		t, err := time.Parse(time.RFC3339, s)
		if err != nil {
			httpx.WriteError(c, kernel.Validation("request.invalid", "since must be RFC 3339", kernel.FieldError{Field: "since", Message: "not a timestamp"}))
			return
		}
		since = t
	}
	cs, err := h.svc.ChangesSince(c.Request.Context(), auth.UserID(c), since)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	out := make([]changeResponse, 0, len(cs))
	for _, x := range cs {
		out = append(out, changeResponse{
			FlightID: x.FlightID.String(), Flight: x.Code, Date: x.Date.String(), Kind: string(x.Kind),
			From: x.From, To: x.To, DetectedAt: x.DetectedAt.UTC().Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"items": out})
}
