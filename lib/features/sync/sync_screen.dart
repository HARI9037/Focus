import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/controller.dart';
import '../../app/screens.dart';

class SyncScreen extends StatefulWidget {
  final FocusController c;
  const SyncScreen({super.key, required this.c});
  @override
  State<SyncScreen> createState() => _SyncScreenState();
}

class _SyncScreenState extends State<SyncScreen> {
  final input = TextEditingController();
  List<String> codes = [];
  bool working = false;
  String? message;
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      working = true;
      message = null;
    });
    try {
      await action();
    } catch (_) {
      message =
          'Could not connect. Use the same Wi-Fi, check the pairing code, and allow Focus on your private network in Windows Firewall.';
    } finally {
      if (mounted) setState(() => working = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    title: 'Device sync',
    eyebrow: 'Your devices, together',
    children: [
      const Text(
        'Sync tasks, projects, notes, goals, habits and finished sessions over your local network. Phone usage and a timestamped phone-status snapshot can also reach Windows. No cloud account is required.',
      ),
      const SizedBox(height: 20),
      const Text(
        'Start pairing on Windows, then paste its code on Android. The code grants access to your Focus records: keep it private. Pairing expires after 10 minutes; generate a new code for the next connection.',
      ),
      const SizedBox(height: 20),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          FilledButton(
            onPressed: working
                ? null
                : () => perform(() async {
                    codes = await widget.c.hostSync();
                    if (codes.isEmpty) {
                      message = 'Connect to Wi-Fi before pairing.';
                    }
                  }),
            child: const Text('Start pairing'),
          ),
          OutlinedButton(
            onPressed: working
                ? null
                : () => perform(() async {
                    await widget.c.sync.close();
                    codes = [];
                    message = 'Pairing stopped.';
                  }),
            child: const Text('Stop pairing'),
          ),
        ],
      ),
      if (widget.c.sync.hosting)
        for (final code in codes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(code),
                TextButton.icon(
                  onPressed: () => Clipboard.setData(ClipboardData(text: code)),
                  icon: const Icon(Icons.copy),
                  label: const Text('Copy pairing code'),
                ),
              ],
            ),
          ),
      const SizedBox(height: 24),
      TextField(
        controller: input,
        autocorrect: false,
        enableSuggestions: false,
        decoration: const InputDecoration(
          labelText: 'Pairing code from your other device',
        ),
      ),
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: FilledButton(
          onPressed: working
              ? null
              : () => perform(() async {
                  await widget.c.joinSync(input.text);
                  message = widget.c.error == null
                      ? 'Sync completed. Both devices now have the merged records.'
                      : 'Sync did not complete. Check the code and connection.';
                }),
          child: const Text('Sync now'),
        ),
      ),
      if (working) const LinearProgressIndicator(),
      if (message != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(message!),
        ),
      const SizedBox(height: 24),
      const Text(
        'Transfers use authenticated AES-256-GCM encryption. Permissions, restriction rules and active timers remain device-specific. Newer record timestamps win; export a backup before merging simultaneous edits.',
      ),
      if (widget.c.phone['syncedAt'] != null)
        Section(
          'Last phone snapshot',
          child: Text(
            'As of ${widget.c.phone['syncedAt']}\nNight Lock: ${widget.c.phone['state']}\nRestriction service: ${widget.c.phone['accessibility'] == true ? 'connected' : 'disconnected'}',
          ),
        ),
    ],
  );
}
