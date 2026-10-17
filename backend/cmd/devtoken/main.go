// Command devtoken prints a development bearer token for AUTH_MODE=dev.
//
//	DEV_JWT_SECRET=... go run ./cmd/devtoken -sub alice -email alice@example.com
package main

import (
	"flag"
	"fmt"
	"os"
	"time"

	"wanderplan/backend/internal/platform/auth"
)

func main() {
	sub := flag.String("sub", "dev-user", "subject (stable user id at the identity provider)")
	email := flag.String("email", "", "email claim")
	name := flag.String("name", "", "name claim")
	ttl := flag.Duration("ttl", 24*time.Hour, "token lifetime")
	flag.Parse()
	secret := os.Getenv("DEV_JWT_SECRET")
	if len(secret) < 32 {
		fmt.Fprintln(os.Stderr, "DEV_JWT_SECRET (>= 32 chars) is required")
		os.Exit(2)
	}
	tok, err := auth.IssueDevToken(secret, *sub, *email, *name, *ttl)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
	fmt.Println(tok)
}
