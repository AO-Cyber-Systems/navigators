package navigators

import (
	"context"
	"fmt"
	"log/slog"

	firebase "firebase.google.com/go/v4"
	"firebase.google.com/go/v4/messaging"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"

	"github.com/aocybersystems/eden-platform-go/platform/notification"
)

// FCMDispatcher implements notification.Dispatcher using Firebase Admin SDK.
type FCMDispatcher struct {
	client *messaging.Client
	pool   *pgxpool.Pool // shared pool for device_tokens queries
}

// NewFCMDispatcher creates a new FCMDispatcher from a Firebase app.
func NewFCMDispatcher(app *firebase.App, pool *pgxpool.Pool) (*FCMDispatcher, error) {
	client, err := app.Messaging(context.Background())
	if err != nil {
		return nil, fmt.Errorf("create FCM client: %w", err)
	}
	return &FCMDispatcher{client: client, pool: pool}, nil
}

// SendPush sends push notifications to the given device tokens using SendEachForMulticast.
// Cleans stale tokens on IsRegistrationTokenNotRegistered errors.
func (d *FCMDispatcher) SendPush(ctx context.Context, tokens []notification.DeviceTokenRecord, title, body string, data map[string]string) error {
	if len(tokens) == 0 {
		return nil
	}

	// Extract token strings
	tokenStrings := make([]string, len(tokens))
	for i, t := range tokens {
		tokenStrings[i] = t.Token
	}

	msg := &messaging.MulticastMessage{
		Tokens: tokenStrings,
		Notification: &messaging.Notification{
			Title: title,
			Body:  body,
		},
		Data: data,
	}

	resp, err := d.client.SendEachForMulticast(ctx, msg)
	if err != nil {
		return fmt.Errorf("send FCM multicast: %w", err)
	}

	// Clean stale tokens
	for i, sendResp := range resp.Responses {
		if sendResp.Error != nil {
			if messaging.IsRegistrationTokenNotRegistered(sendResp.Error) {
				slog.Info("cleaning stale FCM token", "token_prefix", tokenStrings[i][:min(8, len(tokenStrings[i]))])
				if err := d.DeleteDeviceToken(ctx, tokens[i].Token, tokens[i].UserID); err != nil {
					slog.Warn("failed to delete stale device token", "error", err)
				}
			} else {
				slog.Warn("FCM send error for token", "error", sendResp.Error, "token_index", i)
			}
		}
	}

	slog.Debug("FCM multicast sent", "success", resp.SuccessCount, "failure", resp.FailureCount)
	return nil
}

// IsEnabled returns true if the FCM client is configured.
func (d *FCMDispatcher) IsEnabled() bool {
	return d.client != nil
}

// GetTokensForUser queries device tokens for a user from the eden device_tokens table.
func (d *FCMDispatcher) GetTokensForUser(ctx context.Context, userID uuid.UUID) ([]notification.DeviceTokenRecord, error) {
	rows, err := d.pool.Query(ctx, "SELECT token, platform, user_id FROM device_tokens WHERE user_id = $1", userID)
	if err != nil {
		return nil, fmt.Errorf("query device tokens: %w", err)
	}
	defer rows.Close()

	var tokens []notification.DeviceTokenRecord
	for rows.Next() {
		var t notification.DeviceTokenRecord
		if err := rows.Scan(&t.Token, &t.Platform, &t.UserID); err != nil {
			return nil, fmt.Errorf("scan device token: %w", err)
		}
		tokens = append(tokens, t)
	}
	return tokens, rows.Err()
}

// RegisterDeviceToken registers a device token for push notifications.
// Uses INSERT ON CONFLICT DO NOTHING for idempotency.
func (d *FCMDispatcher) RegisterDeviceToken(ctx context.Context, userID uuid.UUID, token, platform string) error {
	_, err := d.pool.Exec(ctx,
		"INSERT INTO device_tokens (user_id, token, platform) VALUES ($1, $2, $3) ON CONFLICT (user_id, token) DO NOTHING",
		userID, token, platform,
	)
	if err != nil {
		return fmt.Errorf("register device token: %w", err)
	}
	return nil
}

// DeleteDeviceToken removes a specific device token.
func (d *FCMDispatcher) DeleteDeviceToken(ctx context.Context, token string, userID uuid.UUID) error {
	_, err := d.pool.Exec(ctx,
		"DELETE FROM device_tokens WHERE token = $1 AND user_id = $2",
		token, userID,
	)
	if err != nil {
		return fmt.Errorf("delete device token: %w", err)
	}
	return nil
}
