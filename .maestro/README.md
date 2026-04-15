# Navigators Maestro E2E flows

End-to-end UI flows for the Navigators Flutter app, driven by
[Maestro](https://maestro.mobile.dev). Selectors come from the
`semanticsIdentifier` values documented in
`navigators-flutter/SEMANTICS.md`.

All flows target `appId: com.mainegop.navigators` (see
`navigators-flutter/android/app/build.gradle.kts`).

## Layout

```
.maestro/
  auth/
    login-admin.yaml          # reusable: log in as seeded admin
    login-navigator.yaml      # reusable: log in as plain navigator
  gap-closures/
    02-04-suppression-admin.yaml
    02-04-suppression-non-admin.yaml
    07-03-call-script-crud.yaml
    08-04-no-firebase-errors.yaml
    10-03-training-upload.yaml
```

The `gap-closures/*` flows start with
`runFlow: ../auth/login-<role>.yaml`, so they each run against a freshly
authenticated app.

## Seed credentials

All flows use accounts from `seed_data.sql`. The seeded password for every
user is `testtest` (see the header of that file).

| Role      | Email                     | Used by                          |
| --------- | ------------------------- | -------------------------------- |
| admin     | `admin@mainegop.test`     | `auth/login-admin.yaml`          |
| navigator | `nav2@mainegop.test`      | `auth/login-navigator.yaml`      |

## Running

```bash
# one flow
MAESTRO_PW=testtest maestro test .maestro/gap-closures/02-04-suppression-admin.yaml

# all gap-closure flows
MAESTRO_PW=testtest maestro test .maestro/gap-closures/

# override credentials per-run
maestro test \
  -e EMAIL=someone@mainegop.test \
  -e PASSWORD=hunter2 \
  .maestro/auth/login-admin.yaml
```

## Environment variables

| Var          | Default              | Flows                           |
| ------------ | -------------------- | ------------------------------- |
| `EMAIL`      | per-flow default     | `auth/*`                        |
| `PASSWORD`   | `${MAESTRO_PW}`      | `auth/*` (required)             |
| `MAESTRO_PW` | (none)               | substituted into `PASSWORD`     |

If `MAESTRO_PW` is unset the `auth/*` flows will fail on the password field
input. Export it for the session or pass `-e PASSWORD=...` directly.

## Open TODOs

Each flow documents its own TODOs inline; the big ones:

- **07-03 call-script CRUD** — `CallScriptManagerScreen` is not yet wired
  into any nav entry in `lib/src/app.dart`. The flow is written against the
  real identifiers but is currently gated on `nav-home` as a stop-gap.
- **10-03 training upload** — the file-picker step launches the platform
  SAF picker, which lives in a different `appId` than the Flutter app.
  Requires either a pre-pushed fixture + a SAF sub-flow or a
  test-only in-app file source.
- **08-04 no Firebase errors** — Maestro can't read logcat; pair the flow
  with an `adb logcat` scrape in CI to get real signal.
- **02-04 non-admin** — hardening: seed a known-suppressed voter for the
  navigator's turf so the 'Suppressed' badge can also be asserted in
  read-only mode.

## Local artifacts

Maestro writes traces / screenshots under `~/.maestro/tests/` by default,
not into this repo, so no `.gitignore` entry is needed here. If a future
flow uses `- takeScreenshot: foo` with a relative path, those files will
land next to the flow file — add `.maestro/**/*.png` to the repo
`.gitignore` at that point.
