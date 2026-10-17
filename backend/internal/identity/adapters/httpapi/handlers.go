// Package httpapi exposes the Identity context over HTTP (Gin).
package httpapi

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"wanderplan/backend/internal/identity/app"
	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
)

type Handler struct{ svc *app.Service }

func New(svc *app.Service) *Handler { return &Handler{svc: svc} }

func (h *Handler) Register(g *gin.RouterGroup) { g.GET("/me", h.me) }

func (h *Handler) me(c *gin.Context) {
	u, err := h.svc.Get(c.Request.Context(), auth.UserID(c))
	if err != nil {
		httpx.WriteError(c, err)
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":          u.ID.String(),
		"email":       u.Email,
		"displayName": u.DisplayName,
		"createdAt":   u.CreatedAt.UTC().Format(time.RFC3339),
	})
}
