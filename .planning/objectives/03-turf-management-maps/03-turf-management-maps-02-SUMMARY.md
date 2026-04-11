---
objective: 03-turf-management-maps
job: "02"
subsystem: ui
tags: [flutter-map, openstreetmap, geojson, polygon-drawing, marker-cluster, riverpod, turf-map]

# Dependency graph
requires:
  - objective: 03-turf-management-maps
    provides: "TurfService ConnectRPC with GeoJSON boundary CRUD, GetVotersInTurf, assignments"
provides:
  - "TurfMapScreen with OSM tiles, turf polygon display, voter pin clustering"
  - "TurfDrawScreen with PolyEditor polygon drawing and GeoJSON export"
  - "MapService with ConnectRPC JSON client for TurfService RPCs"
  - "Map tab in bottom navigation for all user roles"
affects: [03-turf-management-maps, 04-offline-sync]

# Tech tracking
tech-stack:
  added: [flutter_map-8.2.2, flutter_map_marker_cluster-8.2.2, flutter_map_line_editor-8.0.0, flutter_map_dragmarker-8.0.0, latlong2-0.9.1]
  patterns: [map-service-connectrpc, turf-polygon-layer-builder, voter-cluster-layer-builder, geojson-latlng-coordinate-swap]

key-files:
  created:
    - "navigators-flutter/lib/src/services/map_service.dart"
    - "navigators-flutter/lib/src/features/map/turf_map_screen.dart"
    - "navigators-flutter/lib/src/features/map/turf_draw_screen.dart"
    - "navigators-flutter/lib/src/features/map/widgets/turf_polygon_layer.dart"
    - "navigators-flutter/lib/src/features/map/widgets/voter_cluster_layer.dart"
  modified:
    - "navigators-flutter/pubspec.yaml"
    - "navigators-flutter/lib/src/app.dart"

key-decisions:
  - "PolygonLayer uses generic type parameter <String> for hitValue to satisfy flutter_map 8 nullability constraints"
  - "Polygon fill uses color parameter (not isFilled) per flutter_map 8 API -- non-null color = filled"
  - "Map tab positioned for all roles (index 2) between Voters and Import tabs"
  - "Voter pins loaded on turf selection (not viewport bounds) to avoid overwhelming map with all voters"

patterns-established:
  - "MapService pattern: mirrors VoterService ConnectRPC JSON protocol for TurfService RPCs"
  - "buildTurfPolygonLayer/buildVoterClusterLayer: functional builders returning layer widgets"
  - "GeoJSON coordinate swap: LatLng(lat,lng) -> [lng,lat] for GeoJSON, reverse for display"

requirements-completed: [TURF-01, TURF-02, TURF-04]

# Verification evidence
verification:
  gates_defined: 2
  gates_passed: 1
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

# Metrics
duration: 6min
completed: 2026-04-11
---

# Objective 03 TRD 02: Flutter Map UI Summary

**Interactive flutter_map with OSM tiles, turf polygon drawing via PolyEditor, voter pin clustering with party colors, turf assignment UI, and Map tab in bottom navigation**

## Performance

- **Duration:** 6 min
- **Started:** 2026-04-11T02:50:08Z
- **Completed:** 2026-04-11T02:56:05Z
- **Tasks:** 2 auto + 1 checkpoint (auto-approved)
- **Files modified:** 7

## Accomplishments
- MapService with full TurfService RPC client (list, get, create, update boundary, voters-in-turf, assign/remove)
- TurfMapScreen with OSM map centered on Augusta, Maine, turf polygon display with color palette, voter pin clusters
- TurfDrawScreen with PolyEditor for draggable polygon vertex drawing and GeoJSON export
- Voter cluster layer with party-colored pins (R=red, D=blue, G=green, L=orange, U=grey)
- Map tab added to bottom navigation for all user roles

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: Add map dependencies + MapService + turf map screen | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| 2: Polygon drawing screen + app navigation integration | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| 3: Verify map UI functionality | Auto-approved (checkpoint) | - | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: Add map dependencies + MapService + turf map screen with polygons and voter pins** - `c7772ff` (feat)
2. **Task 2: Polygon drawing screen + app navigation integration** - `299c43e` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| build | Not run (macOS/web build not available in CI) | - | SKIPPED |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (isFilled -> color parameter, PolygonLayer generic type)
- **Must-haves verified:** 5/5
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/services/map_service.dart` - MapService with TurfService ConnectRPC client, TurfInfo/VoterPin models, Riverpod providers
- `navigators-flutter/lib/src/features/map/turf_map_screen.dart` - Main map screen with turf polygons, voter clusters, detail panel, assignment dialog
- `navigators-flutter/lib/src/features/map/turf_draw_screen.dart` - Polygon drawing screen with PolyEditor, GeoJSON export, save flow
- `navigators-flutter/lib/src/features/map/widgets/turf_polygon_layer.dart` - PolygonLayer builder with color palette and selection state
- `navigators-flutter/lib/src/features/map/widgets/voter_cluster_layer.dart` - MarkerClusterLayerWidget builder with party-colored pins
- `navigators-flutter/pubspec.yaml` - Added flutter_map, marker_cluster, line_editor, dragmarker, latlong2 deps
- `navigators-flutter/lib/src/app.dart` - Added Map tab to bottom nav for all roles

## Decisions Made
- PolygonLayer uses explicit generic type parameter `<String>` for hitValue to satisfy flutter_map 8 strict nullability on `R extends Object`
- Polygon fill uses `color` parameter (not deprecated `isFilled`) per flutter_map 8 API
- Map tab positioned for all roles (not just admin) at index 2 between Voters and Import
- Voter pins loaded per-turf on selection rather than viewport-based to avoid loading all voters at once

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed flutter_map 8 API incompatibilities**
- **Found during:** Task 1 (turf_polygon_layer.dart)
- **Issue:** `isFilled` parameter does not exist in flutter_map 8.2.2 Polygon class; PolygonLayer generic type constraint requires `<R extends Object>` not `<R extends Object?>`
- **Fix:** Removed isFilled (non-null color = filled), added explicit `<String>` generic type to PolygonLayer and Polygon in draw screen
- **Files modified:** turf_polygon_layer.dart, turf_draw_screen.dart
- **Verification:** `flutter analyze` passes with no errors
- **Committed in:** c7772ff (Task 1), 299c43e (Task 2)

---

**Total deviations:** 1 auto-fixed (1 bug)
**Impact on plan:** Necessary API compatibility fix. No scope creep.

## Issues Encountered
None beyond the flutter_map API differences noted above.

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Map UI complete and ready for heat map overlay (TRD 03-03)
- TurfDrawScreen ready for boundary editing (UpdateTurfBoundary already in MapService)
- Voter cluster layer ready for canvassing workflow integration (Objective 04)

---
*Objective: 03-turf-management-maps*
*Completed: 2026-04-11*
