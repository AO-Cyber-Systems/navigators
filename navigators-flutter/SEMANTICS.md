# Semantics Identifiers Convention

All interactive widgets in the Navigators Flutter app carry a stable
`semanticsIdentifier` so Maestro can drive end-to-end tests against the OS
accessibility tree (iOS `accessibilityIdentifier`, Android `resource-id`).

## Convention

`<feature>-<role>[-<id-or-index>]` in **kebab-case**.

- **feature**: the screen/flow (e.g. `voter-list`, `sms-campaign-create`,
  `training-upload`, `phone-call`)
- **role**: what the element does (e.g. `-btn`, `-submit`, `-fab`,
  `-search`, `-row`, `-screen`, `-dialog`, `-cancel`, `-confirm`,
  `-filter-<name>`)
- **id**: the stable server id for list rows (`voter-list-row-${voterId}`);
  fallback to index only if no id exists
- **screen roots** end in `-screen` and wrap the `Scaffold` with
  `Semantics(identifier: ..., explicitChildNodes: true, child: Scaffold(...))`.

## Examples

```dart
// Screen root
return Semantics(
  identifier: 'voter-detail-screen',
  explicitChildNodes: true,
  child: Scaffold(...),
);

// Button (no direct semanticsIdentifier param -> wrap)
Semantics(
  identifier: 'voter-detail-suppress-btn',
  button: true,
  child: EdenButton(label: 'Suppress', onPressed: _handle),
);

// TextField
Semantics(
  identifier: 'login-email',
  textField: true,
  child: TextField(controller: _emailCtl),
);

// List row (prefer stable id)
Semantics(
  identifier: 'voter-list-row-${voter.id}',
  button: true,
  child: ListTile(onTap: ..., title: Text(voter.name)),
);
```

## Rules

- Only tag **interactive** widgets (buttons, inputs, taps, FABs, nav items,
  dialog actions) and **screen roots**. Never tag static labels or
  decoration.
- Never alter `semanticsLabel` or other accessibility-announced text.
  `semanticsIdentifier` is a separate field.
- Never remove an existing `key: Key(...)` — add `Semantics` alongside.
- Never modify generated files (`*.g.dart`, `*.freezed.dart`, `build/`).
- `EdenNavItem` entries can't carry identifiers until an upstream
  eden-ui-flutter change lands. `PlatformLoginScreen` lives in eden-libs.
  Both are out-of-scope for this repo.

When adding new interactive widgets, follow this convention so Maestro tests
keep working without flaky text-based selectors.
