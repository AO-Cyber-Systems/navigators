package navigators

import (
	"context"
	"fmt"
	"log/slog"
	"time"

	"github.com/aocybersystems/eden-platform-go/platform/audit"
	"github.com/aocybersystems/eden-platform-go/platform/server"
)

// RequestPasswordReset initiates a password reset flow. Always returns nil
// regardless of whether the email exists (prevents user enumeration).
func (s *AdminService) RequestPasswordReset(ctx context.Context, email string) error {
	// Look up user by email -- if not found, return nil silently
	user, err := s.authStore.GetUserByEmail(ctx, email)
	if err != nil {
		// User not found -- return nil to prevent user enumeration
		slog.Debug("password reset requested for unknown email", "email", email)
		return nil
	}

	if !user.IsActive {
		// Deactivated user -- also return nil silently
		return nil
	}

	// Create a short-lived reset token (30 minutes)
	token, err := s.jwtManager.CreateShortLivedToken(user.Email, 30*time.Minute)
	if err != nil {
		slog.Error("failed to create password reset token", "error", err)
		return nil // Still return nil -- don't leak errors
	}

	// For MVP: log the reset URL to console instead of sending email.
	// Production would integrate with an email service here.
	slog.Info("PASSWORD RESET TOKEN",
		"email", user.Email,
		"url", fmt.Sprintf("http://localhost:8080/reset?token=%s", token),
	)

	// Log audit event (use system actor if no claims in context)
	actorID := "system"
	if id, _, _ := server.ExtractClaims(ctx); id != "" {
		actorID = id
	}
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    actorID,
		Action:     "password_reset.requested",
		Resource:   "user",
		ResourceID: user.ID.String(),
	})

	return nil
}

// ConfirmPasswordReset validates the reset token and sets a new password.
// Revokes all refresh tokens to force re-login.
func (s *AdminService) ConfirmPasswordReset(ctx context.Context, token, newPassword string) error {
	if len(newPassword) < 8 {
		return fmt.Errorf("password must be at least 8 characters")
	}

	// Validate token -- returns the email (subject)
	email, err := s.jwtManager.ValidateShortLivedToken(token)
	if err != nil {
		return fmt.Errorf("invalid or expired reset token")
	}

	// Look up user by email
	user, err := s.authStore.GetUserByEmail(ctx, email)
	if err != nil {
		return fmt.Errorf("invalid or expired reset token") // Don't reveal details
	}

	// Hash new password
	hashedPassword, err := s.passwordHasher.Hash(newPassword)
	if err != nil {
		return fmt.Errorf("hash password: %w", err)
	}

	// Update password directly via pool (auth store doesn't expose password update)
	_, err = s.pool.Exec(ctx,
		`UPDATE users SET password_hash = $1, updated_at = now() WHERE id = $2`,
		hashedPassword, user.ID,
	)
	if err != nil {
		return fmt.Errorf("update password: %w", err)
	}

	// Revoke all refresh tokens for this user (force re-login)
	_, err = s.pool.Exec(ctx,
		`UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND revoked = false`,
		user.ID,
	)
	if err != nil {
		slog.Error("failed to revoke refresh tokens during password reset", "user_id", user.ID, "error", err)
		// Don't fail the reset over this
	}

	// Log audit event
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    user.ID.String(),
		Action:     "password_reset.completed",
		Resource:   "user",
		ResourceID: user.ID.String(),
	})

	slog.Info("password reset completed", "user_id", user.ID)
	return nil
}
