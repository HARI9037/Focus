import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app/controller.dart';
import '../../app/screens.dart';

class DisciplineScreen extends StatefulWidget {
  final FocusController c;
  const DisciplineScreen({super.key, required this.c});
  @override
  State<DisciplineScreen> createState() => _DisciplineScreenState();
}

class _DisciplineScreenState extends State<DisciplineScreen> {
  String? error;
  Future<void> edit([Map<String, dynamic>? rule]) async {
    try {
      final apps = await widget.c.device.apps();
      if (!mounted) return;
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (_) => _RuleEditor(apps: apps, rule: rule),
      );
      if (result == null) return;
      final rules =
          widget.c.disciplineRules
              .where((r) => r['id'] != result['id'])
              .toList()
            ..add(result);
      await widget.c.saveDiscipline(rules);
    } catch (_) {
      if (mounted) {
        setState(
          () => error = 'Could not load apps or save this rule. Try again.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return PageBody(
      title: 'Digital discipline',
      eyebrow: 'Choose your boundaries',
      action: c.device.supported
          ? FilledButton.icon(
              onPressed: () => edit(),
              icon: const Icon(Icons.add),
              label: const Text('Add rule'),
            )
          : null,
      children: [
        const Text(
          'Set a daily budget for one app, or select several apps to share a category budget. Essential apps and system safety controls remain available.',
        ),
        const SizedBox(height: 20),
        if (!c.device.supported)
          const Text(
            'Configure restrictions on your Android phone. Windows remains your planning workspace.',
          ),
        if (c.device.supported)
          Text(
            'Restriction service: ${c.phone['accessibility'] == true ? 'connected' : 'enable in Settings'} · Usage Access: ${c.phone['usageAccess'] == true ? 'available' : 'required for daily budgets'}',
          ),
        if (error != null) Text(error!),
        const SizedBox(height: 24),
        if (c.disciplineRules.isEmpty)
          const EmptyState(
            'Make a little room.',
            'Add your first app limit. A group of apps can share one category budget.',
          ),
        for (final rule in c.disciplineRules)
          Section(
            rule['label'] as String,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(rule['packages'] as List).length} apps · ${rule['minutes'] == 0 ? 'No daily limit' : '${rule['minutes']} min / day'} · ${rule['duringFocus'] == true ? 'Blocked during focus' : 'Available during focus'}',
                ),
                if ((rule['blockedUntil'] as num? ?? 0) >
                    DateTime.now().millisecondsSinceEpoch)
                  Text(
                    'Cooldown until ${DateTime.fromMillisecondsSinceEpoch((rule['blockedUntil'] as num).toInt()).toLocal()}',
                  ),
                if (c.device.supported)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => edit(rule),
                        child: const Text('Edit'),
                      ),
                      TextButton(
                        onPressed: () => c.saveDiscipline(
                          c.disciplineRules
                              .map(
                                (r) => r['id'] == rule['id']
                                    ? {
                                        ...r,
                                        'blockedUntil': DateTime.now()
                                            .add(const Duration(minutes: 15))
                                            .millisecondsSinceEpoch,
                                      }
                                    : r,
                              )
                              .toList(),
                        ),
                        child: const Text('Block for 15 min'),
                      ),
                      TextButton(
                        onPressed: () => c.saveDiscipline(
                          c.disciplineRules
                              .map(
                                (r) => r['id'] == rule['id']
                                    ? {...r, 'blockedUntil': 0}
                                    : r,
                              )
                              .toList(),
                        ),
                        child: const Text('End cooldown'),
                      ),
                      TextButton(
                        onPressed: () => c.saveDiscipline(
                          c.disciplineRules
                              .where((r) => r['id'] != rule['id'])
                              .toList(),
                        ),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const Text(
          'Daily limits reset at local midnight. Focus warns at 80% and restricts at 100% while its service is connected. Missing Usage Access disables budget enforcement; focus blocking and cooldowns still work.',
        ),
      ],
    );
  }
}

class _RuleEditor extends StatefulWidget {
  final List<Map<String, dynamic>> apps;
  final Map<String, dynamic>? rule;
  const _RuleEditor({required this.apps, this.rule});
  @override
  State<_RuleEditor> createState() => _RuleEditorState();
}

class _RuleEditorState extends State<_RuleEditor> {
  final form = GlobalKey<FormState>();
  late final TextEditingController label, minutes;
  late Set<String> selected;
  late bool duringFocus;
  String query = '';
  @override
  void initState() {
    super.initState();
    label = TextEditingController(
      text: widget.rule?['label'] as String? ?? 'Distractions',
    );
    minutes = TextEditingController(text: '${widget.rule?['minutes'] ?? 30}');
    selected = Set<String>.from(widget.rule?['packages'] as List? ?? []);
    duringFocus = widget.rule?['duringFocus'] as bool? ?? true;
  }

  @override
  void dispose() {
    label.dispose();
    minutes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('App or category rule'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: label,
                decoration: const InputDecoration(labelText: 'Name'),
                maxLength: 120,
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: minutes,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Daily minutes (0 = no daily limit)',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  return n == null || n < 0 || n > 1440 ? 'Use 0–1440' : null;
                },
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: duringFocus,
                onChanged: (v) => setState(() => duringFocus = v),
                title: const Text('Block during focus sessions'),
              ),
              TextField(
                decoration: const InputDecoration(labelText: 'Find an app'),
                onChanged: (v) => setState(() => query = v.toLowerCase()),
              ),
              Text('${selected.length} apps selected'),
              SizedBox(
                height: 230,
                child: ListView(
                  children: [
                    for (final app in widget.apps.where(
                      (a) => '${a['label']} ${a['package']}'
                          .toLowerCase()
                          .contains(query),
                    ))
                      CheckboxListTile(
                        value: selected.contains(app['package']),
                        title: Text(app['label'] as String),
                        subtitle: Text(app['package'] as String),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            selected.add(app['package'] as String);
                          } else {
                            selected.remove(app['package']);
                          }
                        }),
                      ),
                  ],
                ),
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
        onPressed: selected.isEmpty
            ? null
            : () {
                if (!form.currentState!.validate()) return;
                Navigator.pop(context, {
                  'id': widget.rule?['id'] ?? const Uuid().v4(),
                  'label': label.text.trim(),
                  'minutes': int.parse(minutes.text),
                  'packages': selected.toList(),
                  'duringFocus': duringFocus,
                  'blockedUntil': widget.rule?['blockedUntil'] ?? 0,
                });
              },
        child: const Text('Save rule'),
      ),
    ],
  );
}
