import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/controller.dart';
import '../../app/screens.dart';
import 'domain/report.dart';

class ReportSection extends StatelessWidget {
  final FocusController c;
  final DateTime start, end;
  const ReportSection({
    super.key,
    required this.c,
    required this.start,
    required this.end,
  });
  @override
  Widget build(BuildContext context) {
    final report = ReportEngine.create(
      c.entries,
      c.usage,
      c.disciplineRules,
      c.phone['overrides'] as List? ?? [],
      start,
      end,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Section(
          'Period report',
          child: Wrap(
            spacing: 28,
            runSpacing: 12,
            children: [
              Text('${report.tasksCreated} tasks captured'),
              Text('${report.tasksCompleted} completed'),
              Text('${report.overdue} currently overdue'),
              Text('${report.sessions} focus sessions'),
              Text('${report.habitCheckins} habit check-ins'),
              Text('${report.overrides} recorded overrides'),
            ],
          ),
        ),
        if (report.categories.isNotEmpty)
          Section(
            'Your app groups',
            child: Column(
              children: [
                for (final group in report.categories.entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(group.key),
                    trailing: Text(durationLabel(group.value)),
                  ),
              ],
            ),
          ),
        Section(
          'Patterns & next steps',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final insight in report.insights)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(insight),
                ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            await Clipboard.setData(
              ClipboardData(
                text: const JsonEncoder.withIndent(
                  '  ',
                ).convert(report.toJson()),
              ),
            );
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Report copied.')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy report as JSON'),
        ),
      ],
    );
  }
}
