package navigators

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/aocybersystems/eden-platform-go/platform/audit"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// SessionInfo holds session details for listing.
type SessionInfo struct {
	UserID       uuid.UUID
	Email        string
	CreatedAt    time.Time
	LastActiveAt *time.Time
}

// RevokeSession revokes all refresh tokens for a target user.
func (s *AdminService) RevokeSession(ctx context.Context, targetUserID uuid.UUID) error {
	result, err := s.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND revoked = false`,
		targetUserID,
	)
	if err != nil {
		return fmt.Errorf("revoke session: %w", err)
	}

	callerID, _, _ := server.ExtractClaims(ctx)
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    callerID,
		Action:     "session.revoked",
		Resource:   "user",
		ResourceID: targetUserID.String(),
		Details:    map[string]any{"tokens_revoked": result.RowsAffected()},
	})

	slog.Info("admin revoked session", "target_user_id", targetUserID, "tokens_revoked", result.RowsAffected())
	return nil
}

// ListActiveSessions returns users with non-revoked, non-expired refresh tokens
// in the MaineGOP company.
func (s *AdminService) ListActiveSessions(ctx context.Context) ([]SessionInfo, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT DISTINCT ON (u.id) u.id, u.email, rt.created_at, rt.last_active_at
		FROM refresh_tokens rt
		JOIN users u ON u.id = rt.user_id
		JOIN company_memberships cm ON cm.user_id = u.id
		WHERE cm.company_id = $1
		  AND rt.revoked = false
		  AND rt.expires_at > now()
		ORDER BY u.id, rt.created_at DESC
	`, MaineGOPCompanyID)
	if err != nil {
		return nil, fmt.Errorf("list active sessions: %w", err)
	}
	defer rows.Close()

	var sessions []SessionInfo
	for rows.Next() {
		var s SessionInfo
		if err := rows.Scan(&s.UserID, &s.Email, &s.CreatedAt, &s.LastActiveAt); err != nil {
			return nil, fmt.Errorf("scan session: %w", err)
		}
		sessions = append(sessions, s)
	}
	return sessions, rows.Err()
}

// StartSessionTimeoutChecker launches a background goroutine that periodically
// revokes refresh tokens that have been inactive longer than the timeout.
//
// The checker runs every `interval` and revokes tokens where last_active_at
// (or created_at if last_active_at is null) is older than `timeout`.
func StartSessionTimeoutChecker(ctx context.Context, pool *pgxpool.Pool, interval, timeout time.Duration) {
	go func() {
		ticker := time.NewTicker(interval)
		defer ticker.Stop()

		slog.Info("session timeout checker started", "interval", interval, "timeout", timeout)

		for {
			select {
			case <-ctx.Done():
				slog.Info("session timeout checker stopped")
				return
			case <-ticker.C:
				cutoff := time.Now().Add(-timeout)
				result, err := pool.Exec(ctx, `
					UPDATE refresh_tokens
					SET revoked = true
					WHERE revoked = false
					  AND COALESCE(last_active_at, created_at) < $1
				`, cutoff)
				if err != nil {
					slog.Error("session timeout check failed", "error", err)
					continue
				}
				if result.RowsAffected() > 0 {
					slog.Info("session timeout: revoked inactive tokens", "count", result.RowsAffected())
				}
			}
		}
	}()
}

// UpdateLastActive updates the last_active_at timestamp for a refresh token.
// Called during token refresh to track session activity.
func UpdateLastActive(ctx context.Context, pool *pgxpool.Pool, tokenHash string) {
	_, err := pool.Exec(ctx,
		`UPDATE refresh_tokens SET last_active_at = now() WHERE token_hash = $1 AND revoked = false`,
		tokenHash,
	)
	if err != nil {
		slog.Warn("failed to update last_active_at", "error", err)
	}
}
