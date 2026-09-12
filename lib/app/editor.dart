import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import '../features/tasks/domain/entry.dart';

Future<void> editEntry(
  BuildContext context,
  FocusController c, {
  Entry? entry,
  String kind = 'task',
}) async {
  await showDialog<void>(
    context: context,
    builder: (ctx) => EntryEditor(c: c, entry: entry, kind: kind),
  );
}

class EntryEditor extends StatefulWidget {
  final FocusController c;
  final Entry? entry;
  final String kind;
  const EntryEditor({
    super.key,
    required this.c,
    this.entry,
    required this.kind,
  });
  @override
  State<EntryEditor> createState() => _EntryEditorState();
}

class _EntryEditorState extends State<EntryEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController title, body, tags, estimate, target, unit, current;
  late String kind, state, recurrence;
  String? project;
  String? linkedTask;
  String metric = 'manual';
  DateTime? due;
  int priority = 1;
  @override
  void initState() {
    super.initState();
    final e = widget.entry;
    kind = e?.kind ?? widget.kind;
    state =
        e?.state ?? (['task', 'milestone'].contains(kind) ? 'inbox' : 'active');
    title = TextEditingController(text: e?.title);
    body = TextEditingController(text: e?.body);
    tags = TextEditingController(
      text: (e?.data['tags'] as List? ?? []).join(', '),
    );
    estimate = TextEditingController(
      text: '${e?.data['estimateMinutes'] ?? 30}',
    );
    target = TextEditingController(text: '${e?.data['target'] ?? 14}');
    current = TextEditingController(text: '${e?.data['current'] ?? 0}');
    unit = TextEditingController(text: e?.data['unit'] as String? ?? 'hours');
    recurrence = e?.data['recurrence'] as String? ?? 'none';
    project = e?.projectId;
    linkedTask = e?.data['taskId'] as String?;
    metric = e?.data['metric'] as String? ?? 'manual';
    due = e?.dueAt?.toLocal();
    priority = e?.priority ?? 1;
  }

  @override
  void dispose() {
    for (final x in [title, body, tags, estimate, target, unit, current]) {
      x.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Capture something' : 'Edit $kind'),
    content: SizedBox(
      width: 550,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.entry == null)
                DropdownButtonFormField<String>(
                  initialValue: kind,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [
                    for (final k in [
                      'task',
                      'note',
                      'idea',
                      'reminder',
                      'project',
                      'milestone',
                      'goal',
                      'habit',
                    ])
                      DropdownMenuItem(value: k, child: Text(k)),
                  ],
                  onChanged: (v) => setState(() {
                    kind = v!;
                    state = ['task', 'milestone'].contains(kind)
                        ? 'inbox'
                        : 'active';
                  }),
                ),
              const SizedBox(height: 16),
              TextFormField(
                controller: title,
                autofocus: true,
                maxLength: 240,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Add a title' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: body,
                minLines: 3,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Details / plain Markdown',
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: tags,
                decoration: const InputDecoration(
                  labelText: 'Tags, separated by commas',
                ),
              ),
              if (kind == 'task' ||
                  kind == 'milestone' ||
                  kind == 'project') ...[
                const SizedBox(height: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: [
                        for (var i = 0; i < 4; i++)
                          DropdownMenuItem(
                            value: i,
                            child: Text(
                              ['Low', 'Medium', 'High', 'Critical'][i],
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() => priority = v!),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: state,
                      key: ValueKey('status-$kind'),
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final s
                            in (kind != 'project'
                                ? [
                                    'inbox',
                                    'planned',
                                    'in_progress',
                                    'completed',
                                    'cancelled',
                                  ]
                                : [
                                    'planning',
                                    'active',
                                    'paused',
                                    'completed',
                                    'archived',
                                  ]))
                          DropdownMenuItem(
                            value: s,
                            child: Text(s.replaceAll('_', ' ')),
                          ),
                      ],
                      onChanged: (v) => setState(() => state = v!),
                    ),
                  ],
                ),
              ],
              if ([
                'task',
                'milestone',
                'note',
                'idea',
                'goal',
              ].contains(kind)) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue:
                      // Keep long project names within the phone dialog.
                      widget.c.of('project').any((p) => p.id == project)
                      ? project
                      : null,
                  decoration: const InputDecoration(labelText: 'Project'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No project'),
                    ),
                    for (final p in widget.c.of('project'))
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.title, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => project = v),
                ),
              ],
              if (kind == 'task') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: estimate,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Estimate (min)',
                        ),
                        validator: (v) => (int.tryParse(v ?? '') ?? -1) < 0
                            ? 'Use 0 or more'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: recurrence,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Repeats'),
                        items: [
                          for (final r in [
                            'none',
                            'daily',
                            'weekly',
                            'monthly',
                          ])
                            DropdownMenuItem(value: r, child: Text(r)),
                        ],
                        onChanged: (v) => setState(() => recurrence = v!),
                      ),
                    ),
                  ],
                ),
              ],
              if (kind == 'goal') ...[
                DropdownButtonFormField<String>(
                  initialValue: metric,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Progress source',
                  ),
                  items: [
                    for (final item in [
                      ('manual', 'Manual'),
                      ('focusHours', 'Recorded focus hours'),
                      ('tasksCompleted', 'Completed tasks'),
                      ('projectPercent', 'Project completion %'),
                    ])
                      DropdownMenuItem(value: item.$1, child: Text(item.$2)),
                  ],
                  onChanged: (v) => setState(() {
                    metric = v!;
                    unit.text = switch (metric) {
                      'focusHours' => 'hours',
                      'tasksCompleted' => 'tasks',
                      'projectPercent' => '%',
                      _ => unit.text,
                    };
                  }),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: unit,
                  decoration: const InputDecoration(labelText: 'Unit'),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: current,
                        decoration: const InputDecoration(labelText: 'Current'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? -1) < 0
                            ? 'Use 0 or more'
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: target,
                        decoration: const InputDecoration(labelText: 'Target'),
                        keyboardType: TextInputType.number,
                        validator: (v) => (double.tryParse(v ?? '') ?? 0) <= 0
                            ? 'Use more than 0'
                            : null,
                      ),
                    ),
                  ],
                ),
              ],
              if (kind == 'note' || kind == 'idea')
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.c.of('task').any((e) => e.id == linkedTask)
                      ? linkedTask
                      : null,
                  decoration: const InputDecoration(labelText: 'Linked task'),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('No task'),
                    ),
                    for (final task in widget.c.of('task'))
                      DropdownMenuItem(
                        value: task.id,
                        child: Text(
                          task.title,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (v) => setState(() => linkedTask = v),
                ),
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  TextButton.icon(
                    icon: const Icon(Icons.event),
                    label: Text(
                      due == null
                          ? 'Add date & time'
                          : DateFormat('MMM d, y · HH:mm').format(due!),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final d = await showDatePicker(
                        context: context,
                        initialDate: due ?? now,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2100),
                      );
                      if (d == null || !context.mounted) return;
                      final t = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.fromDateTime(due ?? now),
                      );
                      if (t != null && mounted) {
                        setState(
                          () => due = DateTime(
                            d.year,
                            d.month,
                            d.day,
                            t.hour,
                            t.minute,
                          ),
                        );
                      }
                    },
                  ),
                  if (due != null)
                    IconButton(
                      onPressed: () => setState(() => due = null),
                      tooltip: 'Remove date',
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              if (kind == 'reminder')
                const Text(
                  'Appears in your calendar. Android reminders need notification permission; exact alarm access improves timing.',
                ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: widget.c.busy
            ? null
            : () async {
                if (!form.currentState!.validate()) return;
                final data = {
                  ...(widget.entry?.data ?? <String, dynamic>{}),
                  'tags': tags.text
                      .split(',')
                      .map((t) => t.trim())
                      .where((t) => t.isNotEmpty)
                      .toList(),
                  'recurrence': recurrence,
                  if (kind == 'note' || kind == 'idea') 'taskId': linkedTask,
                  'estimateMinutes': int.tryParse(estimate.text) ?? 0,
                  if (kind == 'goal') ...{
                    'metric': metric,
                    'target': double.parse(target.text),
                    'current': double.parse(current.text),
                    'unit': unit.text.trim(),
                  },
                };
                final old = widget.entry;
                var e =
                    old?.copy(
                      title: title.text.trim(),
                      body: body.text,
                      state: state,
                      priority: priority,
                      projectId: project,
                      clearProject: project == null,
                      dueAt: due,
                      clearDue: due == null,
                      data: data,
                    ) ??
                    Entry(
                      kind: kind,
                      title: title.text.trim(),
                      body: body.text,
                      state: state,
                      priority: priority,
                      projectId: project,
                      dueAt: due,
                      data: data,
                    );
                // Route completion through the same transactional recurrence path as checkboxes.
                if (['task', 'milestone'].contains(kind) &&
                    state == 'completed' &&
                    old?.state != 'completed') {
                  e = e.copy(state: 'planned');
                  await widget.c.save(e);
                  if (widget.c.error == null) await widget.c.complete(e);
                } else {
                  await widget.c.save(e);
                }
                if (context.mounted && widget.c.error == null) {
                  Navigator.pop(context);
                }
              },
        child: const Text('Save'),
      ),
    ],
  );
}
