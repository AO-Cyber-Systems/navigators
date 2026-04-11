package navigators

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgtype"
	"github.com/jackc/pgx/v5/pgxpool"

	"navigators-go/internal/db"
)

// VoterNotesService provides voter note operations with role-scoped visibility.
type VoterNotesService struct {
	queries *db.Queries
	pool    *pgxpool.Pool
}

// NewVoterNotesService creates a new VoterNotesService.
func NewVoterNotesService(queries *db.Queries, pool *pgxpool.Pool) *VoterNotesService {
	return &VoterNotesService{
		queries: queries,
		pool:    pool,
	}
}

// voterNotePayload is the JSON structure for voter note push operations.
type voterNotePayload struct {
	ID         string `json:"id"`
	VoterID    string `json:"voter_id"`
	UserID     string `json:"user_id"`
	TurfID     string `json:"turf_id"`
	Content    string `json:"content"`
	Visibility string `json:"visibility"`
	CreatedAt  string `json:"created_at"`
	UpdatedAt  string `json:"updated_at"`
}

// ProcessVoterNote processes a voter note from a client push.
func (s *VoterNotesService) ProcessVoterNote(ctx context.Context, companyID, userID uuid.UUID, op SyncOperationInput) error {
	var payload voterNotePayload
	if err := json.Unmarshal(op.Payload, &payload); err != nil {
		return fmt.Errorf("unmarshal voter note payload: %w", err)
	}

	noteID, err := uuid.Parse(payload.ID)
	if err != nil {
		noteID, err = uuid.Parse(op.EntityID)
		if err != nil {
			return fmt.Errorf("parse note ID: %w", err)
		}
	}

	voterID, err := uuid.Parse(payload.VoterID)
	if err != nil {
		return fmt.Errorf("parse voter ID: %w", err)
	}

	var turfID pgtype.UUID
	if payload.TurfID != "" {
		parsed, err := uuid.Parse(payload.TurfID)
		if err != nil {
			return fmt.Errorf("parse turf ID: %w", err)
		}
		turfID = pgtype.UUID{Bytes: parsed, Valid: true}
	}

	visibility := payload.Visibility
	if visibility == "" {
		visibility = "team"
	}

	createdAt := time.Now()
	if payload.CreatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.CreatedAt); err == nil {
			createdAt = parsed
		}
	}

	updatedAt := createdAt
	if payload.UpdatedAt != "" {
		if parsed, err := time.Parse(time.RFC3339, payload.UpdatedAt); err == nil {
			updatedAt = parsed
		}
	}

	return s.queries.UpsertVoterNoteFromSync(ctx, db.UpsertVoterNoteFromSyncParams{
		ID:         noteID,
		CompanyID:  companyID,
		VoterID:    voterID,
		UserID:     userID,
		TurfID:     turfID,
		Content:    payload.Content,
		Visibility: visibility,
		CreatedAt:  createdAt,
		UpdatedAt:  updatedAt,
	})
}

// SyncVoterNoteRow represents a voter note row returned for sync pull.
type SyncVoterNoteRow struct {
	ID         uuid.UUID
	VoterID    uuid.UUID
	UserID     uuid.UUID
	TurfID     uuid.UUID
	Content    string
	Visibility string
	CreatedAt  time.Time
	UpdatedAt  time.Time
}

// PullVoterNotesResult contains the result of a voter note pull operation.
type PullVoterNotesResult struct {
	VoterNotes []SyncVoterNoteRow
	NextCursor string
	HasMore    bool
}

// PullVoterNotes returns voter notes created since cursor, scoped to turfs and role.
// Uses raw pgxpool for role-scoped filtering (complex WHERE clause).
func (s *VoterNotesService) PullVoterNotes(ctx context.Context, companyID uuid.UUID, turfIDs []uuid.UUID, roleLevel int, userID uuid.UUID, sinceCursor string, batchSize int32) (*PullVoterNotesResult, error) {
	if batchSize <= 0 || batchSize > 500 {
		batchSize = 500
	}

	if len(turfIDs) == 0 {
		return &PullVoterNotesResult{}, nil
	}

	var sinceTime time.Time
	if sinceCursor != "" {
		var err error
		sinceTime, err = time.Parse(time.RFC3339Nano, sinceCursor)
		if err != nil {
			return nil, fmt.Errorf("parse cursor: %w", err)
		}
	} else {
		sinceTime = time.Date(1970, 1, 1, 0, 0, 0, 0, time.UTC)
	}

	query := `
		SELECT vn.id, vn.voter_id, vn.user_id, vn.turf_id,
			vn.content, vn.visibility, vn.created_at, vn.updated_at
		FROM voter_notes vn
		WHERE vn.company_id = $1
			AND vn.turf_id = ANY($2::uuid[])
			AND vn.created_at > $3
			AND (
				$4 >= 80
				OR ($4 >= 60 AND vn.visibility IN ('org', 'team'))
				OR (vn.visibility = 'org')
				OR (vn.user_id = $5)
			)
		ORDER BY vn.created_at ASC
		LIMIT $6`

	rows, err := s.pool.Query(ctx, query, companyID, turfIDs, sinceTime, roleLevel, userID, batchSize+1)
	if err != nil {
		return nil, fmt.Errorf("pull voter notes: %w", err)
	}
	defer rows.Close()

	var notes []SyncVoterNoteRow
	for rows.Next() {
		var n SyncVoterNoteRow
		if err := rows.Scan(
			&n.ID, &n.VoterID, &n.UserID, &n.TurfID,
			&n.Content, &n.Visibility, &n.CreatedAt, &n.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan voter note row: %w", err)
		}
		notes = append(notes, n)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("iterate voter note rows: %w", err)
	}

	hasMore := len(notes) > int(batchSize)
	if hasMore {
		notes = notes[:batchSize]
	}

	var nextCursor string
	if len(notes) > 0 {
		nextCursor = notes[len(notes)-1].CreatedAt.Format(time.RFC3339Nano)
	}

	return &PullVoterNotesResult{
		VoterNotes: notes,
		NextCursor: nextCursor,
		HasMore:    hasMore,
	}, nil
}
