package navigators

import (
	"context"
	"fmt"
	"time"

	connect "connectrpc.com/connect"
	"github.com/aocybersystems/eden-platform-go/platform/server"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"

	"navigators-go/internal/db"

	navigatorsv1 "navigators-go/gen/go/navigators/v1"
	"navigators-go/gen/go/navigators/v1/navigatorsv1connect"
)

// Compile-time check that EventHandler implements the generated interface.
var _ navigatorsv1connect.EventServiceHandler = (*EventHandler)(nil)

// EventHandler implements the navigators.v1.EventService ConnectRPC handler.
type EventHandler struct {
	eventService *EventService
}

// NewEventHandler creates a new EventHandler.
func NewEventHandler(eventService *EventService) *EventHandler {
	return &EventHandler{eventService: eventService}
}

func (h *EventHandler) CreateEvent(ctx context.Context, req *connect.Request[navigatorsv1.CreateEventRequest]) (*connect.Response[navigatorsv1.CreateEventResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	// Role gate: admin/manager only (RoleLevel >= 60)
	if claims.RoleLevel < 60 {
		return nil, connect.NewError(connect.CodePermissionDenied, fmt.Errorf("insufficient permissions"))
	}

	title := req.Msg.GetTitle()
	if title == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("title is required"))
	}

	eventType := req.Msg.GetEventType()
	if eventType == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("event_type is required"))
	}

	startsAtStr := req.Msg.GetStartsAt()
	if startsAtStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("starts_at is required"))
	}
	startsAt, err := time.Parse(time.RFC3339, startsAtStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid starts_at: %w", err))
	}

	endsAtStr := req.Msg.GetEndsAt()
	if endsAtStr == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("ends_at is required"))
	}
	endsAt, err := time.Parse(time.RFC3339, endsAtStr)
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid ends_at: %w", err))
	}

	var locationName *string
	if req.Msg.GetLocationName() != "" {
		n := req.Msg.GetLocationName()
		locationName = &n
	}

	var locationLat, locationLng *float64
	if req.Msg.GetLocationLat() != 0 {
		lat := req.Msg.GetLocationLat()
		locationLat = &lat
	}
	if req.Msg.GetLocationLng() != 0 {
		lng := req.Msg.GetLocationLng()
		locationLng = &lng
	}

	var linkedTurfID *uuid.UUID
	if req.Msg.GetLinkedTurfId() != "" {
		parsed, err := uuid.Parse(req.Msg.GetLinkedTurfId())
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid linked_turf_id: %w", err))
		}
		linkedTurfID = &parsed
	}

	var maxAttendees *int32
	if req.Msg.GetMaxAttendees() > 0 {
		ma := req.Msg.GetMaxAttendees()
		maxAttendees = &ma
	}

	event, err := h.eventService.CreateEvent(ctx, companyID, userID, CreateEventParams{
		Title:        title,
		Description:  req.Msg.GetDescription(),
		EventType:    eventType,
		StartsAt:     startsAt,
		EndsAt:       endsAt,
		LocationName: locationName,
		LocationLat:  locationLat,
		LocationLng:  locationLng,
		LinkedTurfID: linkedTurfID,
		MaxAttendees: maxAttendees,
	})
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("create event: %w", err))
	}

	rsvpCount, _ := h.eventService.GetEventRSVPCount(ctx, event.ID)

	return connect.NewResponse(&navigatorsv1.CreateEventResponse{
		Event: dbEventToProto(event, rsvpCount),
	}), nil
}

func (h *EventHandler) GetEvent(ctx context.Context, req *connect.Request[navigatorsv1.GetEventRequest]) (*connect.Response[navigatorsv1.GetEventResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	event, err := h.eventService.GetEvent(ctx, companyID, eventID)
	if err != nil {
		return nil, connect.NewError(connect.CodeNotFound, fmt.Errorf("event not found: %w", err))
	}

	rsvpCount, _ := h.eventService.GetEventRSVPCount(ctx, event.ID)

	return connect.NewResponse(&navigatorsv1.GetEventResponse{
		Event: dbEventToProto(event, rsvpCount),
	}), nil
}

func (h *EventHandler) ListEvents(ctx context.Context, req *connect.Request[navigatorsv1.ListEventsRequest]) (*connect.Response[navigatorsv1.ListEventsResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	events, err := h.eventService.ListEvents(ctx, companyID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("list events: %w", err))
	}

	pbEvents := make([]*navigatorsv1.Event, len(events))
	for i := range events {
		rsvpCount, _ := h.eventService.GetEventRSVPCount(ctx, events[i].ID)
		pbEvents[i] = dbEventToProto(&events[i], rsvpCount)
	}

	return connect.NewResponse(&navigatorsv1.ListEventsResponse{
		Events: pbEvents,
	}), nil
}

func (h *EventHandler) UpdateEvent(ctx context.Context, req *connect.Request[navigatorsv1.UpdateEventRequest]) (*connect.Response[navigatorsv1.UpdateEventResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	startsAt, err := time.Parse(time.RFC3339, req.Msg.GetStartsAt())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid starts_at: %w", err))
	}

	endsAt, err := time.Parse(time.RFC3339, req.Msg.GetEndsAt())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid ends_at: %w", err))
	}

	var locationName *string
	if req.Msg.GetLocationName() != "" {
		n := req.Msg.GetLocationName()
		locationName = &n
	}

	var locationLat, locationLng *float64
	if req.Msg.GetLocationLat() != 0 {
		lat := req.Msg.GetLocationLat()
		locationLat = &lat
	}
	if req.Msg.GetLocationLng() != 0 {
		lng := req.Msg.GetLocationLng()
		locationLng = &lng
	}

	var linkedTurfID *uuid.UUID
	if req.Msg.GetLinkedTurfId() != "" {
		parsed, err := uuid.Parse(req.Msg.GetLinkedTurfId())
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid linked_turf_id: %w", err))
		}
		linkedTurfID = &parsed
	}

	var maxAttendees *int32
	if req.Msg.GetMaxAttendees() > 0 {
		ma := req.Msg.GetMaxAttendees()
		maxAttendees = &ma
	}

	event, err := h.eventService.UpdateEvent(ctx, companyID, eventID, UpdateEventParams{
		Title:        req.Msg.GetTitle(),
		Description:  req.Msg.GetDescription(),
		EventType:    req.Msg.GetEventType(),
		StartsAt:     startsAt,
		EndsAt:       endsAt,
		LocationName: locationName,
		LocationLat:  locationLat,
		LocationLng:  locationLng,
		LinkedTurfID: linkedTurfID,
		MaxAttendees: maxAttendees,
	})
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("update event: %w", err))
	}

	rsvpCount, _ := h.eventService.GetEventRSVPCount(ctx, event.ID)

	return connect.NewResponse(&navigatorsv1.UpdateEventResponse{
		Event: dbEventToProto(event, rsvpCount),
	}), nil
}

func (h *EventHandler) CancelEvent(ctx context.Context, req *connect.Request[navigatorsv1.CancelEventRequest]) (*connect.Response[navigatorsv1.CancelEventResponse], error) {
	companyID, err := extractCompanyID(ctx)
	if err != nil {
		return nil, err
	}

	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	if err := h.eventService.CancelEvent(ctx, companyID, eventID); err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("cancel event: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CancelEventResponse{}), nil
}

func (h *EventHandler) RSVPEvent(ctx context.Context, req *connect.Request[navigatorsv1.RSVPEventRequest]) (*connect.Response[navigatorsv1.RSVPEventResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	status := req.Msg.GetStatus()
	if status == "" {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("status is required"))
	}

	rsvp, err := h.eventService.RSVPEvent(ctx, eventID, userID, status)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("rsvp event: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.RSVPEventResponse{
		Rsvp: dbEventRSVPToProto(rsvp),
	}), nil
}

func (h *EventHandler) CheckInEvent(ctx context.Context, req *connect.Request[navigatorsv1.CheckInEventRequest]) (*connect.Response[navigatorsv1.CheckInEventResponse], error) {
	claims := server.ClaimsFromContext(ctx)
	userID, err := uuid.Parse(claims.UserID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("parse user ID: %w", err))
	}

	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	checkin, err := h.eventService.CheckInEvent(ctx, eventID, userID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("check in event: %w", err))
	}

	return connect.NewResponse(&navigatorsv1.CheckInEventResponse{
		Checkin: dbEventCheckinToProto(checkin),
	}), nil
}

func (h *EventHandler) GetEventAttendance(ctx context.Context, req *connect.Request[navigatorsv1.GetEventAttendanceRequest]) (*connect.Response[navigatorsv1.GetEventAttendanceResponse], error) {
	eventID, err := uuid.Parse(req.Msg.GetEventId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, fmt.Errorf("invalid event_id: %w", err))
	}

	rsvps, checkins, err := h.eventService.GetEventAttendance(ctx, eventID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal, fmt.Errorf("get event attendance: %w", err))
	}

	pbRSVPs := make([]*navigatorsv1.EventRSVP, len(rsvps))
	for i, r := range rsvps {
		pbRSVPs[i] = &navigatorsv1.EventRSVP{
			Id:          r.ID.String(),
			EventId:     r.EventID.String(),
			UserId:      r.UserID.String(),
			Status:      r.Status,
			DisplayName: r.DisplayName,
			CreatedAt:   r.CreatedAt.Format(time.RFC3339),
		}
	}

	pbCheckins := make([]*navigatorsv1.EventCheckin, len(checkins))
	for i, c := range checkins {
		pbCheckins[i] = &navigatorsv1.EventCheckin{
			Id:          c.ID.String(),
			EventId:     c.EventID.String(),
			UserId:      c.UserID.String(),
			DisplayName: c.DisplayName,
			CheckedInAt: c.CheckedInAt.Format(time.RFC3339),
		}
	}

	return connect.NewResponse(&navigatorsv1.GetEventAttendanceResponse{
		Rsvps:    pbRSVPs,
		Checkins: pbCheckins,
	}), nil
}

// --- Proto conversion helpers ---

func dbEventToProto(e *db.Event, rsvpCount int32) *navigatorsv1.Event {
	var locationName string
	if e.LocationName != nil {
		locationName = *e.LocationName
	}
	var locationLat, locationLng float64
	if e.LocationLat != nil {
		locationLat = *e.LocationLat
	}
	if e.LocationLng != nil {
		locationLng = *e.LocationLng
	}
	var linkedTurfID string
	if e.LinkedTurfID.Valid {
		linkedTurfID = uuid.UUID(e.LinkedTurfID.Bytes).String()
	}
	var maxAttendees int32
	if e.MaxAttendees != nil {
		maxAttendees = *e.MaxAttendees
	}

	return &navigatorsv1.Event{
		Id:            e.ID.String(),
		CompanyId:     e.CompanyID.String(),
		Title:         e.Title,
		Description:   e.Description,
		EventType:     e.EventType,
		Status:        e.Status,
		StartsAt:      e.StartsAt.Format(time.RFC3339),
		EndsAt:        e.EndsAt.Format(time.RFC3339),
		LocationName:  locationName,
		LocationLat:   locationLat,
		LocationLng:   locationLng,
		LinkedTurfId:  linkedTurfID,
		MaxAttendees:  maxAttendees,
		RsvpCount:     rsvpCount,
		CreatedBy:     e.CreatedBy.String(),
		CreatedAt:     e.CreatedAt.Format(time.RFC3339),
		UpdatedAt:     e.UpdatedAt.Format(time.RFC3339),
	}
}

func dbEventRSVPToProto(r *db.EventRsvp) *navigatorsv1.EventRSVP {
	return &navigatorsv1.EventRSVP{
		Id:        r.ID.String(),
		EventId:   r.EventID.String(),
		UserId:    r.UserID.String(),
		Status:    r.Status,
		CreatedAt: r.CreatedAt.Format(time.RFC3339),
	}
}

func dbEventCheckinToProto(c *db.EventCheckin) *navigatorsv1.EventCheckin {
	return &navigatorsv1.EventCheckin{
		Id:          c.ID.String(),
		EventId:     c.EventID.String(),
		UserId:      c.UserID.String(),
		CheckedInAt: c.CheckedInAt.Format(time.RFC3339),
	}
}

// Ensure pgtype import is used
var _ pgtype.UUID
