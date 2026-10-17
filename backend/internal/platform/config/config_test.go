package config

import "testing"

func TestValidate(t *testing.T) {
	long := "0123456789012345678901234567890123"
	cases := []struct {
		name string
		c    Config
		ok   bool
	}{
		{"dev ok", Config{Env: "development", Auth: AuthDev, DevJWTSecret: long}, true},
		{"dev short secret", Config{Env: "development", Auth: AuthDev, DevJWTSecret: "short"}, false},
		{"dev auth in production", Config{Env: "production", Auth: AuthDev, DevJWTSecret: long, DatabaseURL: "postgres://x"}, false},
		{"oidc needs issuer", Config{Env: "production", Auth: AuthOIDC, DatabaseURL: "postgres://x"}, false},
		{"production needs db", Config{Env: "production", Auth: AuthOIDC, OIDCIssuer: "https://id", OIDCAudience: "api"}, false},
		{"production ok", Config{Env: "production", Auth: AuthOIDC, OIDCIssuer: "https://id", OIDCAudience: "api", DatabaseURL: "postgres://x"}, true},
	}
	for _, c := range cases {
		if err := c.c.Validate(); (err == nil) != c.ok {
			t.Errorf("%s: ok=%v err=%v", c.name, c.ok, err)
		}
	}
}
