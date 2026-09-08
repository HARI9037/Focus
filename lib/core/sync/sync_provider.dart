/// V1 intentionally has no network transport. IDs, updated timestamps and tombstones
/// are already persisted. Future pairing must authenticate both devices, encrypt
/// in transit, and present concurrent note edits instead of silently dropping one.
abstract interface class SyncProvider {
  Future<SyncBatch> exchange(SyncBatch outgoing);
}
class SyncBatch {
  final int schemaVersion;
  final String deviceId, cursor;
  final List<Map<String, Object?>> changes;
  const SyncBatch({required this.schemaVersion, required this.deviceId,
    required this.cursor, required this.changes});
}
