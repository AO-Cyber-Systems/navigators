package navigators

import (
	"context"
	"fmt"

	"github.com/aocybersystems/eden-platform-go/platform/rbac"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"
)

// ScopeType indicates the data scope for a user.
type ScopeType int

const (
	ScopeOwn  ScopeType = iota // Navigator: own turfs only
	ScopeTeam                  // Super Navigator: team's turfs
	ScopeAll                   // Admin: all data
)

// TurfScope represents a resolved data scope for a user.
type TurfScope struct {
	Type    ScopeType
	TurfIDs []uuid.UUID // populated for ScopeOwn and ScopeTeam; nil for ScopeAll
	UserID  uuid.UUID
}

// TurfScopedFilter resolves what data a user can see based on their role and assignments.
type TurfScopedFilter struct {
	queries *db.Queries
}

// NewTurfScopedFilter creates a new TurfScopedFilter.
func NewTurfScopedFilter(queries *db.Queries) *TurfScopedFilter {
	return &TurfScopedFilter{queries: queries}
}

// ResolveScope determines the data scope for the current user from context.
// It uses the JWT claims role level to decide:
//   - Admin (level >= 80): ScopeAll (see all data)
//   - Manager/Super Navigator (level >= 60): ScopeTeam (see team's turfs)
//   - Member/Navigator (default): ScopeOwn (see own turfs only)
func (f *TurfScopedFilter) ResolveScope(ctx context.Context) (*TurfScope, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}

	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("parse user ID: %w", err)
	}

	switch {
	case claims.RoleLevel >= int(rbac.RoleLevelAdmin):
		return &TurfScope{Type: ScopeAll, UserID: userID}, nil

	case claims.RoleLevel >= int(rbac.RoleLevelManager):
		// Super Navigator: get all turfs from their team's navigators
		turfIDs, err := f.queries.GetTeamTurfIDs(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("get team turf IDs: %w", err)
		}
		return &TurfScope{Type: ScopeTeam, TurfIDs: turfIDs, UserID: userID}, nil

	default:
		// Navigator: get own assigned turfs
		turfIDs, err := f.queries.GetUserTurfIDs(ctx, userID)
		if err != nil {
			return nil, fmt.Errorf("get user turf IDs: %w", err)
		}
		return &TurfScope{Type: ScopeOwn, TurfIDs: turfIDs, UserID: userID}, nil
	}
}
