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
	FeatureSync    rbac.Feature = "sync"
	FeatureSurveys rbac.Feature = "surveys"
	FeatureNotes   rbac.Feature = "notes"
	FeatureSMS         rbac.Feature = "sms"
	FeatureCallScripts rbac.Feature = "call_scripts"
	FeatureTasks       rbac.Feature = "tasks"
	FeatureAnalytics    rbac.Feature = "analytics"
	FeatureOnboarding   rbac.Feature = "onboarding"
	FeatureLeaderboard  rbac.Feature = "leaderboard"
	FeatureTraining     rbac.Feature = "training"
	FeatureEvents       rbac.Feature = "events"
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
		FeatureSync: {
			"pull": rbac.RoleLevelMember, // Navigator (40) -- all navigators can sync
			"push": rbac.RoleLevelMember, // Navigator (40)
		},
		FeatureSurveys: {
			"view":   rbac.RoleLevelMember,  // Navigator (40)
			"create": rbac.RoleLevelAdmin,   // Admin (80)
			"admin":  rbac.RoleLevelAdmin,   // Admin (80)
		},
		FeatureNotes: {
			"view":   rbac.RoleLevelMember, // Navigator (40)
			"create": rbac.RoleLevelMember, // Navigator (40)
			"admin":  rbac.RoleLevelAdmin,  // Admin (80)
		},
		FeatureSMS: {
			"send":     rbac.RoleLevelMember, // Navigator (40) -- can send P2P
			"view":     rbac.RoleLevelMember, // Navigator (40) -- can view conversations
			"config":   rbac.RoleLevelAdmin,  // Admin (80) -- configures Twilio
			"template": rbac.RoleLevelAdmin,  // Admin (80) -- manages message templates
			"campaign": rbac.RoleLevelAdmin,  // Admin (80) -- manages campaigns
			"admin":    rbac.RoleLevelAdmin,  // Admin (80) -- manages all SMS
		},
		FeatureCallScripts: {
			"view":   rbac.RoleLevelMember, // Navigator (40)
			"create": rbac.RoleLevelAdmin,  // Admin (80)
			"admin":  rbac.RoleLevelAdmin,  // Admin (80)
		},
		FeatureTasks: {
			"view":   rbac.RoleLevelMember,  // Navigator (40)
			"create": rbac.RoleLevelManager, // Super Navigator (60)
			"assign": rbac.RoleLevelManager, // Super Navigator (60)
			"admin":  rbac.RoleLevelAdmin,   // Admin (80)
		},
		FeatureAnalytics: {
			"view":   rbac.RoleLevelMember, // Navigator (40) -- all roles can view dashboard
			"export": rbac.RoleLevelAdmin,  // Admin (80) -- export is admin-only
		},
		FeatureOnboarding: {
			"view":   rbac.RoleLevelMember, // Navigator (40) -- all roles can access onboarding
			"update": rbac.RoleLevelMember, // Navigator (40)
		},
		FeatureLeaderboard: {
			"view": rbac.RoleLevelMember, // Navigator (40) -- all roles can view leaderboard
		},
		FeatureTraining: {
			"view":   rbac.RoleLevelMember,  // Navigator (40) -- all roles can view materials
			"create": rbac.RoleLevelManager, // Super Navigator (60)
		},
		FeatureEvents: {
			"view":   rbac.RoleLevelMember,  // Navigator (40) -- all roles can view/RSVP/check-in
			"create": rbac.RoleLevelManager, // Super Navigator (60) -- create/update/cancel
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

		// Voter import management (admin only)
		"/navigators.v1.VoterImportService/StartImport":      {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterImportService/ConfirmUpload":    {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterImportService/GetImportStatus":  {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterImportService/ListImportJobs":   {Feature: "voters", Action: "admin"},

		// Voter data queries
		"/navigators.v1.VoterService/GetVoter":     {Feature: "voters", Action: "view"},
		"/navigators.v1.VoterService/SearchVoters": {Feature: "voters", Action: "view"},
		"/navigators.v1.VoterService/ListVoters":   {Feature: "voters", Action: "view"},

		// Voter suppression list management
		"/navigators.v1.VoterService/AddToSuppressionList":      {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterService/RemoveFromSuppressionList": {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterService/IsVoterSuppressed":         {Feature: "voters", Action: "view"},
		"/navigators.v1.VoterService/ListSuppressedVoters":      {Feature: "voters", Action: "admin"},

		// Sync operations
		"/navigators.v1.SyncService/PullVoterUpdates":    {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullContactLogs":     {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullSurveyForms":     {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullSurveyResponses": {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullVoterNotes":      {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullCallScripts":     {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PushSyncBatch":       {Feature: "sync", Action: "push"},
		"/navigators.v1.SyncService/GetSyncManifest":     {Feature: "sync", Action: "pull"},

		// Voter tag management
		"/navigators.v1.VoterService/CreateTag":          {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterService/ListTags":            {Feature: "voters", Action: "view"},
		"/navigators.v1.VoterService/DeleteTag":           {Feature: "voters", Action: "admin"},
		"/navigators.v1.VoterService/AssignTagToVoter":    {Feature: "voters", Action: "edit"},
		"/navigators.v1.VoterService/RemoveTagFromVoter":  {Feature: "voters", Action: "edit"},
		"/navigators.v1.VoterService/GetVoterTags":        {Feature: "voters", Action: "view"},

		// SMS operations
		"/navigators.v1.SMSService/SendP2PMessage":   {Feature: "sms", Action: "send"},
		"/navigators.v1.SMSService/GetConversation":   {Feature: "sms", Action: "view"},
		"/navigators.v1.SMSService/ListConversations": {Feature: "sms", Action: "view"},
		"/navigators.v1.SMSService/GetSMSConfig":      {Feature: "sms", Action: "config"},
		"/navigators.v1.SMSService/UpdateSMSConfig":   {Feature: "sms", Action: "config"},

		// Template management (Admin only)
		"/navigators.v1.SMSService/CreateTemplate":   {Feature: "sms", Action: "template"},
		"/navigators.v1.SMSService/ListTemplates":    {Feature: "sms", Action: "template"},
		"/navigators.v1.SMSService/GetTemplate":      {Feature: "sms", Action: "template"},
		"/navigators.v1.SMSService/UpdateTemplate":   {Feature: "sms", Action: "template"},
		"/navigators.v1.SMSService/DeleteTemplate":   {Feature: "sms", Action: "template"},
		"/navigators.v1.SMSService/PreviewTemplate":  {Feature: "sms", Action: "template"},

		// Campaign management (Admin only)
		"/navigators.v1.SMSService/CreateCampaign":   {Feature: "sms", Action: "campaign"},
		"/navigators.v1.SMSService/LaunchCampaign":   {Feature: "sms", Action: "campaign"},
		"/navigators.v1.SMSService/PauseCampaign":    {Feature: "sms", Action: "campaign"},
		"/navigators.v1.SMSService/CancelCampaign":   {Feature: "sms", Action: "campaign"},
		"/navigators.v1.SMSService/GetCampaign":      {Feature: "sms", Action: "campaign"},
		"/navigators.v1.SMSService/ListCampaigns":    {Feature: "sms", Action: "campaign"},

		// 10DLC status (Admin only)
		"/navigators.v1.SMSService/Get10DLCStatus":    {Feature: "sms", Action: "config"},
		"/navigators.v1.SMSService/Update10DLCStatus": {Feature: "sms", Action: "config"},

		// Task management
		"/navigators.v1.TaskService/CreateTask":         {Feature: "tasks", Action: "create"},
		"/navigators.v1.TaskService/GetTask":             {Feature: "tasks", Action: "view"},
		"/navigators.v1.TaskService/ListTasks":            {Feature: "tasks", Action: "view"},
		"/navigators.v1.TaskService/UpdateTaskStatus":     {Feature: "tasks", Action: "create"},
		"/navigators.v1.TaskService/DeleteTask":            {Feature: "tasks", Action: "admin"},
		"/navigators.v1.TaskService/AssignTask":            {Feature: "tasks", Action: "assign"},
		"/navigators.v1.TaskService/UnassignTask":          {Feature: "tasks", Action: "assign"},
		"/navigators.v1.TaskService/GetTaskAssignments":    {Feature: "tasks", Action: "view"},
		"/navigators.v1.TaskService/LinkTaskVoters":        {Feature: "tasks", Action: "create"},
		"/navigators.v1.TaskService/CreateTaskNote":        {Feature: "tasks", Action: "view"},
		"/navigators.v1.TaskService/ListTaskNotes":         {Feature: "tasks", Action: "view"},
		"/navigators.v1.TaskService/RegisterDeviceToken":   {Feature: "tasks", Action: "view"}, // All authenticated users (Member level)

		// Task sync
		"/navigators.v1.SyncService/PullTasks":     {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullTaskNotes": {Feature: "sync", Action: "pull"},

		// Analytics (read endpoints accessible to all authenticated roles)
		"/navigators.v1.AnalyticsService/GetDashboardMetrics":  {Feature: "analytics", Action: "view"},
		"/navigators.v1.AnalyticsService/GetTrendData":          {Feature: "analytics", Action: "view"},
		"/navigators.v1.AnalyticsService/GetPerformanceReport":  {Feature: "analytics", Action: "view"},
		// Export is admin-only
		"/navigators.v1.AnalyticsService/ExportData": {Feature: "analytics", Action: "export"},

		// Onboarding (all authenticated)
		"/navigators.v1.OnboardingService/GetOnboardingStatus":   {Feature: "onboarding", Action: "view"},
		"/navigators.v1.OnboardingService/AcknowledgeLegal":      {Feature: "onboarding", Action: "update"},
		"/navigators.v1.OnboardingService/CompleteOnboarding":    {Feature: "onboarding", Action: "update"},
		"/navigators.v1.OnboardingService/UpdateLeaderboardOptIn": {Feature: "onboarding", Action: "update"},

		// Leaderboard (all authenticated)
		"/navigators.v1.LeaderboardService/GetLeaderboard": {Feature: "leaderboard", Action: "view"},

		// Training materials
		"/navigators.v1.TrainingService/ListTrainingMaterials":   {Feature: "training", Action: "view"},
		"/navigators.v1.TrainingService/CreateTrainingMaterial":  {Feature: "training", Action: "create"},
		"/navigators.v1.TrainingService/GetTrainingDownloadUrl":  {Feature: "training", Action: "view"},

		// Events
		"/navigators.v1.EventService/CreateEvent":         {Feature: "events", Action: "create"},
		"/navigators.v1.EventService/GetEvent":             {Feature: "events", Action: "view"},
		"/navigators.v1.EventService/ListEvents":            {Feature: "events", Action: "view"},
		"/navigators.v1.EventService/UpdateEvent":           {Feature: "events", Action: "create"},
		"/navigators.v1.EventService/CancelEvent":           {Feature: "events", Action: "create"},
		"/navigators.v1.EventService/RSVPEvent":             {Feature: "events", Action: "view"},
		"/navigators.v1.EventService/CheckInEvent":          {Feature: "events", Action: "view"},
		"/navigators.v1.EventService/GetEventAttendance":    {Feature: "events", Action: "view"},

		// Event + Training sync
		"/navigators.v1.SyncService/PullEvents":              {Feature: "sync", Action: "pull"},
		"/navigators.v1.SyncService/PullTrainingMaterials":   {Feature: "sync", Action: "pull"},
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
