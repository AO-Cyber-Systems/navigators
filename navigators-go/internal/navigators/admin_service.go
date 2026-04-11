package navigators

import (
	"context"
	"fmt"
	"log/slog"
	"net/mail"
	"strings"

	"github.com/aocybersystems/eden-platform-go/platform/audit"
	"github.com/aocybersystems/eden-platform-go/platform/auth"
	"github.com/aocybersystems/eden-platform-go/platform/rbac"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

// MaineGOPCompanyID is the well-known UUID for the pre-seeded MaineGOP company.
var MaineGOPCompanyID = uuid.MustParse("40000000-0000-0000-0000-000000000001")

// roleNameToID maps navigators role names to eden system role IDs.
var roleNameToID = map[string]uuid.UUID{
	"navigator":       rbac.MemberRoleID,  // level 40
	"super_navigator": rbac.ManagerRoleID, // level 60
	"admin":           rbac.AdminRoleID,   // level 80
}

// roleIDToName maps eden system role IDs to navigators role names.
var roleIDToName = map[uuid.UUID]string{
	rbac.MemberRoleID:  "navigator",
	rbac.ManagerRoleID: "super_navigator",
	rbac.AdminRoleID:   "admin",
	rbac.OwnerRoleID:   "admin", // owner maps to admin display
}

// UserInfo holds user details for listing.
type UserInfo struct {
	ID          uuid.UUID
	Email       string
	DisplayName string
	Role        string
	IsActive    bool
	CreatedAt   string
}

// AdminService provides admin operations for the Navigators application.
type AdminService struct {
	authStore      auth.TxAuthStore
	rbacStore      rbac.RBACStore
	passwordHasher *auth.PasswordHasher
	jwtManager     *auth.JWTManager
	auditLogger    *audit.Logger
	pool           *pgxpool.Pool
}

// NewAdminService creates a new AdminService.
func NewAdminService(
	authStore auth.TxAuthStore,
	rbacStore rbac.RBACStore,
	passwordHasher *auth.PasswordHasher,
	jwtManager *auth.JWTManager,
	auditLogger *audit.Logger,
	pool *pgxpool.Pool,
) *AdminService {
	return &AdminService{
		authStore:      authStore,
		rbacStore:      rbacStore,
		passwordHasher: passwordHasher,
		jwtManager:     jwtManager,
		auditLogger:    auditLogger,
		pool:           pool,
	}
}

// CreateUser creates a new user account and assigns them to the MaineGOP company
// with the specified role. This does NOT use eden's SignUp (which creates a company per user).
func (s *AdminService) CreateUser(ctx context.Context, email, displayName, password, roleName string) (uuid.UUID, error) {
	// Validate inputs
	if err := validateEmail(email); err != nil {
		return uuid.Nil, fmt.Errorf("invalid email: %w", err)
	}
	if len(password) < 8 {
		return uuid.Nil, fmt.Errorf("password must be at least 8 characters")
	}
	if strings.TrimSpace(displayName) == "" {
		return uuid.Nil, fmt.Errorf("display name is required")
	}

	// Map role name to eden role ID
	roleID, ok := roleNameToID[strings.ToLower(roleName)]
	if !ok {
		return uuid.Nil, fmt.Errorf("invalid role: %s (must be navigator, super_navigator, or admin)", roleName)
	}

	// Hash password
	hashedPassword, err := s.passwordHasher.Hash(password)
	if err != nil {
		return uuid.Nil, fmt.Errorf("hash password: %w", err)
	}

	// Begin transaction
	tx, err := s.authStore.BeginTx(ctx)
	if err != nil {
		return uuid.Nil, fmt.Errorf("begin transaction: %w", err)
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Create user
	email = strings.ToLower(strings.TrimSpace(email))
	user, err := tx.CreateUser(ctx, email, hashedPassword, strings.TrimSpace(displayName))
	if err != nil {
		if strings.Contains(err.Error(), "duplicate key") || strings.Contains(err.Error(), "unique constraint") {
			return uuid.Nil, fmt.Errorf("an account with this email already exists")
		}
		return uuid.Nil, fmt.Errorf("create user: %w", err)
	}

	// Create membership in MaineGOP company
	if err := tx.CreateCompanyMembership(ctx, MaineGOPCompanyID, user.ID, roleID); err != nil {
		return uuid.Nil, fmt.Errorf("create company membership: %w", err)
	}

	// Commit transaction
	if err := tx.Commit(ctx); err != nil {
		return uuid.Nil, fmt.Errorf("commit transaction: %w", err)
	}

	// Extract caller info for audit
	callerID, _, _ := server.ExtractClaims(ctx)

	// Log audit event
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    callerID,
		Action:     "user.created",
		Resource:   "user",
		ResourceID: user.ID.String(),
		Details:    map[string]any{"role": roleName, "email": email},
	})

	slog.Info("admin created user", "user_id", user.ID, "email", email, "role", roleName)
	return user.ID, nil
}

// ListUsers returns all users in the MaineGOP company with their roles.
func (s *AdminService) ListUsers(ctx context.Context) ([]UserInfo, error) {
	rows, err := s.pool.Query(ctx, `
		SELECT u.id, u.email, u.display_name, r.id as role_id, u.is_active, u.created_at
		FROM users u
		JOIN company_memberships cm ON cm.user_id = u.id
		JOIN roles r ON r.id = cm.role_id
		WHERE cm.company_id = $1
		ORDER BY u.created_at DESC
	`, MaineGOPCompanyID)
	if err != nil {
		return nil, fmt.Errorf("list users: %w", err)
	}
	defer rows.Close()

	var users []UserInfo
	for rows.Next() {
		var u UserInfo
		var roleID uuid.UUID
		var createdAt interface{}
		if err := rows.Scan(&u.ID, &u.Email, &u.DisplayName, &roleID, &u.IsActive, &createdAt); err != nil {
			return nil, fmt.Errorf("scan user: %w", err)
		}
		u.Role = roleIDToName[roleID]
		if u.Role == "" {
			u.Role = "unknown"
		}
		u.CreatedAt = fmt.Sprintf("%v", createdAt)
		users = append(users, u)
	}
	return users, rows.Err()
}

// DeactivateUser soft-deactivates a user and revokes all their refresh tokens.
func (s *AdminService) DeactivateUser(ctx context.Context, userID uuid.UUID) error {
	// Deactivate user
	_, err := s.pool.Exec(ctx, `UPDATE users SET is_active = false, updated_at = now() WHERE id = $1`, userID)
	if err != nil {
		return fmt.Errorf("deactivate user: %w", err)
	}

	// Revoke all refresh tokens
	_, err = s.pool.Exec(ctx, `UPDATE refresh_tokens SET revoked = true WHERE user_id = $1 AND revoked = false`, userID)
	if err != nil {
		return fmt.Errorf("revoke tokens: %w", err)
	}

	callerID, _, _ := server.ExtractClaims(ctx)
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    callerID,
		Action:     "user.deactivated",
		Resource:   "user",
		ResourceID: userID.String(),
	})

	slog.Info("admin deactivated user", "user_id", userID)
	return nil
}

// AssignRole changes a user's role in the MaineGOP company.
func (s *AdminService) AssignRole(ctx context.Context, userID uuid.UUID, roleName string) error {
	roleID, ok := roleNameToID[strings.ToLower(roleName)]
	if !ok {
		return fmt.Errorf("invalid role: %s (must be navigator, super_navigator, or admin)", roleName)
	}

	if err := s.rbacStore.AssignRoleToUser(ctx, MaineGOPCompanyID, userID, roleID); err != nil {
		return fmt.Errorf("assign role: %w", err)
	}

	callerID, _, _ := server.ExtractClaims(ctx)
	s.auditLogger.Log(audit.Event{
		CompanyID:  MaineGOPCompanyID.String(),
		ActorID:    callerID,
		Action:     "user.role_assigned",
		Resource:   "user",
		ResourceID: userID.String(),
		Details:    map[string]any{"role": roleName},
	})

	slog.Info("admin assigned role", "user_id", userID, "role", roleName)
	return nil
}

func validateEmail(email string) error {
	_, err := mail.ParseAddress(email)
	return err
}
