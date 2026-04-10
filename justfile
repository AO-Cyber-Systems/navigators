# Load .env.dev
set dotenv-filename := ".env.dev"

# Start infrastructure
infra:
  docker compose up -d

# Stop infrastructure
infra-down:
  docker compose down

# Run Go server
dev-go:
  cd navigators-go && go run ./cmd/server

# Run Flutter app
dev-flutter:
  cd navigators-flutter && flutter run

# Generate proto (requires buf)
generate:
  cd navigators-go && buf generate

# Run Go tests
test-go:
  cd navigators-go && go test ./...

# Run sqlc generate
sqlc:
  cd navigators-go && sqlc generate

# Run all migrations fresh (drop + recreate DB)
db-reset:
  docker compose exec postgres psql -U navigators -c "DROP DATABASE IF EXISTS navigators_dev;"
  docker compose exec postgres psql -U navigators -c "CREATE DATABASE navigators_dev;"
  just dev-go
