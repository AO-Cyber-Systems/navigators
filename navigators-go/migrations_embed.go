package navigators

import "embed"

//go:embed migrations/navigators/*.sql
var NavigatorsMigrationsFS embed.FS
