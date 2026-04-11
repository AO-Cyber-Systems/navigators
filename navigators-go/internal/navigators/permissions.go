package navigators

import (
	"github.com/aocybersystems/eden-platform-go/platform/rbac"
	"github.com/aocybersystems/eden-platform-go/platform/server"
)

// Navigators feature constants.
const (
	FeatureVoters rbac.Feature = "voters"
	FeatureTurfs  rbac.Feature = "turfs"
	FeatureTeams  rbac.Feature = "teams"
	FeatureAudit  rbac.Feature = "audit"
	FeatureAdmin  rbac.Feature = "admin"
)

// NavigatorsPermissionMatrix returns the RBAC permission matrix for the Navigators app.
// Maps each feature:action pair to the minimum role level required.
//
// Role mapping:
//
//	Navigator      = Member  (level 40)
//	Super Navigator = Manager (level 60)
//	Admin          = Admin   (level 80)
func NavigatorsPermissionMatrix() rbac.PermissionMatrix {
	return rbac.PermissionMatrix{
		FeatureVoters: {
			"view":   rbac.RoleLevelMember,  // Navigator (40)
			"edit":   rbac.RoleLevelMember,  // Navigator (40)
			"export": rbac.RoleLevelManager, // Super Navigator (60)
			"admin":  rbac.RoleLevelAdmin,   // Admin (80)
		},
		FeatureTurfs: {
			"view":   rbac.RoleLevelMember,  // Navigator (40)
			"create": rbac.RoleLevelAdmin,   // Admin (80)
			"assign": rbac.RoleLevelManager, // Super Navigator (60)
			"admin":  rbac.RoleLevelAdmin,   // Admin (80)
		},
		FeatureTeams: {
			"view":   rbac.RoleLevelManager, // Super Navigator (60)
			"manage": rbac.RoleLevelAdmin,   // Admin (80)
			"admin":  rbac.RoleLevelAdmin,   // Admin (80)
		},
		FeatureAudit: {
			"view":  rbac.RoleLevelAdmin, // Admin (80)
			"admin": rbac.RoleLevelAdmin, // Admin (80)
		},
		FeatureAdmin: {
			"users":    rbac.RoleLevelAdmin, // Admin (80)
			"sessions": rbac.RoleLevelAdmin, // Admin (80)
			"admin":    rbac.RoleLevelAdmin, // Admin (80)
		},
	}
}

// NavigatorsProcedurePermissions maps ConnectRPC procedure names to the
// permission (feature:action) required for access. Procedures not in this map
// are allowed through if the user is authenticated (unless they appear in
// PublicProcedures).
func NavigatorsProcedurePermissions() map[string]server.Permission {
	return map[string]server.Permission{
		// Admin user management
		"/navigators.v1.AdminService/CreateUser":  {Feature: "admin", Action: "users"},
		"/navigators.v1.AdminService/ListUsers":   {Feature: "admin", Action: "users"},
		"/navigators.v1.AdminService/AssignRole":  {Feature: "admin", Action: "users"},
		"/navigators.v1.AdminService/DeactivateUser": {Feature: "admin", Action: "users"},

		// Session management
		"/navigators.v1.AdminService/RevokeSession":      {Feature: "admin", Action: "sessions"},
		"/navigators.v1.AdminService/ListActiveSessions":  {Feature: "admin", Action: "sessions"},

		// Audit logs
		"/navigators.v1.AdminService/ListAuditLogs": {Feature: "audit", Action: "view"},

		// Turf management
		"/navigators.v1.TurfService/CreateTurf":        {Feature: "turfs", Action: "create"},
		"/navigators.v1.TurfService/ListTurfs":          {Feature: "turfs", Action: "view"},
		"/navigators.v1.TurfService/AssignUserToTurf":   {Feature: "turfs", Action: "assign"},
		"/navigators.v1.TurfService/RemoveUserFromTurf": {Feature: "turfs", Action: "assign"},
		"/navigators.v1.TurfService/GetUserTurfs":       {Feature: "turfs", Action: "view"},

		// Team management
		"/navigators.v1.TeamService/AssignNavigatorToTeam":   {Feature: "teams", Action: "manage"},
		"/navigators.v1.TeamService/RemoveNavigatorFromTeam": {Feature: "teams", Action: "manage"},
		"/navigators.v1.TeamService/GetTeamNavigators":       {Feature: "teams", Action: "view"},
	}
}

// NavigatorsPublicProcedures returns procedures that do not require authentication.
// These are merged with eden's DefaultPublicProcedures.
func NavigatorsPublicProcedures() map[string]bool {
	return map[string]bool{
		// Password reset must be accessible to unauthenticated users
		"/navigators.v1.AdminService/RequestPasswordReset": true,
		"/navigators.v1.AdminService/ConfirmPasswordReset": true,
	}
}

// MergedPublicProcedures returns eden's default public procedures merged with
// navigators-specific public procedures.
func MergedPublicProcedures() map[string]bool {
	merged := server.DefaultPublicProcedures()
	for k, v := range NavigatorsPublicProcedures() {
		merged[k] = v
	}
	return merged
}
