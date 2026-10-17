// Package auth verifies bearer tokens and resolves the signed-in user.
// Production uses OpenID Connect (any provider: Zitadel, Auth0, Cognito…);
// development can use locally signed HS256 tokens.
package auth

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/MicahParks/keyfunc/v3"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"github.com/google/uuid"

	"wanderplan/backend/internal/platform/httpx"
)

// Claims is the verified identity carried by a token.
type Claims struct {
	Subject string
	Email   string
	Name    string
}

type Verifier interface {
	Verify(ctx context.Context, rawToken string) (Claims, error)
}

type tokenClaims struct {
	Email string `json:"email"`
	Name  string `json:"name"`
	jwt.RegisteredClaims
}

func claimsFrom(tc *tokenClaims) Claims {
	return Claims{Subject: tc.Subject, Email: tc.Email, Name: tc.Name}
}

// ---------------------------------------------------------------- OIDC

type OIDCVerifier struct {
	kf       keyfunc.Keyfunc
	issuer   string
	audience string
}

// NewOIDCVerifier loads signing keys from jwksURL, or discovers it from the
// issuer's /.well-known/openid-configuration. Keys refresh automatically.
func NewOIDCVerifier(ctx context.Context, issuer, audience, jwksURL string) (*OIDCVerifier, error) {
	if jwksURL == "" {
		u, err := discoverJWKS(ctx, issuer)
		if err != nil {
			return nil, err
		}
		jwksURL = u
	}
	kf, err := keyfunc.NewDefaultCtx(ctx, []string{jwksURL})
	if err != nil {
		return nil, fmt.Errorf("load JWKS: %w", err)
	}
	return &OIDCVerifier{kf: kf, issuer: issuer, audience: audience}, nil
}

func discoverJWKS(ctx context.Context, issuer string) (string, error) {
	ctx, cancel := context.WithTimeout(ctx, 10*time.Second)
	defer cancel()
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, strings.TrimRight(issuer, "/")+"/.well-known/openid-configuration", nil)
	res, err := http.DefaultClient.Do(req)
	if err != nil {
		return "", fmt.Errorf("OIDC discovery: %w", err)
	}
	defer res.Body.Close()
	var doc struct {
		JWKSURI string `json:"jwks_uri"`
	}
	if err := json.NewDecoder(res.Body).Decode(&doc); err != nil || doc.JWKSURI == "" {
		return "", errors.New("OIDC discovery: no jwks_uri")
	}
	return doc.JWKSURI, nil
}

func (v *OIDCVerifier) Verify(_ context.Context, raw string) (Claims, error) {
	var tc tokenClaims
	_, err := jwt.ParseWithClaims(raw, &tc, v.kf.Keyfunc,
		jwt.WithIssuer(v.issuer),
		jwt.WithAudience(v.audience),
		jwt.WithValidMethods([]string{"RS256", "ES256", "PS256"}),
		jwt.WithExpirationRequired(),
		jwt.WithLeeway(30*time.Second),
	)
	if err != nil {
		return Claims{}, err
	}
	return claimsFrom(&tc), nil
}

// ---------------------------------------------------------------- development

// DevVerifier accepts HS256 tokens signed with a shared secret. Never enable
// in production (config validation refuses it).
type DevVerifier struct{ secret []byte }

func NewDevVerifier(secret string) *DevVerifier { return &DevVerifier{secret: []byte(secret)} }

const devIssuer = "wanderplan-dev"

func (v *DevVerifier) Verify(_ context.Context, raw string) (Claims, error) {
	var tc tokenClaims
	_, err := jwt.ParseWithClaims(raw, &tc, func(*jwt.Token) (any, error) { return v.secret, nil },
		jwt.WithIssuer(devIssuer), jwt.WithValidMethods([]string{"HS256"}), jwt.WithExpirationRequired())
	if err != nil {
		return Claims{}, err
	}
	return claimsFrom(&tc), nil
}

// IssueDevToken signs a development token (tests, local tooling).
func IssueDevToken(secret, subject, email, name string, ttl time.Duration) (string, error) {
	now := time.Now()
	tc := tokenClaims{Email: email, Name: name, RegisteredClaims: jwt.RegisteredClaims{
		Issuer: devIssuer, Subject: subject, IssuedAt: jwt.NewNumericDate(now), ExpiresAt: jwt.NewNumericDate(now.Add(ttl)),
	}}
	return jwt.NewWithClaims(jwt.SigningMethodHS256, tc).SignedString([]byte(secret))
}

// ---------------------------------------------------------------- middleware

// UserResolver maps verified claims to the internal user ID (creating the
// user on first sign-in). Supplied by the composition root.
type UserResolver func(ctx context.Context, c Claims) (uuid.UUID, error)

const userIDKey = "user_id"

// Required rejects requests without a valid bearer token.
func Required(v Verifier, resolve UserResolver) gin.HandlerFunc {
	return func(c *gin.Context) {
		h := c.GetHeader("Authorization")
		raw, ok := strings.CutPrefix(h, "Bearer ")
		if !ok || raw == "" {
			c.Header("WWW-Authenticate", `Bearer realm="wanderplan"`)
			httpx.WriteProblem(c, http.StatusUnauthorized, "auth.missing_token", "sign in to continue")
			return
		}
		claims, err := v.Verify(c.Request.Context(), raw)
		if err != nil {
			c.Header("WWW-Authenticate", `Bearer error="invalid_token"`)
			httpx.WriteProblem(c, http.StatusUnauthorized, "auth.invalid_token", "your session is invalid or expired")
			return
		}
		id, err := resolve(c.Request.Context(), claims)
		if err != nil {
			httpx.WriteError(c, err)
			return
		}
		c.Set(userIDKey, id)
		httpx.SetLogUser(c, id.String())
		c.Next()
	}
}

// UserID returns the authenticated user's ID (only valid behind Required).
func UserID(c *gin.Context) uuid.UUID {
	id, _ := c.Get(userIDKey)
	u, _ := id.(uuid.UUID)
	return u
}
