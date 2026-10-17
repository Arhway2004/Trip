package domain

import (
	"time"

	"github.com/google/uuid"
)

// Role is a person's permission level on one trip.
type Role string

const (
	RoleOwner  Role = "owner"
	RoleEditor Role = "editor"
	RoleViewer Role = "viewer"
)

func (r Role) Valid() bool            { return r == RoleOwner || r == RoleEditor || r == RoleViewer }
func (r Role) CanView() bool          { return r.Valid() }
func (r Role) CanEdit() bool          { return r == RoleOwner || r == RoleEditor }
func (r Role) CanDelete() bool        { return r == RoleOwner }
func (r Role) CanManageMembers() bool { return r == RoleOwner }

// Membership links a user to a trip with a role.
type Membership struct {
	TripID    uuid.UUID
	UserID    uuid.UUID
	Role      Role
	CreatedAt time.Time
}
