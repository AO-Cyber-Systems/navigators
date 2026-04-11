package navigators

import (
	"encoding/json"
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"net/url"
	"strings"

	twilioClient "github.com/twilio/twilio-go/client"

	"github.com/nats-io/nats.go/jetstream"
)

// InboundSMSEvent represents an inbound SMS message from Twilio, published to NATS.
type InboundSMSEvent struct {
	MessageSid          string `json:"message_sid"`
	From                string `json:"from"`
	To                  string `json:"to"`
	Body                string `json:"body"`
	OptOutType          string `json:"opt_out_type"`
	MessagingServiceSid string `json:"messaging_service_sid"`
}

// StatusUpdateEvent represents a delivery status update from Twilio, published to NATS.
type StatusUpdateEvent struct {
	MessageSid    string `json:"message_sid"`
	MessageStatus string `json:"message_status"`
	ErrorCode     string `json:"error_code"`
}

// SMSWebhookHandler handles Twilio webhook HTTP requests.
// NOT a ConnectRPC handler -- plain HTTP handlers registered on mux directly.
type SMSWebhookHandler struct {
	js        jetstream.JetStream
	authToken string
}

// NewSMSWebhookHandler creates a new SMSWebhookHandler.
func NewSMSWebhookHandler(js jetstream.JetStream, authToken string) *SMSWebhookHandler {
	return &SMSWebhookHandler{
		js:        js,
		authToken: authToken,
	}
}

// HandleInbound handles inbound SMS webhooks from Twilio.
// Validates the Twilio signature, parses the form, publishes to NATS, returns TwiML.
func (h *SMSWebhookHandler) HandleInbound(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read and validate Twilio signature
	if !h.validateTwilioSignature(r) {
		slog.Warn("invalid Twilio signature on inbound webhook")
		http.Error(w, "invalid signature", http.StatusForbidden)
		return
	}

	// Parse form data
	if err := r.ParseForm(); err != nil {
		slog.Error("failed to parse inbound webhook form", "error", err)
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	event := InboundSMSEvent{
		MessageSid:          r.FormValue("MessageSid"),
		From:                r.FormValue("From"),
		To:                  r.FormValue("To"),
		Body:                r.FormValue("Body"),
		OptOutType:          r.FormValue("OptOutType"),
		MessagingServiceSid: r.FormValue("MessagingServiceSid"),
	}

	data, err := json.Marshal(event)
	if err != nil {
		slog.Error("failed to marshal inbound event", "error", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	// Publish to NATS for async processing
	if _, err := h.js.Publish(r.Context(), "navigators.sms.inbound", data); err != nil {
		slog.Error("failed to publish inbound SMS to NATS", "error", err, "message_sid", event.MessageSid)
		// Still return 200 to Twilio to prevent retries -- we log the error
		// and the message data is lost (acceptable for v1; add dead letter later)
	}

	// Return empty TwiML response
	w.Header().Set("Content-Type", "application/xml")
	w.WriteHeader(http.StatusOK)
	fmt.Fprint(w, "<Response></Response>")
}

// HandleStatus handles delivery status callback webhooks from Twilio.
// Validates the Twilio signature, parses the form, publishes to NATS.
func (h *SMSWebhookHandler) HandleStatus(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}

	// Read and validate Twilio signature
	if !h.validateTwilioSignature(r) {
		slog.Warn("invalid Twilio signature on status webhook")
		http.Error(w, "invalid signature", http.StatusForbidden)
		return
	}

	// Parse form data
	if err := r.ParseForm(); err != nil {
		slog.Error("failed to parse status webhook form", "error", err)
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	event := StatusUpdateEvent{
		MessageSid:    r.FormValue("MessageSid"),
		MessageStatus: r.FormValue("MessageStatus"),
		ErrorCode:     r.FormValue("ErrorCode"),
	}

	data, err := json.Marshal(event)
	if err != nil {
		slog.Error("failed to marshal status event", "error", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}

	// Publish to NATS for async processing
	if _, err := h.js.Publish(r.Context(), "navigators.sms.status", data); err != nil {
		slog.Error("failed to publish status update to NATS", "error", err, "message_sid", event.MessageSid)
	}

	w.WriteHeader(http.StatusOK)
}

// validateTwilioSignature validates the X-Twilio-Signature header against the request.
func (h *SMSWebhookHandler) validateTwilioSignature(r *http.Request) bool {
	if h.authToken == "" {
		// If no auth token configured, skip validation (dev mode)
		slog.Warn("Twilio auth token not configured, skipping webhook signature validation")
		return true
	}

	signature := r.Header.Get("X-Twilio-Signature")
	if signature == "" {
		return false
	}

	// Reconstruct the full URL that Twilio used to generate the signature
	requestURL := reconstructURL(r)

	// Read body for validation, then reset for ParseForm
	bodyBytes, err := io.ReadAll(r.Body)
	if err != nil {
		slog.Error("failed to read request body for signature validation", "error", err)
		return false
	}
	r.Body = io.NopCloser(strings.NewReader(string(bodyBytes)))

	// Parse the form values from the body
	params, err := url.ParseQuery(string(bodyBytes))
	if err != nil {
		slog.Error("failed to parse body for signature validation", "error", err)
		return false
	}

	// Convert url.Values to map[string]string (Twilio validator expects single values)
	paramMap := make(map[string]string)
	for key, values := range params {
		if len(values) > 0 {
			paramMap[key] = values[0]
		}
	}

	validator := twilioClient.NewRequestValidator(h.authToken)
	return validator.Validate(requestURL, paramMap, signature)
}

// reconstructURL rebuilds the full request URL from the HTTP request.
func reconstructURL(r *http.Request) string {
	scheme := "https"
	if r.TLS == nil {
		// Check X-Forwarded-Proto for reverse proxy
		if proto := r.Header.Get("X-Forwarded-Proto"); proto != "" {
			scheme = proto
		} else {
			scheme = "http"
		}
	}

	host := r.Host
	if fwdHost := r.Header.Get("X-Forwarded-Host"); fwdHost != "" {
		host = fwdHost
	}

	return scheme + "://" + host + r.RequestURI
}
