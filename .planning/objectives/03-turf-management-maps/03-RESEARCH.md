# Objective 3: Turf Management + Maps - Research

**Researched:** 2026-04-10
**Domain:** Flutter mapping, PostGIS spatial queries, offline tile caching, marker clustering
**Confidence:** HIGH

## Summary

This objective adds interactive map-based turf management to the Navigators app. The backend already has turfs, turf assignments, and voters with PostGIS POINT locations and GIST indexes. The primary work is: (1) extending the backend to store/query polygon boundaries and perform spatial voter lookups, (2) building a Flutter map UI with polygon drawing, marker clustering, offline tiles, and heat maps.

The standard Flutter mapping stack is **flutter_map 8.x** (BSD-3, vendor-free, OSM-based) with **FMTC 10.x** for offline tile caching (GPL-3, commercial license available), **flutter_map_marker_cluster 8.x** for pin clustering, and **flutter_map_line_editor 8.x** for interactive polygon drawing. The heat map requirement is the one area requiring custom implementation, as the existing flutter_map_heatmap package is incompatible with flutter_map 8.

**Primary recommendation:** Use flutter_map 8.2.2 as the map engine, FMTC 10.1.1 for offline tiles (negotiate commercial license or accept GPL), flutter_map_marker_cluster 8.2.2 for clustering, flutter_map_line_editor 8.0.0 for polygon drawing, and server-side generated heat map tiles via a custom approach using Canvas/CustomPainter overlay.

<phase_requirements>
## Objective Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| TURF-01 | Admin can draw turf polygon boundaries on interactive map | flutter_map + flutter_map_line_editor for polygon drawing; GeoJSON transfer to backend; PostGIS ST_GeomFromGeoJSON for storage |
| TURF-02 | Admin can assign turfs to Navigators | Already implemented in turf_handler.go (AssignUserToTurf). Proto needs boundary field additions for TurfInfo |
| TURF-03 | System auto-populates voter list for each turf using PostGIS spatial queries | PostGIS ST_Contains with GIST index on voters.location; new SQL query GetVotersInTurf |
| TURF-04 | User can view voters as clustered pins on map | flutter_map_marker_cluster 8.2.2 with MarkerClusterLayerWidget; load voter lat/lng from API |
| TURF-05 | Navigator can download offline map tiles for assigned turf via FMTC | FMTC 10.1.1 CustomPolygonRegion for turf boundary; FMTCTileProvider with BrowseLoadingStrategy.cacheFirst |
| TURF-06 | System generates route-optimized walk lists (nearest-neighbor) | PostGIS KNN operator (<->) with recursive CTE or server-side Go nearest-neighbor O(n^2) loop |
| TURF-07 | System tracks turf completion progress (% voters contacted) | SQL COUNT with LEFT JOIN on contact_logs; server-computed percentage per turf |
| TURF-08 | Admin can view geographic heat maps of contact density and support levels | Custom Canvas/CustomPainter overlay on flutter_map; server-side grid aggregation query |
</phase_requirements>

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| flutter_map | ^8.2.2 | Interactive map widget | #1 non-commercial Flutter map; BSD-3; OSM tiles; cross-platform |
| flutter_map_tile_caching (FMTC) | ^10.1.1 | Offline tile download + browse caching | Only flutter_map offline solution; CustomPolygonRegion support; >1000 tiles/sec |
| flutter_map_marker_cluster | ^8.2.2 | Marker clustering | Compatible with flutter_map 8; animated clusters; popup support |
| flutter_map_line_editor | ^8.0.0 | Interactive polygon drawing | MIT license; tap-to-add, drag-to-move, long-press-delete UX |
| flutter_map_dragmarker | ^8.0.0 | Draggable markers (line_editor dep) | Required by flutter_map_line_editor |
| latlong2 | ^0.9.1 | Lat/lng coordinate type | Standard coordinate type for flutter_map ecosystem |
| PostGIS | (already installed) | Spatial queries | Already enabled via migration 001; GIST indexes on turfs.boundary and voters.location |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| dart:ui (Canvas) | built-in | Custom heat map rendering | TURF-08: paint density overlay on map |
| geojson_vi | ^2.2.0 | GeoJSON parsing in Dart | Parse polygon boundaries from server responses |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| flutter_map | google_maps_flutter | Requires API key, not free, vendor lock-in; flutter_map is open and free |
| flutter_map_marker_cluster | flutter_map_supercluster | supercluster requires flutter_map ^5.0.0 -- INCOMPATIBLE with fm 8 |
| flutter_map_heatmap | custom Canvas overlay | heatmap package requires flutter_map >=7.0.0 <8.0.0 -- INCOMPATIBLE; must build custom |
| FMTC | Manual tile download | FMTC handles pause/resume/recovery/rate-limiting; manual approach loses all of this |

**Installation:**
```bash
# In navigators-flutter/pubspec.yaml add:
flutter_map: ^8.2.2
flutter_map_tile_caching: ^10.1.1
flutter_map_marker_cluster: ^8.2.2
flutter_map_line_editor: ^8.0.0
latlong2: ^0.9.1
```

**FMTC License Note:** FMTC is GPL-3. For a proprietary app like Navigators, you MUST either:
1. Purchase a commercial license from fmtc@jaffaketchup.dev (recommended -- yearly, priced by scale)
2. Open-source the Flutter app under GPL-3 (not appropriate for MaineGOP)
3. Use the non-profit free alternative license if applicable

## Architecture Patterns

### Recommended Project Structure
```
navigators-flutter/lib/src/features/map/
  turf_map_screen.dart        # Main map screen with turf polygons + voter pins
  turf_draw_screen.dart       # Admin polygon drawing screen
  turf_detail_panel.dart      # Turf info overlay (stats, assignments)
  walk_list_screen.dart       # Route-optimized voter walk list
  heat_map_overlay.dart       # Custom painter for heat map
  offline_download_screen.dart # FMTC download progress UI
  widgets/
    voter_cluster_layer.dart  # MarkerClusterLayerWidget config
    turf_polygon_layer.dart   # PolygonLayer with turf boundaries
    heat_map_painter.dart     # CustomPainter for density rendering

navigators-flutter/lib/src/services/
  map_service.dart            # API calls for turf boundaries, voters-in-turf
  tile_cache_service.dart     # FMTC store management + download orchestration

navigators-go/internal/navigators/
  turf_handler.go             # EXTEND: add boundary CRUD, voters-in-turf, walk list
  turf_stats.go               # NEW: completion tracking, heat map grid aggregation

navigators-go/queries/navigators/
  turfs.sql                   # EXTEND: spatial queries
```

### Pattern 1: GeoJSON Polygon Transfer
**What:** Transfer turf boundaries as GeoJSON between Flutter and Go backend via proto string fields.
**When to use:** All turf CRUD operations involving polygon boundaries.
**Example:**
```protobuf
// In turf.proto -- extend CreateTurfRequest and TurfInfo
message CreateTurfRequest {
  string name = 1;
  string description = 2;
  string boundary_geojson = 3; // GeoJSON Polygon geometry string
}

message TurfInfo {
  string turf_id = 1;
  string name = 2;
  string description = 3;
  bool is_active = 4;
  string created_at = 5;
  string updated_at = 6;
  string boundary_geojson = 7;    // GeoJSON for Flutter rendering
  double center_lat = 8;          // ST_Centroid Y
  double center_lng = 9;          // ST_Centroid X
  double area_sq_meters = 10;     // ST_Area(boundary::geography)
  int32 voter_count = 11;         // COUNT of voters in boundary
}
```

```sql
-- Store boundary from GeoJSON
-- name: CreateTurfWithBoundary :one
INSERT INTO turfs (company_id, name, description, boundary)
VALUES ($1, $2, $3, ST_GeomFromGeoJSON($4))
RETURNING id, company_id, name, description, is_active,
  ST_AsGeoJSON(boundary) as boundary_geojson,
  ST_Y(ST_Centroid(boundary)) as center_lat,
  ST_X(ST_Centroid(boundary)) as center_lng,
  ST_Area(boundary::geography) as area_sq_meters,
  created_at, updated_at;
```

### Pattern 2: Spatial Voter Query
**What:** Find all voters within a turf boundary using PostGIS ST_Contains.
**When to use:** Auto-populating voter list per turf (TURF-03).
**Example:**
```sql
-- name: GetVotersInTurf :many
SELECT v.id, v.first_name, v.last_name, v.party, v.status,
       v.res_street_address, v.res_city, v.res_zip,
       ST_Y(v.location) as latitude, ST_X(v.location) as longitude
FROM voters v
JOIN turfs t ON t.id = @turf_id
WHERE v.company_id = @company_id
  AND v.location IS NOT NULL
  AND v.geocode_status = 'success'
  AND ST_Contains(t.boundary, v.location)
ORDER BY v.last_name, v.first_name
LIMIT @lim OFFSET @off;
```
The GIST indexes on both `turfs.boundary` and `voters.location` make this efficient. PostGIS uses the index as a primary bounding-box filter, then CPU-refines with the actual polygon geometry.

### Pattern 3: FMTC Offline Tile Download per Turf
**What:** Download map tiles for a turf's bounding area at zoom levels 12-18.
**When to use:** Navigator downloads tiles before going to field (TURF-05).
**Example:**
```dart
// Initialize FMTC (in main.dart, before runApp)
await FMTCObjectBoxBackend().initialise();

// Create a store per turf
final store = FMTCStore('turf-${turfId}');
await store.manage.create();

// Define download region from turf polygon
final region = CustomPolygonRegion(
  outline: turfBoundaryPoints, // List<LatLng> from GeoJSON
);

// Start bulk download
final downloadableRegion = region.toDownloadable(
  minZoom: 12,
  maxZoom: 18,
  options: TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
);

// Estimate tile count first
final tileCount = await store.download.check(downloadableRegion);

// Execute download with progress
final downloadStream = store.download.startForeground(
  region: downloadableRegion,
  parallelThreads: 5,
  rateLimit: 200, // tiles per second, respect OSM usage policy
);

downloadStream.listen((progress) {
  // Update UI with progress.percentageProgress
});

// Use cached tiles in map
FlutterMap(
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      tileProvider: FMTCTileProvider(
        stores: {'turf-${turfId}': BrowseStoreStrategy.readUpdateCreate},
        loadingStrategy: BrowseLoadingStrategy.cacheFirst,
      ),
    ),
  ],
);
```

### Pattern 4: Nearest-Neighbor Walk List
**What:** Generate a route-optimized ordering of voters for door-to-door canvassing.
**When to use:** TURF-06: walk list generation.
**Example (server-side Go):**
```go
// Nearest-neighbor greedy TSP approximation
// O(n^2) but simple and sufficient for turf-sized datasets (typically 100-2000 voters)
func generateWalkList(voters []VoterLocation, startLat, startLng float64) []VoterLocation {
    ordered := make([]VoterLocation, 0, len(voters))
    remaining := make(map[int]bool)
    for i := range voters {
        remaining[i] = true
    }

    currentLat, currentLng := startLat, startLng
    for len(remaining) > 0 {
        bestIdx := -1
        bestDist := math.MaxFloat64
        for idx := range remaining {
            d := haversine(currentLat, currentLng, voters[idx].Lat, voters[idx].Lng)
            if d < bestDist {
                bestDist = d
                bestIdx = idx
            }
        }
        ordered = append(ordered, voters[bestIdx])
        currentLat = voters[bestIdx].Lat
        currentLng = voters[bestIdx].Lng
        delete(remaining, bestIdx)
    }
    return ordered
}
```

Alternative: use PostGIS KNN with recursive CTE:
```sql
-- Recursive nearest-neighbor walk order
WITH RECURSIVE walk AS (
    -- Start from turf centroid
    SELECT v.id, v.location, 1 as step
    FROM voters v
    JOIN turfs t ON ST_Contains(t.boundary, v.location)
    WHERE t.id = @turf_id AND v.company_id = @company_id
    ORDER BY v.location <-> ST_Centroid((SELECT boundary FROM turfs WHERE id = @turf_id))
    LIMIT 1

    UNION ALL

    SELECT v.id, v.location, w.step + 1
    FROM voters v, walk w
    WHERE v.id != w.id
      AND NOT EXISTS (SELECT 1 FROM walk w2 WHERE w2.id = v.id)
    ORDER BY v.location <-> w.location
    LIMIT 1
)
SELECT * FROM walk;
```

Note: The recursive CTE approach is elegant but may be slow for large datasets. The Go approach is recommended for datasets > 500 voters. For smaller turfs, the PostGIS approach works well.

### Pattern 5: Turf Completion Tracking
**What:** Calculate percentage of voters contacted per turf.
**When to use:** TURF-07: progress tracking.
**Example:**
```sql
-- name: GetTurfCompletionStats :one
SELECT
    COUNT(DISTINCT v.id) as total_voters,
    COUNT(DISTINCT CASE WHEN cl.id IS NOT NULL THEN v.id END) as contacted_voters
FROM voters v
JOIN turfs t ON ST_Contains(t.boundary, v.location)
LEFT JOIN contact_logs cl ON cl.voter_id = v.id AND cl.turf_id = t.id
WHERE t.id = @turf_id
  AND v.company_id = @company_id
  AND v.location IS NOT NULL
  AND v.geocode_status = 'success';
```

Note: This requires a `contact_logs` table (likely part of a future objective or needs to be added in this objective). At minimum, the table needs: voter_id, turf_id, contacted_by, contacted_at, contact_type, outcome.

### Pattern 6: Heat Map Grid Aggregation
**What:** Server-side aggregation of voter density into a grid for heat map rendering.
**When to use:** TURF-08: admin heat map views.
**Example:**
```sql
-- Aggregate voters into grid cells for heat map
-- name: GetVoterDensityGrid :many
SELECT
    ST_X(ST_SnapToGrid(v.location, @grid_size)) as grid_lng,
    ST_Y(ST_SnapToGrid(v.location, @grid_size)) as grid_lat,
    COUNT(*) as voter_count,
    COUNT(CASE WHEN cl.id IS NOT NULL THEN 1 END) as contacted_count,
    COUNT(CASE WHEN cl.outcome = 'support' THEN 1 END) as support_count
FROM voters v
LEFT JOIN contact_logs cl ON cl.voter_id = v.id
WHERE v.company_id = @company_id
  AND v.location IS NOT NULL
  AND ST_Contains(
    ST_MakeEnvelope(@min_lng, @min_lat, @max_lng, @max_lat, 4326),
    v.location
  )
GROUP BY ST_SnapToGrid(v.location, @grid_size)
ORDER BY voter_count DESC;
```

Flutter-side rendering using CustomPainter:
```dart
class HeatMapPainter extends CustomPainter {
  final List<HeatPoint> points;
  final FlutterMapState mapState;

  @override
  void paint(Canvas canvas, Size size) {
    for (final point in points) {
      final screenPos = mapState.project(point.latLng);
      final radius = _radiusForIntensity(point.intensity);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            _colorForValue(point.value).withOpacity(0.6),
            _colorForValue(point.value).withOpacity(0.0),
          ],
        ).createShader(Rect.fromCircle(center: screenPos, radius: radius));
      canvas.drawCircle(screenPos, radius, paint);
    }
  }
}
```

### Anti-Patterns to Avoid
- **Loading all voters at once on map:** Use pagination + viewport bounding box queries. Only load voters visible in current map bounds.
- **Storing polygon as array of floats in proto:** Use GeoJSON string. It is the standard interchange format, PostGIS natively supports it, and Dart GeoJSON parsers exist.
- **Downloading all zoom levels for offline:** Restrict to zoom 12-18. Lower zooms waste storage; higher zooms have diminishing returns for canvassing.
- **Client-side spatial containment checks:** Always use PostGIS server-side. Client-side point-in-polygon is slow and error-prone for complex geometries.
- **Skipping rate limiting on tile downloads:** OSM tile servers have strict usage policies (max 2 requests/sec for heavy downloading). FMTC supports rate limiting -- use it.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Map rendering | Custom map widget | flutter_map 8.x | Tile loading, zoom, pan, gestures, projections are complex |
| Marker clustering | Manual grid-based clustering | flutter_map_marker_cluster 8.x | Handles zoom-based cluster merging, animations, edge cases |
| Polygon drawing UX | Custom gesture detector + canvas | flutter_map_line_editor 8.x | Drag handles, intermediate points, close-path logic |
| Offline tile caching | Manual HTTP download + SQLite | FMTC 10.x | Pause/resume, recovery, dedup, multi-store, rate limiting |
| Spatial containment | Client-side point-in-polygon | PostGIS ST_Contains | GIST index utilization, handles complex polygons, edge cases |
| GeoJSON parsing | Manual JSON parsing | ST_GeomFromGeoJSON / ST_AsGeoJSON | Handles all edge cases: winding order, SRID, validation |
| Distance calculations | Euclidean distance | Haversine or PostGIS <-> operator | Earth curvature matters at Maine's latitude |

**Key insight:** The mapping domain has extremely mature libraries. Every "simple" feature (clustering, offline tiles, spatial queries) has dozens of edge cases that the standard libraries handle. Custom implementations will have bugs that surface in production with real geographic data.

## Common Pitfalls

### Pitfall 1: FMTC GPL License Violation
**What goes wrong:** Ship proprietary app with GPL dependency; legal exposure.
**Why it happens:** Developers add FMTC without reading license.
**How to avoid:** Contact fmtc@jaffaketchup.dev BEFORE development to negotiate commercial license. Budget for yearly license fee.
**Warning signs:** Any discussion of "just using it" without license review.

### Pitfall 2: OSM Tile Server Rate Limiting / Bans
**What goes wrong:** Bulk downloading tiles gets IP banned by OSM tile servers.
**Why it happens:** OSM has strict tile usage policy: max 2 heavy-use connections, must include proper User-Agent.
**How to avoid:** (1) Use FMTC rate limiting (set rateLimit to ~100-200 tiles/sec). (2) Set proper User-Agent header. (3) Consider using a commercial tile provider (MapTiler, Thunderforest) for production. (4) OSM policy forbids systematic bulk downloading -- a commercial tile source may be required.
**Warning signs:** HTTP 429 responses, empty tiles, IP blocks.

### Pitfall 3: Polygon Winding Order
**What goes wrong:** Polygon appears inverted (covers entire world except the turf area).
**Why it happens:** GeoJSON requires counter-clockwise winding for exterior rings (RFC 7946). PostGIS and flutter_map may interpret differently.
**How to avoid:** Always normalize with `ST_ForcePolygonCCW()` when storing. Validate winding in Flutter before sending to server.
**Warning signs:** Turf boundary renders as a "hole" in the world rather than a filled region.

### Pitfall 4: Voter Location NULL Handling
**What goes wrong:** Spatial queries fail or return unexpected results for voters without geocoded locations.
**Why it happens:** Not all voters have been geocoded (geocode_status = 'pending' or 'failed').
**How to avoid:** Always filter `WHERE v.location IS NOT NULL AND v.geocode_status = 'success'` in spatial queries.
**Warning signs:** NULL pointer errors in spatial functions, wrong voter counts.

### Pitfall 5: Memory Pressure from Large Marker Sets
**What goes wrong:** App becomes sluggish or crashes when displaying 10,000+ voter markers.
**Why it happens:** Each Marker is a widget; Flutter can't handle 10K+ widgets efficiently.
**How to avoid:** (1) Use flutter_map_marker_cluster to reduce rendered widgets. (2) Only load voters in current viewport bounds. (3) Implement viewport-based lazy loading with server-side bounding box queries.
**Warning signs:** Frame drops when zooming, high memory usage, ANR on Android.

### Pitfall 6: sqlc and PostGIS Custom Types
**What goes wrong:** sqlc cannot generate correct Go types for PostGIS geometry columns.
**Why it happens:** sqlc has limited PostGIS support; geometry columns map to `interface{}`.
**How to avoid:** Use GeoJSON string conversion in SQL queries (ST_AsGeoJSON / ST_GeomFromGeoJSON) so sqlc sees TEXT columns. Avoid returning raw geometry columns; always convert to GeoJSON or individual lat/lng float columns in the SELECT.
**Warning signs:** `interface{}` types in generated Go code for spatial columns.

### Pitfall 7: Offline Map + Clustering Interaction
**What goes wrong:** Cached tiles don't display, or clustering breaks when offline.
**Why it happens:** FMTC needs correct store configuration; marker data needs to be cached separately from tiles.
**How to avoid:** (1) Store voter data locally (SQLite or Hive) in addition to tiles. (2) Use `BrowseLoadingStrategy.cacheFirst` not `cacheOnly` during development. (3) Test offline mode by enabling airplane mode.
**Warning signs:** Blank map tiles when offline, markers disappear.

## Code Examples

### flutter_map Basic Setup with Polygon Layer
```dart
// Source: flutter_map docs (docs.fleaflet.dev)
FlutterMap(
  options: MapOptions(
    initialCenter: LatLng(44.3106, -69.7795), // Augusta, Maine
    initialZoom: 8.0,
  ),
  children: [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.mainegop.navigators',
    ),
    PolygonLayer(
      polygons: turfs.map((turf) => Polygon(
        points: turf.boundaryPoints, // List<LatLng>
        color: Colors.blue.withOpacity(0.2),
        borderColor: Colors.blue,
        borderStrokeWidth: 2.0,
        isFilled: true,
      )).toList(),
    ),
  ],
);
```

### Interactive Polygon Drawing (Admin)
```dart
// Source: flutter_map_line_editor pub.dev example
class TurfDrawScreen extends StatefulWidget { ... }

class _TurfDrawScreenState extends State<TurfDrawScreen> {
  final List<LatLng> _polygonPoints = [];
  late PolyEditor _polyEditor;

  @override
  void initState() {
    super.initState();
    _polyEditor = PolyEditor(
      points: _polygonPoints,
      pointIcon: const Icon(Icons.circle, size: 20, color: Colors.red),
      intermediateIcon: const Icon(Icons.lens, size: 12, color: Colors.grey),
      callbackRefresh: () => setState(() {}),
      addClosePathMarker: true, // CRITICAL: closes the polygon
    );
  }

  @override
  Widget build(BuildContext context) {
    return FlutterMap(
      options: MapOptions(
        onTap: (tapPosition, latLng) {
          setState(() => _polygonPoints.add(latLng));
        },
      ),
      children: [
        TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
        PolygonLayer(polygons: [
          Polygon(
            points: _polygonPoints,
            color: Colors.blue.withOpacity(0.15),
            borderColor: Colors.blue,
            borderStrokeWidth: 2,
            isFilled: true,
          ),
        ]),
        DragMarkers(markers: _polyEditor.edit()),
      ],
    );
  }

  // Convert to GeoJSON for API submission
  String _toGeoJSON() {
    final coords = _polygonPoints.map((p) => [p.longitude, p.latitude]).toList();
    coords.add(coords.first); // Close the ring
    return jsonEncode({
      'type': 'Polygon',
      'coordinates': [coords],
    });
  }
}
```

### Marker Cluster Layer
```dart
// Source: flutter_map_marker_cluster pub.dev
MarkerClusterLayerWidget(
  options: MarkerClusterLayerOptions(
    maxClusterRadius: 80,
    markers: voters.map((v) => Marker(
      point: LatLng(v.latitude, v.longitude),
      width: 30,
      height: 30,
      child: const Icon(Icons.location_pin, color: Colors.red, size: 30),
    )).toList(),
    builder: (context, markers) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${markers.length}',
            style: const TextStyle(color: Colors.white, fontSize: 12),
          ),
        ),
      );
    },
  ),
);
```

### PostGIS: Update Turf Boundary
```sql
-- name: UpdateTurfBoundary :one
UPDATE turfs
SET boundary = ST_ForcePolygonCCW(ST_GeomFromGeoJSON(@boundary_geojson)),
    updated_at = now()
WHERE id = @turf_id AND company_id = @company_id
RETURNING id, name, description, is_active,
  ST_AsGeoJSON(boundary) as boundary_geojson,
  ST_Y(ST_Centroid(boundary)) as center_lat,
  ST_X(ST_Centroid(boundary)) as center_lng,
  ST_Area(boundary::geography) as area_sq_meters,
  created_at, updated_at;
```

### PostGIS: Count Voters in Turf
```sql
-- name: CountVotersInTurf :one
SELECT COUNT(*) as voter_count
FROM voters v
JOIN turfs t ON t.id = @turf_id
WHERE v.company_id = @company_id
  AND v.location IS NOT NULL
  AND v.geocode_status = 'success'
  AND ST_Contains(t.boundary, v.location);
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| google_maps_flutter only | flutter_map + FMTC | 2023-2024 | Free, open-source, vendor-independent offline maps |
| flutter_map v6 layer system | flutter_map v7+ children-based | 2024 | Plugins switched from Layer to Widget-based API |
| flutter_map_supercluster | flutter_map_marker_cluster 8.x | 2025 | supercluster stuck on fm ^5; marker_cluster updated to fm 8 |
| flutter_map_heatmap | Custom Canvas overlay | 2025 | heatmap package stuck on fm <8; custom solution needed |
| Manual tile downloads | FMTC 10.x | 2024 | ObjectBox backend, multi-store, recovery, custom polygon regions |

**Deprecated/outdated:**
- flutter_map_supercluster: NOT compatible with flutter_map 8; do not use
- flutter_map_heatmap: NOT compatible with flutter_map 8; do not use
- Flutter map v6 layer plugin API: replaced by children widget list in v7+

## Open Questions

1. **FMTC Commercial License Cost**
   - What we know: GPL-3 requires open-sourcing or commercial license; maintainer sells yearly licenses
   - What's unclear: Price for a political campaign app with ~200 users
   - Recommendation: Email fmtc@jaffaketchup.dev immediately; alternatively evaluate self-hosted tile server to avoid GPL issue entirely

2. **Tile Provider for Production**
   - What we know: OSM tile servers forbid systematic bulk downloading; FMTC rate limiting helps but may not be sufficient
   - What's unclear: Whether OSM is acceptable for production with 200+ Navigators each downloading turf tiles
   - Recommendation: Use a commercial tile provider (MapTiler, Thunderforest, Stadia Maps) for production. Budget ~$50-200/month. Many offer free tiers that may suffice for pilot.

3. **Contact Logs Table**
   - What we know: TURF-07 (completion tracking) and TURF-08 (heat maps) require a contact_logs table
   - What's unclear: Whether this belongs in Objective 3 or a later objective (Objective 5: Outreach/Canvassing?)
   - Recommendation: Create a minimal contact_logs table in this objective (voter_id, turf_id, user_id, contacted_at, contact_type, outcome). Full outreach features in later objective.

4. **Offline Voter Data Storage**
   - What we know: FMTC handles tile caching; voter data also needs to be available offline
   - What's unclear: Full offline sync is Objective 4; how much offline voter data is needed for Objective 3?
   - Recommendation: For Objective 3, load voter pins from network only (online). Defer full offline voter data to Objective 4 (Offline & Sync). FMTC offline tiles are independent of voter data.

5. **Tile Storage Size Per Turf**
   - What we know: Each zoom level quadruples tile count; OSM tiles average 10-30KB each
   - Estimate for a typical neighborhood turf (~1 sq mi) at zoom 12-18: ~1,000-5,000 tiles = ~10-100MB
   - Estimate for a rural turf (~25 sq mi) at zoom 12-18: ~5,000-25,000 tiles = ~50-500MB
   - Recommendation: Use FMTC's tile count estimation API before downloading. Show estimated size to user. Set max download size warning at 500MB.

## Sources

### Primary (HIGH confidence)
- flutter_map pub.dev - v8.2.2, BSD-3-Clause, cross-platform https://pub.dev/packages/flutter_map
- flutter_map_tile_caching pub.dev - v10.1.1, GPL-3, flutter_map ^8.1.1 https://pub.dev/packages/flutter_map_tile_caching
- flutter_map_marker_cluster pub.dev - v8.2.2, flutter_map ^8.2.2 https://pub.dev/packages/flutter_map_marker_cluster
- flutter_map_line_editor pub.dev - v8.0.0, MIT, flutter_map_dragmarker ^8.0.0 https://pub.dev/packages/flutter_map_line_editor
- FMTC docs - store management, tile provider, download API https://fmtc.jaffaketchup.dev/
- PostGIS docs - ST_Contains, ST_GeomFromGeoJSON, ST_AsGeoJSON, KNN https://postgis.net/docs/
- OpenStreetMap Wiki - zoom levels, tile sizing https://wiki.openstreetmap.org/wiki/Zoom_levels

### Secondary (MEDIUM confidence)
- flutter_map_supercluster - confirmed incompatible with flutter_map 8 (requires ^5.0.0) https://pub.dev/packages/flutter_map_supercluster
- flutter_map_heatmap - confirmed incompatible with flutter_map 8 (requires >=7 <8) https://pub.dev/packages/flutter_map_heatmap
- FMTC integrating with map guide https://fmtc.jaffaketchup.dev/usage/integrating-with-a-map

### Tertiary (LOW confidence)
- Tile storage size estimates (derived from zoom level math, not measured) -- needs validation with FMTC count API
- Walk list nearest-neighbor performance claims -- needs benchmarking with real Maine voter data

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH - all versions verified on pub.dev, compatibility confirmed
- Architecture: HIGH - patterns derived from existing codebase + official docs
- Pitfalls: HIGH - license, rate limiting, winding order are well-documented issues
- Heat map approach: MEDIUM - custom Canvas approach is standard Flutter but untested for this use case
- Offline tile sizing: LOW - estimates only; need real-world measurement

**Research date:** 2026-04-10
**Valid until:** 2026-05-10 (30 days -- flutter_map ecosystem is stable but check for version bumps)
