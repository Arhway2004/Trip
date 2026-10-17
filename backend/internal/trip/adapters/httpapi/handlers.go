// Package httpapi exposes the Trip context over HTTP (Gin). It translates JSON
// ⇄ domain types and delegates every decision to the application service.
package httpapi

import (
	"fmt"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"

	"wanderplan/backend/internal/kernel"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
	"wanderplan/backend/internal/trip/app"
	"wanderplan/backend/internal/trip/domain"
)

type Handler struct{ svc *app.Service }

func New(svc *app.Service) *Handler { return &Handler{svc: svc} }

// Register mounts the routes on an authenticated group (e.g. /v1).
func (h *Handler) Register(g *gin.RouterGroup) {
	g.POST("/trips", h.create)
	g.POST("/trips/import", h.importTrip)
	g.GET("/trips/:tripId/import", h.importedPackage)
	g.GET("/trips/:tripId/plan", h.plan)
	g.PUT("/trips/:tripId/plan", h.savePlan)
	g.GET("/trips/:tripId/export", h.exportPlan)
	g.GET("/trips", h.list)
	g.GET("/trips/:tripId", h.get)
	g.PUT("/trips/:tripId", h.replace)
	g.DELETE("/trips/:tripId", h.delete)
	g.GET("/trips/:tripId/members", h.members)
}

// tripRequest uses the same field names as the app's trip file format.
type tripRequest struct {
	ID             *string  `json:"id"`
	Title          string   `json:"title"`
	Description    *string  `json:"description"`
	StartDate      *string  `json:"startDate"`
	EndDate        *string  `json:"endDate"`
	DepartureTime  *string  `json:"departureTime"`
	DatesConfirmed bool     `json:"datesConfirmed"`
	TimeZone       string   `json:"timeZone"`
	TravelerCount  int      `json:"travelerCount"`
	Currency       *string  `json:"currency"`
	TotalBudget    *float64 `json:"totalBudget"`
	TravelStyle    *string  `json:"travelStyle"`
	Stage          string   `json:"stage"`
	Archived       bool     `json:"archived"`
}

type tripResponse struct {
	ID             string   `json:"id"`
	OwnerID        string   `json:"ownerId"`
	Role           string   `json:"role"`
	Title          string   `json:"title"`
	Description    *string  `json:"description"`
	StartDate      *string  `json:"startDate"`
	EndDate        *string  `json:"endDate"`
	DepartureTime  *string  `json:"departureTime"`
	DatesConfirmed bool     `json:"datesConfirmed"`
	TimeZone       string   `json:"timeZone"`
	TravelerCount  int      `json:"travelerCount"`
	Currency       *string  `json:"currency"`
	TotalBudget    *float64 `json:"totalBudget"`
	TravelStyle    *string  `json:"travelStyle"`
	Stage          string   `json:"stage"`
	Archived       bool     `json:"archived"`
	Version        int64    `json:"version"`
	CreatedAt      string   `json:"createdAt"`
	UpdatedAt      string   `json:"updatedAt"`
}

type memberResponse struct {
	UserID    string `json:"userId"`
	Role      string `json:"role"`
	CreatedAt string `json:"createdAt"`
}

func (r tripRequest) fields() (domain.Fields, error) {
	var errs []kernel.FieldError
	date := func(name string, s *string) *kernel.Date {
		if s == nil || *s == "" {
			return nil
		}
		d, err := kernel.ParseDate(*s)
		if err != nil {
			errs = append(errs, kernel.FieldError{Field: name, Message: "must be YYYY-MM-DD"})
			return nil
		}
		return &d
	}
	f := domain.Fields{
		Title:          r.Title,
		Description:    r.Description,
		StartDate:      date("startDate", r.StartDate),
		EndDate:        date("endDate", r.EndDate),
		DepartureTime:  r.DepartureTime,
		DatesConfirmed: r.DatesConfirmed,
		TimeZone:       r.TimeZone,
		TravelerCount:  r.TravelerCount,
		Currency:       r.Currency,
		TotalBudget:    r.TotalBudget,
		Stage:          domain.Stage(r.Stage),
		Archived:       r.Archived,
	}
	if r.TravelStyle != nil && *r.TravelStyle != "" {
		s := domain.TravelStyle(*r.TravelStyle)
		f.TravelStyle = &s
	}
	if len(errs) > 0 {
		return f, kernel.Validation("trip.invalid", "the trip has invalid fields", errs...)
	}
	return f, nil
}

func toResponse(v app.View) tripResponse {
	t := v.Trip
	str := func(d *kernel.Date) *string {
		if d == nil {
			return nil
		}
		s := d.String()
		return &s
	}
	var style *string
	if t.TravelStyle != nil {
		s := string(*t.TravelStyle)
		style = &s
	}
	return tripResponse{
		ID: t.ID.String(), OwnerID: t.OwnerID.String(), Role: string(v.Role),
		Title: t.Title, Description: t.Description, StartDate: str(t.StartDate), EndDate: str(t.EndDate),
		DepartureTime: t.DepartureTime, DatesConfirmed: t.DatesConfirmed, TimeZone: t.TimeZone,
		TravelerCount: t.TravelerCount, Currency: t.Currency, TotalBudget: t.TotalBudget, TravelStyle: style,
		Stage: string(t.Stage), Archived: t.Archived, Version: t.Version,
		CreatedAt: t.CreatedAt.UTC().Format(time.RFC3339), UpdatedAt: t.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func etag(version int64) string { return fmt.Sprintf(`"%d"`, version) }

// parseIfMatch reads a strong ETag like "3" (W/ prefixes are tolerated).
func parseIfMatch(c *gin.Context) (int64, bool) {
	v := strings.TrimPrefix(strings.TrimSpace(c.GetHeader("If-Match")), "W/")
	n, err := strconv.ParseInt(strings.Trim(v, `"`), 10, 64)
	return n, err == nil
}

func tripID(c *gin.Context) (uuid.UUID, bool) {
	id, err := uuid.Parse(c.Param("tripId"))
	if err != nil {
		httpx.WriteError(c, kernel.NotFound("trip.not_found", "trip not found"))
		return uuid.Nil, false
	}
	return id, true
}

func (h *Handler) create(c *gin.Context) {
	var req tripRequest
	if !httpx.BindJSON(c, &req) {
		return
	}
	f, err := req.fields()
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	var id *uuid.UUID
	if req.ID != nil {
		parsed, err := uuid.Parse(*req.ID)
		if err != nil {
			httpx.WriteError(c, kernel.Validation("trip.invalid", "the trip has invalid fields", kernel.FieldError{Field: "id", Message: "must be a UUID"}))
			return
		}
		id = &parsed
	}
	v, created, err := h.svc.Create(c.Request.Context(), auth.UserID(c), id, f)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("ETag", etag(v.Trip.Version))
	c.Header("Location", "/v1/trips/"+v.Trip.ID.String())
	status := http.StatusCreated
	if !created {
		status = http.StatusOK // idempotent retry of an earlier create
	}
	c.JSON(status, toResponse(v))
}

func (h *Handler) list(c *gin.Context) {
	includeArchived := c.Query("includeArchived") == "true"
	views, err := h.svc.List(c.Request.Context(), auth.UserID(c), includeArchived)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	items := make([]tripResponse, 0, len(views))
	for _, v := range views {
		items = append(items, toResponse(v))
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}

func (h *Handler) get(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	v, err := h.svc.Get(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	tag := etag(v.Trip.Version)
	c.Header("ETag", tag)
	if c.GetHeader("If-None-Match") == tag {
		c.Status(http.StatusNotModified)
		return
	}
	c.JSON(http.StatusOK, toResponse(v))
}

func (h *Handler) replace(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	version, ok := parseIfMatch(c)
	if !ok {
		httpx.WriteProblem(c, http.StatusPreconditionRequired, "trip.if_match_required",
			"send If-Match with the trip's ETag to avoid overwriting someone else's changes")
		return
	}
	var req tripRequest
	if !httpx.BindJSON(c, &req) {
		return
	}
	f, err := req.fields()
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	v, err := h.svc.Replace(c.Request.Context(), auth.UserID(c), id, version, f)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Header("ETag", etag(v.Trip.Version))
	c.JSON(http.StatusOK, toResponse(v))
}

func (h *Handler) delete(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	var expected *int64
	if c.GetHeader("If-Match") != "" {
		v, ok := parseIfMatch(c)
		if !ok {
			httpx.WriteProblem(c, http.StatusBadRequest, "request.bad_if_match", "If-Match must be the trip's ETag")
			return
		}
		expected = &v
	}
	if err := h.svc.Delete(c.Request.Context(), auth.UserID(c), id, expected); err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) members(c *gin.Context) {
	id, ok := tripID(c)
	if !ok {
		return
	}
	ms, err := h.svc.Members(c.Request.Context(), auth.UserID(c), id)
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	items := make([]memberResponse, 0, len(ms))
	for _, m := range ms {
		items = append(items, memberResponse{UserID: m.UserID.String(), Role: string(m.Role), CreatedAt: m.CreatedAt.UTC().Format(time.RFC3339)})
	}
	c.JSON(http.StatusOK, gin.H{"items": items})
}
