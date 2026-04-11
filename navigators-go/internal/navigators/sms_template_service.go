package navigators

import (
	"bytes"
	"context"
	"fmt"
	"text/template"

	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"

	"navigators-go/internal/db"
)

// VoterContext provides merge field data from voter records for template rendering.
// Exported fields match Go text/template syntax: {{.FirstName}}, {{.LastName}}, etc.
type VoterContext struct {
	FirstName string
	LastName  string
	City      string
	District  string
	Party     string
}

// sampleVoterContext is used for template previews.
var sampleVoterContext = VoterContext{
	FirstName: "Jane",
	LastName:  "Doe",
	City:      "Portland",
	District:  "HD-1",
	Party:     "Republican",
}

// SMSTemplateService provides template CRUD and merge field rendering.
type SMSTemplateService struct {
	queries *db.Queries
}

// NewSMSTemplateService creates a new SMSTemplateService.
func NewSMSTemplateService(queries *db.Queries) *SMSTemplateService {
	return &SMSTemplateService{queries: queries}
}

// CreateTemplate creates a new SMS template after validating the template body syntax.
func (s *SMSTemplateService) CreateTemplate(ctx context.Context, name, body string, mergeFields []string) (*db.SmsTemplate, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, fmt.Errorf("parse user ID: %w", err)
	}

	// Validate template body by parsing with text/template (catch syntax errors early).
	// Use empty FuncMap to restrict available functions.
	if _, err := template.New("validate").Funcs(template.FuncMap{}).Parse(body); err != nil {
		return nil, fmt.Errorf("invalid template syntax: %w", err)
	}

	row, err := s.queries.CreateSMSTemplate(ctx, db.CreateSMSTemplateParams{
		CompanyID:   companyID,
		Name:        name,
		Body:        body,
		MergeFields: mergeFields,
		CreatedBy:   userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create template: %w", err)
	}

	return &db.SmsTemplate{
		ID:          row.ID,
		CompanyID:   companyID,
		Name:        name,
		Body:        body,
		MergeFields: mergeFields,
		CreatedBy:   userID,
		IsActive:    true,
		CreatedAt:   row.CreatedAt,
		UpdatedAt:   row.CreatedAt,
	}, nil
}

// ListTemplates returns active templates for the company.
func (s *SMSTemplateService) ListTemplates(ctx context.Context, limit, offset int32) ([]db.SmsTemplate, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	return s.queries.ListSMSTemplates(ctx, db.ListSMSTemplatesParams{
		CompanyID: companyID,
		Limit:     limit,
		Offset:    offset,
	})
}

// GetTemplate returns a template by ID.
func (s *SMSTemplateService) GetTemplate(ctx context.Context, templateID uuid.UUID) (*db.SmsTemplate, error) {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return nil, fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return nil, fmt.Errorf("parse company ID: %w", err)
	}

	tmpl, err := s.queries.GetSMSTemplate(ctx, db.GetSMSTemplateParams{
		ID:        templateID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get template: %w", err)
	}
	return &tmpl, nil
}

// UpdateTemplate updates an existing template after validating the new body syntax.
func (s *SMSTemplateService) UpdateTemplate(ctx context.Context, templateID uuid.UUID, name, body string, mergeFields []string) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	// Validate template body syntax
	if _, err := template.New("validate").Funcs(template.FuncMap{}).Parse(body); err != nil {
		return fmt.Errorf("invalid template syntax: %w", err)
	}

	return s.queries.UpdateSMSTemplate(ctx, db.UpdateSMSTemplateParams{
		ID:          templateID,
		CompanyID:   companyID,
		Name:        name,
		Body:        body,
		MergeFields: mergeFields,
	})
}

// DeleteTemplate soft-deletes a template (sets is_active=false).
func (s *SMSTemplateService) DeleteTemplate(ctx context.Context, templateID uuid.UUID) error {
	claims := server.ClaimsFromContext(ctx)
	if claims == nil {
		return fmt.Errorf("no claims in context")
	}
	companyID, err := uuid.Parse(claims.CompanyID)
	if err != nil {
		return fmt.Errorf("parse company ID: %w", err)
	}

	return s.queries.DeleteSMSTemplate(ctx, db.DeleteSMSTemplateParams{
		ID:        templateID,
		CompanyID: companyID,
	})
}

// RenderTemplate renders a template body with the given VoterContext.
func (s *SMSTemplateService) RenderTemplate(body string, voter VoterContext) (string, error) {
	tmpl, err := template.New("sms").Funcs(template.FuncMap{}).Parse(body)
	if err != nil {
		return "", fmt.Errorf("parse template: %w", err)
	}

	var buf bytes.Buffer
	if err := tmpl.Execute(&buf, voter); err != nil {
		return "", fmt.Errorf("execute template: %w", err)
	}

	return buf.String(), nil
}

// PreviewTemplate renders a template with sample voter data for preview.
func (s *SMSTemplateService) PreviewTemplate(ctx context.Context, templateID uuid.UUID) (string, error) {
	tmpl, err := s.GetTemplate(ctx, templateID)
	if err != nil {
		return "", fmt.Errorf("get template for preview: %w", err)
	}

	return s.RenderTemplate(tmpl.Body, sampleVoterContext)
}

// VoterContextFromRow builds a VoterContext from a campaign voter target row.
func VoterContextFromRow(row db.GetCampaignVoterTargetsRow) VoterContext {
	return VoterContext{
		FirstName: row.FirstName,
		LastName:  row.LastName,
		City:      row.ResCity,
		District:  row.StateHouseDistrict,
		Party:     row.Party,
	}
}
