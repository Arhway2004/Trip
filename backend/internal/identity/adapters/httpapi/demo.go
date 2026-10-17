package httpapi

import (
	"net/http"
	"time"

	"github.com/gin-gonic/gin"

	"wanderplan/backend/internal/platform/auth"
	"wanderplan/backend/internal/platform/httpx"
)

// The demo account the app signs in with on a development server, so testing
// on a phone needs no sign-in form. Development auth only (AUTH_MODE=dev,
// which config validation refuses in production).
const (
	DemoSubject = "demo-user"
	DemoEmail   = "demo@wanderplan.test"
	demoName    = "Demo traveller"
	demoTTL     = 30 * 24 * time.Hour
)

// DemoSignIn returns a token for the shared demo account.
func DemoSignIn(devSecret string) gin.HandlerFunc {
	return func(c *gin.Context) {
		tok, err := auth.IssueDevToken(devSecret, DemoSubject, DemoEmail, demoName, demoTTL)
		if err != nil {
			httpx.WriteError(c, err)
			return
		}
		c.Header("Cache-Control", "no-store")
		c.JSON(http.StatusOK, gin.H{
			"token":     tok,
			"email":     DemoEmail,
			"expiresAt": time.Now().Add(demoTTL).UTC().Format(time.RFC3339),
		})
	}
}
