// Package domain holds the Identity context's entities. Pure Go: no HTTP, no SQL.
package domain

import (
	"time"

	"github.com/google/uuid"
)

// ExternalIdentity is what a verified login token tells us about a person.
type ExternalIdentity struct {
	Subject string // stable ID at the identity provider ("sub")
	Email   string
	Name    string
}

// User is a person known to WanderPlan.
type User struct {
	ID          uuid.UUID
	Subject     string
	Email       string
	DisplayName string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// SyncProfile copies changed profile fields from the identity provider and
// reports whether anything changed.
func (u *User) SyncProfile(ext ExternalIdentity, now time.Time) bool {
	changed := false
	if ext.Email != "" && ext.Email != u.Email {
		u.Email, changed = ext.Email, true
	}
	if ext.Name != "" && ext.Name != u.DisplayName {
		u.DisplayName, changed = ext.Name, true
	}
	if changed {
		u.UpdatedAt = now
	}
	return changed
}
