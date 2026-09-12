/// Extension contract for future incremental providers. The current manual LAN
/// transport is implemented in local_sync.dart and transfers encrypted snapshots.
abstract interface class SyncProvider {
  Future<SyncBatch> exchange(SyncBatch outgoing);
}

class SyncBatch {
  final int schemaVersion;
  final String deviceId, cursor;
  final List<Map<String, Object?>> changes;
  const SyncBatch({
    required this.schemaVersion,
    required this.deviceId,
    required this.cursor,
    required this.changes,
  });
}
