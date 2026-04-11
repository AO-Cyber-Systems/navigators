---
objective: 03-turf-management-maps
job: "03"
subsystem: ui
tags: [fmtc, offline-tiles, heat-map, walk-list, canvas, flutter-map, riverpod]

requires:
  - objective: 03-turf-management-maps-02
    provides: "TurfMapScreen with polygon drawing, voter clusters, MapService with turf CRUD"
  - objective: 03-turf-management-maps-01
    provides: "Go backend with turf spatial queries, walk lists, contact logs, density grid, turf stats"
provides:
  - "FMTC offline tile downloading scoped to turf polygon boundaries"
  - "Heat map Canvas overlay with density and support color modes"
  - "Walk list screen with route-optimized voter ordering"
  - "Turf dashboard with completion progress bars and stats"
  - "TileCacheService for per-turf offline store management"
affects: [objective-04, objective-06, objective-08]

tech-stack:
  added: [flutter_map_tile_caching, url_launcher]
  patterns: [CustomPainter-for-map-overlay, FMTC-per-turf-store, debounced-viewport-fetch]

key-files:
  created:
    - navigators-flutter/lib/src/services/tile_cache_service.dart
    - navigators-flutter/lib/src/features/map/offline_download_screen.dart
    - navigators-flutter/lib/src/features/map/walk_list_screen.dart
    - navigators-flutter/lib/src/features/map/heat_map_overlay.dart
    - navigators-flutter/lib/src/features/map/widgets/heat_map_painter.dart
    - navigators-flutter/lib/src/features/map/turf_dashboard_screen.dart
  modified:
    - navigators-flutter/pubspec.yaml
    - navigators-flutter/lib/main.dart
    - navigators-flutter/lib/src/services/map_service.dart
    - navigators-flutter/lib/src/features/map/turf_map_screen.dart

key-decisions:
  - "FMTC store naming convention: 'turf-{turfId}' for unique per-turf caching"
  - "Heat map uses CustomPainter with getOffsetFromOrigin (not deprecated project method) for flutter_map 8 compatibility"
  - "FMTC countTiles API used (check is deprecated in 10.1.1)"
  - "startForeground returns record with .downloadProgress and .tileEvents streams"

patterns-established:
  - "CustomPainter overlay: extend CustomPainter, use MapCamera.getOffsetFromOrigin for LatLng-to-screen projection"
  - "Debounced map data fetch: 300ms timer on mapEventStream for viewport-dependent API calls"
  - "FMTC per-turf stores: FMTCStore('turf-$id') with BrowseStoreStrategy.readUpdateCreate + cacheFirst"

requirements-completed: [TURF-05, TURF-06, TURF-07, TURF-08]

verification:
  gates_defined: 2
  gates_passed: 2
  auto_fix_cycles: 1
  tdd_evidence: false
  test_pairing: false

duration: 9min
completed: 2026-04-11
---

# Objective 3 TRD 03: Offline Tiles, Heat Map, Walk List, Turf Dashboard Summary

**FMTC offline tile downloading for turf polygons, Canvas-based heat map with density/support modes, route-optimized walk list, and turf dashboard with completion tracking**

## Performance

- **Duration:** 9 min
- **Started:** 2026-04-11T02:59:13Z
- **Completed:** 2026-04-11T03:08:54Z
- **Tasks:** 2 auto + 1 checkpoint (auto-approved)
- **Files modified:** 10

## Accomplishments
- Navigator can download offline map tiles scoped to their turf polygon (FMTC with zoom 12-18, rate limited 200 tiles/sec)
- Heat map overlay renders density or support colored gradients via CustomPainter, updating on pan/zoom with 300ms debounce
- Walk list shows route-optimized voter order with sequence numbers, party badges, and map view toggle with route polyline
- Turf dashboard displays all turfs with voter count, area, completion progress bars, search, and sorting
- TurfMapScreen integrates all features: heat map toggle, walk list navigation, offline download, FMTC tile provider for cached turfs

## Task Evidence

| Task | Verify Command | Exit Code | Status |
|---|---|---|---|
| 1: FMTC offline tiles + walk list + map_service extensions | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| 2: Heat map overlay + turf dashboard + map screen integration | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| 3: Checkpoint human-verify | Auto-approved | - | PASS |

## Task Commits

Each task was committed atomically:

1. **Task 1: FMTC offline tiles + walk list screen + map_service extensions** - `26be6ee` (feat)
2. **Task 2: Heat map overlay + turf dashboard + map screen integration** - `a14db38` (feat)

## Validation Gate Results

| Gate | Command | Exit Code | Status |
|---|---|---|---|
| lint | `cd navigators-flutter && flutter analyze` | 0 | PASS |
| build | `cd navigators-flutter && flutter build apk --debug` | 0 | PASS |

## Post-TRD Verification

- **Auto-fix cycles used:** 1 (FMTC API corrections for flutter_map 8 / FMTC 10.1.1)
- **Must-haves verified:** 6/6
- **Gate failures:** None

## Files Created/Modified
- `navigators-flutter/lib/src/services/tile_cache_service.dart` - FMTC store management, tile estimation, download streaming, per-turf tile provider (GPL-3 license noted)
- `navigators-flutter/lib/src/features/map/offline_download_screen.dart` - Download progress UI with estimation, cancel, delete cache
- `navigators-flutter/lib/src/features/map/walk_list_screen.dart` - Route-optimized voter list with map view toggle and navigation
- `navigators-flutter/lib/src/features/map/heat_map_overlay.dart` - FlutterMap child with debounced viewport density grid fetching
- `navigators-flutter/lib/src/features/map/widgets/heat_map_painter.dart` - CustomPainter with radial gradient circles for density/support modes
- `navigators-flutter/lib/src/features/map/turf_dashboard_screen.dart` - All turfs with stats, completion bars, search, sort
- `navigators-flutter/lib/src/services/map_service.dart` - Added WalkListVoter, TurfStats, DensityGridCell models; generateWalkList, getTurfStats, getVoterDensityGrid methods
- `navigators-flutter/lib/src/features/map/turf_map_screen.dart` - Integrated heat map toggle, walk list, offline download, dashboard, FMTC tile provider, completion stats
- `navigators-flutter/pubspec.yaml` - Added flutter_map_tile_caching ^10.1.1, url_launcher ^6.3.0
- `navigators-flutter/lib/main.dart` - FMTC ObjectBox backend initialization before runApp

## Decisions Made
- FMTC store naming convention: 'turf-{turfId}' for unique per-turf caching
- Heat map uses MapCamera.getOffsetFromOrigin (not deprecated project) for flutter_map 8 compatibility
- Used countTiles instead of deprecated check method in FMTC 10.1.1
- startForeground returns a record type; access .downloadProgress stream from it
- DownloadProgress uses attemptedTilesCount/maxTilesCount (not attemptedTiles/maxTiles)
- Store stats use .length (not .tileCount) in FMTC 10.1.1 API

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Fixed FMTC 10.1.1 API mismatches**
- **Found during:** Task 1 (tile_cache_service, offline_download_screen)
- **Issue:** Research context had slightly incorrect FMTC API names (check vs countTiles, startForeground return type, DownloadProgress field names, store stats fields)
- **Fix:** Updated to correct FMTC 10.1.1 API: countTiles(), .downloadProgress stream from record, attemptedTilesCount/maxTilesCount, stats.length
- **Files modified:** tile_cache_service.dart, offline_download_screen.dart
- **Verification:** flutter analyze passes with 0 errors
- **Committed in:** 26be6ee (Task 1 commit)

**2. [Rule 3 - Blocking] Fixed flutter_map 8 MapCamera API**
- **Found during:** Task 2 (heat_map_painter, heat_map_overlay)
- **Issue:** Used camera.project() (removed in flutter_map 8) and camera.size.x/.y (Size uses .width/.height)
- **Fix:** Used camera.getOffsetFromOrigin() for projection, camera.size.width/.height for dimensions
- **Files modified:** heat_map_painter.dart, heat_map_overlay.dart
- **Verification:** flutter analyze passes
- **Committed in:** a14db38 (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (2 blocking API issues)
**Impact on plan:** Both were necessary API corrections. No scope creep.

## Issues Encountered
None beyond the API corrections documented above.

## User Setup Required
None - no external service configuration required.

## Next Objective Readiness
- Objective 3 (Turf Management + Maps) is fully complete with all 3 TRDs executed
- Full map workflow: turf creation, voter pins, offline tiles, heat maps, walk lists, dashboard
- Ready for Objective 4 (Contact Logging + Canvassing)

---
*Objective: 03-turf-management-maps*
*Completed: 2026-04-11*
