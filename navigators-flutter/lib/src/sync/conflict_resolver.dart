/// Result of a conflict resolution decision.
enum ConflictResult {
  /// Server version wins -- overwrite local data.
  serverWins,

  /// Client version wins -- keep local data, pending outbox will push to server.
  clientWins,
}

/// Resolves conflicts between local and server data during pull sync.
///
/// Strategy:
/// - Contact logs: append-only, no conflict possible (both sides keep).
/// - Survey responses: append-only (same as contact logs).
/// - Voter metadata (notes, tags): last-write-wins using timestamps.
class ConflictResolver {
  /// Resolve a voter metadata conflict using last-write-wins (LWW).
  ///
  /// Compares the local update timestamp against the server update timestamp.
  /// If the server version is newer (or same), server wins.
  /// If the local version is strictly newer, client wins.
  ///
  /// The server assigns authoritative timestamps, so [serverUpdatedAt] is
  /// trusted. [localUpdatedAt] is set when the local write occurred.
  ConflictResult resolveVoterMetadata({
    required DateTime localUpdatedAt,
    required DateTime serverUpdatedAt,
  }) {
    // Server wins if its timestamp is >= local timestamp.
    // Tie goes to server (authoritative source).
    if (serverUpdatedAt.isAfter(localUpdatedAt) ||
        serverUpdatedAt.isAtSameMomentAs(localUpdatedAt)) {
      return ConflictResult.serverWins;
    }
    return ConflictResult.clientWins;
  }

  /// Contact logs are append-only. Both client and server versions are kept.
  /// No resolution needed -- this method exists for documentation clarity.
  ///
  /// During pull sync, any contact log from server is inserted locally via
  /// INSERT ON CONFLICT DO NOTHING (keyed on client-generated UUID).
  /// During push sync, server also uses INSERT ON CONFLICT DO NOTHING.
  ///
  /// Returns null to indicate no conflict action needed.
  ConflictResult? resolveContactLog() => null;

  /// Survey responses are append-only (same as contact logs).
  /// Each field visit creates a new response record.
  ConflictResult? resolveSurveyResponse() => null;
}
