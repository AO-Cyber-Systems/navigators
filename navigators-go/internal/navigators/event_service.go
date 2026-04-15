package navigators

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/nats-io/nats.go/jetstream"

	"navigators-go/internal/db"
)

// EventService provides event CRUD, RSVP, and check-in operations.
type EventService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
	js      jetstream.JetStream // nil if NATS unavailable
}

// NewEventService creates a new EventService.
func NewEventService(queries *db.Queries, pool *pgxpool.Pool, js jetstream.JetStream) *EventService {
	return &EventService{
		queries: queries,
		pool:    pool,
		js:      js,
	}
}

// CreateEventParams holds the parameters for creating an event.
type CreateEventParams struct {
	Title        string
	Description  string
	EventType    string
	StartsAt     time.Time
	EndsAt       time.Time
	LocationName *string
	LocationLat  *float64
	LocationLng  *float64
	LinkedTurfID *uuid.UUID
	MaxAttendees *int32
}

// CreateEvent creates a new event.
func (s *EventService) CreateEvent(ctx context.Context, companyID, userID uuid.UUID, params CreateEventParams) (*db.Event, error) {
	// Validate event_type
	switch params.EventType {
	case "canvass", "phone_bank", "meeting", "other":
	default:
		return nil, fmt.Errorf("invalid event_type: %s", params.EventType)
	}

	var pgLinkedTurfID pgtype.UUID
	if params.LinkedTurfID != nil {
		pgLinkedTurfID = pgtype.UUID{Bytes: *params.LinkedTurfID, Valid: true}
	}

	event, err := s.queries.CreateEvent(ctx, db.CreateEventParams{
		CompanyID:    companyID,
		Title:        params.Title,
		Description:  params.Description,
		EventType:    params.EventType,
		StartsAt:     params.StartsAt,
		EndsAt:       params.EndsAt,
		LocationName: params.LocationName,
		LocationLat:  params.LocationLat,
		LocationLng:  params.LocationLng,
		LinkedTurfID: pgLinkedTurfID,
		MaxAttendees: params.MaxAttendees,
		CreatedBy:    userID,
	})
	if err != nil {
		return nil, fmt.Errorf("create event: %w", err)
	}

	return &event, nil
}

// GetEvent returns an event by ID.
func (s *EventService) GetEvent(ctx context.Context, companyID, eventID uuid.UUID) (*db.Event, error) {
	event, err := s.queries.GetEvent(ctx, db.GetEventParams{
		ID:        eventID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get event: %w", err)
	}
	return &event, nil
}

// ListEvents returns events for a company.
func (s *EventService) ListEvents(ctx context.Context, companyID uuid.UUID) ([]db.Event, error) {
	events, err := s.queries.ListEventsByCompany(ctx, companyID)
	if err != nil {
		return nil, fmt.Errorf("list events: %w", err)
	}
	return events, nil
}

// UpdateEventParams holds the parameters for updating an event.
type UpdateEventParams struct {
	Title        string
	Description  string
	EventType    string
	StartsAt     time.Time
	EndsAt       time.Time
	LocationName *string
	LocationLat  *float64
	LocationLng  *float64
	LinkedTurfID *uuid.UUID
	MaxAttendees *int32
}

// UpdateEvent updates an existing event.
func (s *EventService) UpdateEvent(ctx context.Context, companyID, eventID uuid.UUID, params UpdateEventParams) (*db.Event, error) {
	// Check event exists and is not cancelled
	existing, err := s.queries.GetEvent(ctx, db.GetEventParams{
		ID:        eventID,
		CompanyID: companyID,
	})
	if err != nil {
		return nil, fmt.Errorf("get event for update: %w", err)
	}
	if existing.Status == "cancelled" {
		return nil, fmt.Errorf("cannot update a cancelled event")
	}

	var pgLinkedTurfID pgtype.UUID
	if params.LinkedTurfID != nil {
		pgLinkedTurfID = pgtype.UUID{Bytes: *params.LinkedTurfID, Valid: true}
	}

	event, err := s.queries.UpdateEvent(ctx, db.UpdateEventParams{
		ID:           eventID,
		CompanyID:    companyID,
		Title:        params.Title,
		Description:  params.Description,
		EventType:    params.EventType,
		StartsAt:     params.StartsAt,
		EndsAt:       params.EndsAt,
		LocationName: params.LocationName,
		LocationLat:  params.LocationLat,
		LocationLng:  params.LocationLng,
		LinkedTurfID: pgLinkedTurfID,
		MaxAttendees: params.MaxAttendees,
	})
	if err != nil {
		return nil, fmt.Errorf("update event: %w", err)
	}

	return &event, nil
}

// CancelEvent cancels an event.
func (s *EventService) CancelEvent(ctx context.Context, companyID, eventID uuid.UUID) error {
	if err := s.queries.CancelEvent(ctx, db.CancelEventParams{
		ID:        eventID,
		CompanyID: companyID,
	}); err != nil {
		return fmt.Errorf("cancel event: %w", err)
	}
	return nil
}

// EventRSVPEvent is published to NATS when a user RSVPs to an event.
type EventRSVPEvent struct {
	EventID   string `json:"event_id"`
	UserID    string `json:"user_id"`
	Status    string `json:"status"`
	EventTitle string `json:"event_title"`
}

// RSVPEvent creates or updates an RSVP for an event.
func (s *EventService) RSVPEvent(ctx context.Context, eventID, userID uuid.UUID, status string) (*db.EventRsvp, error) {
	switch status {
	case "going", "maybe", "declined":
	default:
		return nil, fmt.Errorf("invalid RSVP status: %s", status)
	}

	rsvp, err := s.queries.RSVPEvent(ctx, db.RSVPEventParams{
		EventID: eventID,
		UserID:  userID,
		Status:  status,
	})
	if err != nil {
		return nil, fmt.Errorf("rsvp event: %w", err)
	}

	// Remote push was descoped; no event.rsvp event is published.

	return &rsvp, nil
}

// CheckInEvent records a check-in at an event.
func (s *EventService) CheckInEvent(ctx context.Context, eventID, userID uuid.UUID) (*db.EventCheckin, error) {
	checkin, err := s.queries.CheckInEvent(ctx, db.CheckInEventParams{
		EventID: eventID,
		UserID:  userID,
	})
	if err != nil {
		return nil, fmt.Errorf("check in event: %w", err)
	}
	return &checkin, nil
}

// GetEventAttendance returns RSVPs and check-ins for an event.
func (s *EventService) GetEventAttendance(ctx context.Context, eventID uuid.UUID) ([]db.GetEventRSVPsRow, []db.GetEventCheckinsRow, error) {
	rsvps, err := s.queries.GetEventRSVPs(ctx, eventID)
	if err != nil {
		return nil, nil, fmt.Errorf("get event rsvps: %w", err)
	}

	checkins, err := s.queries.GetEventCheckins(ctx, eventID)
	if err != nil {
		return nil, nil, fmt.Errorf("get event checkins: %w", err)
	}

	return rsvps, checkins, nil
}

// GetEventRSVPCount returns the number of "going" RSVPs for an event.
func (s *EventService) GetEventRSVPCount(ctx context.Context, eventID uuid.UUID) (int32, error) {
	count, err := s.queries.GetEventRSVPCount(ctx, eventID)
	if err != nil {
		return 0, fmt.Errorf("get event rsvp count: %w", err)
	}
	return int32(count), nil
}
