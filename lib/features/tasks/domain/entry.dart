import 'dart:convert';
import 'package:uuid/uuid.dart';

/// Common local record envelope; payload fields are owned by each feature.
/// Timestamps are UTC. Civil dates (habit days, recurrence dates) remain local.
class Entry {
  final String id, kind, title, body, state;
  final int priority;
  final String? projectId;
  final DateTime? dueAt;
  final DateTime createdAt, updatedAt;
  final bool deleted;
  final Map<String, dynamic> data;
  Entry({String? id, required this.kind, required this.title, this.body = '',
    this.state = 'inbox', this.priority = 1, this.projectId, this.dueAt,
    DateTime? createdAt, DateTime? updatedAt, this.deleted = false,
    Map<String, dynamic>? data})
    : id = id ?? const Uuid().v4(), createdAt = createdAt ?? DateTime.now().toUtc(),
      updatedAt = updatedAt ?? DateTime.now().toUtc(), data = data ?? {};
  Entry copy({String? title, String? body, String? state, int? priority,
    String? projectId, DateTime? dueAt, bool clearDue = false,
    bool clearProject = false, bool? deleted, Map<String, dynamic>? data}) => Entry(
      id: id, kind: kind, title: title ?? this.title, body: body ?? this.body,
      state: state ?? this.state, priority: priority ?? this.priority,
      projectId: clearProject ? null : projectId ?? this.projectId,
      dueAt: clearDue ? null : dueAt ?? this.dueAt, createdAt: createdAt,
      deleted: deleted ?? this.deleted, data: data ?? this.data);
  Map<String, Object?> toRow() => {'id': id, 'kind': kind, 'title': title,
    'body': body, 'state': state, 'priority': priority, 'project_id': projectId,
    'due_at': dueAt?.toUtc().toIso8601String(),
    'created_at': createdAt.toIso8601String(), 'updated_at': updatedAt.toIso8601String(),
    'deleted': deleted ? 1 : 0, 'data': jsonEncode(data)};
  factory Entry.fromRow(Map<String, Object?> r) => Entry(
    id: r['id'] as String, kind: r['kind'] as String, title: r['title'] as String,
    body: r['body'] as String, state: r['state'] as String,
    priority: r['priority'] as int, projectId: r['project_id'] as String?,
    dueAt: r['due_at'] == null ? null : DateTime.parse(r['due_at'] as String),
    createdAt: DateTime.parse(r['created_at'] as String),
    updatedAt: DateTime.parse(r['updated_at'] as String), deleted: r['deleted'] == 1,
    data: Map<String, dynamic>.from(jsonDecode(r['data'] as String) as Map));
}

DateTime? nextOccurrence(DateTime date, String rule) {
  final d = date.toLocal();
  switch (rule) {
    case 'daily': return DateTime(d.year, d.month, d.day + 1, d.hour, d.minute);
    case 'weekly': return DateTime(d.year, d.month, d.day + 7, d.hour, d.minute);
    case 'monthly':
      final last = DateTime(d.year, d.month + 2, 0).day;
      return DateTime(d.year, d.month + 1, d.day > last ? last : d.day, d.hour, d.minute);
    default: return null;
  }
}

double projectProgress(Iterable<Entry> entries, String id) {
  final tasks = entries.where((e) => e.kind == 'task' && e.projectId == id &&
    !e.deleted && e.state != 'cancelled').toList();
  if (tasks.isEmpty) return 0;
  return tasks.where((e) => e.state == 'completed').length / tasks.length;
}
String dayKey(DateTime d) {
  final l = d.toLocal();
  return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
}


void validateEntry(Entry e) {
  const states = {
    'task': {'inbox','planned','in_progress','completed','cancelled'},
    'project': {'planning','active','paused','completed','archived'},
    'note': {'active'}, 'idea': {'active'}, 'reminder': {'active'},
    'goal': {'active','completed'}, 'habit': {'active'},
    'session': {'active','completed','interrupted'}, 'override': {'active','completed'},
  };
  if (e.id.isEmpty || e.id.length > 100 || e.title.trim().isEmpty || e.title.length > 240 ||
      e.body.length > 1000000 || e.priority < 0 || e.priority > 3 ||
      !(states[e.kind]?.contains(e.state) ?? false)) {
    throw const FormatException('Invalid record envelope');
  }
  final tags = e.data['tags'];
  if (tags != null && (tags is! List || tags.length > 200 || tags.any((t) => t is! String))) {
    throw const FormatException('Invalid tags');
  }
  if (e.data['pinned'] != null && e.data['pinned'] is! bool) throw const FormatException('Invalid pin');
  if (e.kind == 'task') {
    if (!['none','daily','weekly','monthly'].contains(e.data['recurrence'] ?? 'none')) {
      throw const FormatException('Unsupported recurrence');
    }
    final estimate = e.data['estimateMinutes'];
    if (estimate != null && (estimate is! int || estimate < 0)) throw const FormatException('Invalid estimate');
  }
  if (e.kind == 'goal') {
    final target = e.data['target'], current = e.data['current'];
    if (target is! num || !target.isFinite || target <= 0 || current is! num || !current.isFinite || current < 0 || e.data['unit'] is! String) {
      throw const FormatException('Invalid goal');
    }
  }
  if (e.kind == 'habit' && e.data['days'] != null) {
    final days = e.data['days'];
    if (days is! List || days.length > 50000) throw const FormatException('Invalid habit days');
    for (final day in days) {
      if (day is! String || DateTime.tryParse(day) == null || dayKey(DateTime.parse(day)) != day) {
        throw const FormatException('Invalid habit date');
      }
    }
  }
  if (e.kind == 'session') {
    final started = e.data['startedAt'], ended = e.data['endedAt'];
    if (started is! String || DateTime.tryParse(started) == null ||
        (e.state != 'active' && (ended is! String || DateTime.tryParse(ended) == null))) {
      throw const FormatException('Invalid session interval');
    }
    final targetEnd = e.data['targetEnd'];
    if (targetEnd != null && (targetEnd is! String || DateTime.tryParse(targetEnd) == null)) throw const FormatException('Invalid session end');
    final seconds = e.data['actualSeconds'];
    if (seconds != null && (seconds is! num || !seconds.isFinite || seconds < 0)) throw const FormatException('Invalid session duration');
  }
}
