import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'controller.dart';
import 'screens.dart';
import 'editor.dart';
import 'settings_screen.dart';
import '../features/digital_discipline/discipline_screen.dart';
import '../features/sync/sync_screen.dart';

const accent = Color(0xFFB9D98A);

class FocusApp extends StatefulWidget {
  final FocusController controller;
  const FocusApp({super.key, required this.controller});
  @override
  State<FocusApp> createState() => _FocusAppState();
}

class _FocusAppState extends State<FocusApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) widget.controller.resume();
  }

  ThemeData theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF647D44),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme.copyWith(
        primary: dark ? accent : const Color(0xFF425D28),
        surface: dark ? const Color(0xFF141714) : const Color(0xFFF7F7F1),
      ),
      scaffoldBackgroundColor: dark
          ? const Color(0xFF101310)
          : const Color(0xFFF7F7F1),
      appBarTheme: const AppBarTheme(elevation: 0, scrolledUnderElevation: 0),
      dividerTheme: DividerThemeData(
        color: dark ? Colors.white12 : Colors.black12,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w400,
          letterSpacing: -1.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 30,
          fontWeight: FontWeight.w400,
          letterSpacing: -.8,
        ),
        titleLarge: TextStyle(fontSize: 21, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final mode = widget.controller.settings['theme'] as String? ?? 'system';
      return MaterialApp(
        title: 'Focus',
        debugShowCheckedModeBanner: false,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: mode == 'dark'
            ? ThemeMode.dark
            : mode == 'light'
            ? ThemeMode.light
            : ThemeMode.system,
        home: widget.controller.settings['onboarded'] == true
            ? FocusShell(c: widget.controller)
            : Onboarding(c: widget.controller),
      );
    },
  );
}

const destinations = [
  'Today',
  'Inbox',
  'Tasks',
  'Projects',
  'Calendar',
  'Focus',
  'Notes',
  'Goals',
  'Habits',
  'Analytics',
  'Settings',
  'Digital discipline',
  'Device sync',
];
const destinationIcons = [
  Icons.wb_sunny_outlined,
  Icons.inbox_outlined,
  Icons.check_circle_outline,
  Icons.work_outline,
  Icons.calendar_month_outlined,
  Icons.timelapse,
  Icons.notes,
  Icons.flag_outlined,
  Icons.spa_outlined,
  Icons.bar_chart,
  Icons.tune,
  Icons.shield_outlined,
  Icons.sync,
];

class FocusShell extends StatefulWidget {
  final FocusController c;
  const FocusShell({super.key, required this.c});
  @override
  State<FocusShell> createState() => _FocusShellState();
}

class _FocusShellState extends State<FocusShell> {
  int selected = 0;
  String search = '';
  final searchController = TextEditingController();
  final searchFocus = FocusNode();
  @override
  void dispose() {
    searchController.dispose();
    searchFocus.dispose();
    super.dispose();
  }

  void capture() => editEntry(context, widget.c);
  void navigate(int index) => setState(() {
    selected = index;
    search = '';
    searchController.clear();
  });
  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final wide = MediaQuery.sizeOf(context).width >= 950;
    final body = search.trim().isNotEmpty
        ? SearchScreen(c: c, query: search)
        : switch (selected) {
            0 => TodayScreen(c: c, onNavigate: navigate),
            1 => RecordsScreen(c: c, kind: 'inbox'),
            2 => RecordsScreen(c: c, kind: 'task'),
            3 => RecordsScreen(c: c, kind: 'project'),
            4 => CalendarScreen(c: c),
            5 => FocusScreen(c: c),
            6 => RecordsScreen(c: c, kind: 'note'),
            7 => RecordsScreen(c: c, kind: 'goal'),
            8 => RecordsScreen(c: c, kind: 'habit'),
            9 => AnalyticsScreen(c: c),
            11 => DisciplineScreen(c: c),
            12 => SyncScreen(c: c),
            _ => SettingsScreen(c: c),
          };
    final nav = ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 30),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(14, 0, 0, 4),
          child: Text(
            'F O C U S',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 0, 36),
          child: Text(
            'Space for what matters',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        for (var i = 0; i < destinations.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              selected: selected == i,
              selectedTileColor: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: .10),
              leading: Icon(destinationIcons[i], size: 21),
              title: Text(destinations[i]),
              onTap: () {
                setState(() {
                  selected = i;
                  search = '';
                  searchController.clear();
                });
                if (!wide) Navigator.pop(context);
              },
            ),
          ),
        const SizedBox(height: 30),
        const Padding(
          padding: EdgeInsets.all(14),
          child: Text(
            'PRIVATE BY DEFAULT\nSaved on this device',
            style: TextStyle(fontSize: 11, height: 1.7, letterSpacing: .6),
          ),
        ),
      ],
    );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyN, control: true): capture,
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            searchFocus.requestFocus(),
      },
      child: Scaffold(
        drawer: wide ? null : Drawer(child: SafeArea(child: nav)),
        appBar: wide
            ? null
            : AppBar(
                title: const Text('F O C U S', style: TextStyle(fontSize: 18)),
              ),
        body: SafeArea(
          child: Row(
            children: [
              if (wide) ...[
                SizedBox(width: 225, child: nav),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(
                        wide ? 40 : 20,
                        18,
                        wide ? 40 : 20,
                        14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: searchController,
                              focusNode: searchFocus,
                              onChanged: (v) => setState(() => search = v),
                              decoration: const InputDecoration(
                                hintText:
                                    'Search tasks, projects, notes and goals',
                                prefixIcon: Icon(Icons.search, size: 20),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                          if (wide) ...[
                            const SizedBox(width: 20),
                            Text(
                              DateFormat('EEE, MMM d').format(DateTime.now()),
                            ),
                          ],
                          const SizedBox(width: 12),
                          IconButton(
                            onPressed: c.busy ? null : capture,
                            tooltip: 'Quick capture (Ctrl+N)',
                            icon: const Icon(Icons.add),
                          ),
                        ],
                      ),
                    ),
                    if (c.error != null)
                      MaterialBanner(
                        content: Text(c.error!),
                        actions: [
                          TextButton(
                            onPressed: () {
                              c.dismissError();
                            },
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    if (c.notice != null)
                      MaterialBanner(
                        content: Text(c.notice!),
                        actions: [
                          TextButton(
                            onPressed: c.dismissNotice,
                            child: const Text('Dismiss'),
                          ),
                        ],
                      ),
                    if (c.busy) const LinearProgressIndicator(minHeight: 2),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: KeyedSubtree(
                          key: ValueKey('$selected/${search.isNotEmpty}'),
                          child: body,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: [0, 2, 5, 9].contains(selected)
                    ? [0, 2, 5, 9].indexOf(selected)
                    : 4,
                onDestinationSelected: (i) {
                  if (i == 4) {
                    showModalBottomSheet<void>(
                      context: context,
                      builder: (ctx) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final n in [1, 3, 4, 6, 7, 8, 11, 12, 10])
                              ListTile(
                                leading: Icon(destinationIcons[n]),
                                title: Text(destinations[n]),
                                onTap: () {
                                  Navigator.pop(ctx);
                                  navigate(n);
                                },
                              ),
                          ],
                        ),
                      ),
                    );
                  } else {
                    navigate([0, 2, 5, 9][i]);
                  }
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.wb_sunny_outlined),
                    label: 'Today',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.check_circle_outline),
                    label: 'Tasks',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.timelapse),
                    label: 'Focus',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.bar_chart),
                    label: 'Analytics',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.more_horiz),
                    label: 'More',
                  ),
                ],
              ),
      ),
    );
  }
}

class Onboarding extends StatefulWidget {
  final FocusController c;
  const Onboarding({super.key, required this.c});
  @override
  State<Onboarding> createState() => _OnboardingState();
}

class _OnboardingState extends State<Onboarding> {
  int step = 0;
  final titles = [
    'Take back control\nof your attention.',
    'A clear place\nto begin your day.',
    'Protect the hours\nthat restore you.',
    'Your data.\nYour device.',
  ];
  final copy = [
    'Plan your day, capture ideas and make room for deep work. Focus works offline, without an account.',
    'Bring tasks, projects, notes and focus sessions into one quiet workspace. Start small: one meaningful priority today.',
    'Night Lock defaults to 9 PM–7 AM. Emergency access stays immediate. You can configure essential apps and enable restriction separately in Settings.',
    'Android usage access and Night Lock permissions are optional and requested only when you enable those features. No analytics or notes are sent to a server.',
  ];
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'F O C U S     /     0${step + 1}',
                  style: const TextStyle(letterSpacing: 2),
                ),
                const SizedBox(height: 64),
                Icon(
                  [
                    Icons.filter_center_focus,
                    Icons.wb_sunny_outlined,
                    Icons.nightlight_round,
                    Icons.lock_outline,
                  ][step],
                  size: 54,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 32),
                Text(
                  titles[step],
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 24),
                Text(copy[step], style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 40),
                if (step == 3)
                  const Text(
                    'Initial targets: 3h 30m phone budget · 4h focus\nAdjust these in Settings to fit your day.',
                  ),
                const SizedBox(height: 32),
                Row(
                  children: [
                    if (step > 0)
                      TextButton(
                        onPressed: () => setState(() => step--),
                        child: const Text('Back'),
                      ),
                    const Spacer(),
                    FilledButton(
                      onPressed: widget.c.busy
                          ? null
                          : () {
                              if (step < 3) {
                                setState(() => step++);
                              } else {
                                widget.c.set('onboarded', true);
                              }
                            },
                      child: Text(step == 3 ? 'Begin with today' : 'Continue'),
                    ),
                  ],
                ),
                if (widget.c.error != null) Text(widget.c.error!),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
