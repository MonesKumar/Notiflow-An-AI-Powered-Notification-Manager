import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() => runApp(const NotiflowApp());

const categories = ['Critical', 'Important', 'Social', 'Promotional'];
const tones = [
  Color(0xFFE35B61),
  Color(0xFFF4A74D),
  Color(0xFF5D9FE8),
  Color(0xFF8B96A7)
];
Color tone(String category) => tones[categories.indexOf(category).clamp(0, 3)];
IconData symbol(String category) => [
      Icons.priority_high_rounded,
      Icons.star_rounded,
      Icons.forum_rounded,
      Icons.local_offer_rounded
    ][categories.indexOf(category).clamp(0, 3)];

class Entry {
  Entry(Map<dynamic, dynamic> m)
      : id = (m['id'] as num).toInt(),
        pkg = '${m['pkg']}',
        app = '${m['app']}',
        title = '${m['title']}',
        body = '${m['body']}',
        time = DateTime.fromMillisecondsSinceEpoch((m['time'] as num).toInt()),
        category = '${m['category']}',
        read = m['read'] == true,
        demo = m['demo'] == true;
  final int id;
  final String pkg, app, title, body, category;
  final DateTime time;
  final bool read, demo;
}

String timeLabel(DateTime time) {
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return 'Now';
  if (diff.inHours < 1) return '${diff.inMinutes}m ago';
  if (diff.inDays < 1) return '${diff.inHours}h ago';
  return '${time.day}/${time.month}/${time.year}';
}

class NotiflowApp extends StatefulWidget {
  const NotiflowApp({super.key});
  @override
  State<NotiflowApp> createState() => _AppState();
}

class _AppState extends State<NotiflowApp> with WidgetsBindingObserver {
  static const native = MethodChannel('com.notiflow.app/native');
  bool access = false, loading = true, demoMode = false;
  int page = -1;
  String filter = 'All', search = '', error = '';
  List<Entry> entries = [];
  List<Map<String, String>> preferences = [];
  Timer? ticker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    refresh();
    ticker = Timer.periodic(const Duration(seconds: 5), (_) {
      if (page >= 0) refresh(silent: true);
    });
  }

  @override
  void dispose() {
    ticker?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh({bool silent = false}) async {
    try {
      final granted = await native.invokeMethod<bool>('hasAccess') ?? false;
      final rows = await native.invokeListMethod<dynamic>('list') ?? [];
      final prefs = await native.invokeListMethod<dynamic>('preferences') ?? [];
      if (!mounted) return;
      setState(() {
        access = granted;
        entries = rows.map((e) => Entry(e as Map)).toList();
        preferences =
            prefs.map((e) => Map<String, String>.from(e as Map)).toList();
        loading = false;
        error = '';
        if (page == -1 && (granted || demoMode)) page = 0;
      });
    } catch (e) {
      if (mounted && !silent)
        setState(() {
          loading = false;
          error = 'Could not load local data: $e';
        });
    }
  }

  Future<void> run(String operation, [Map<String, dynamic>? args]) async {
    try {
      await native.invokeMethod<void>(operation, args);
      await refresh();
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
    }
  }

  void startDemo() {
    setState(() {
      demoMode = true;
      page = 0;
    });
    run('seed');
  }

  void showEntry(Entry entry) async {
    await run('markRead', {'id': entry.id});
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => DetailScreen(entry: entry, run: run)));
    refresh();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7169F6),
        brightness: MediaQuery.platformBrightnessOf(context));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Notiflow',
      theme: ThemeData(
          useMaterial3: true,
          colorScheme: scheme,
          scaffoldBackgroundColor: scheme.surface),
      home: Builder(builder: (context) {
        if (loading)
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        if (page == -1)
          return WelcomeScreen(
              access: access,
              onPermission: () => setState(() => page = -2),
              onDemo: startDemo);
        if (page == -2)
          return PermissionScreen(
              access: access,
              onBack: () => setState(() => page = -1),
              onGrant: () => run('requestAccess'),
              onDemo: startDemo,
              onContinue: () => setState(() => page = 0));
        return Scaffold(
          appBar: AppBar(
              title: Row(children: [
                Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.notifications_active_rounded,
                        color: scheme.primary, size: 19)),
                const SizedBox(width: 10),
                const Text('Notiflow',
                    style: TextStyle(fontWeight: FontWeight.w800))
              ]),
              actions: [
                if (!access)
                  IconButton(
                      tooltip: 'Notification access',
                      onPressed: () => setState(() => page = -2),
                      icon: const Icon(Icons.shield_outlined)),
                IconButton(
                    tooltip: 'Refresh',
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh_rounded))
              ]),
          body: error.isNotEmpty
              ? Center(child: Text(error))
              : IndexedStack(index: page, children: [
                  Dashboard(
                      entries: entries,
                      access: access,
                      onPermission: () => setState(() => page = -2),
                      onDemo: startDemo,
                      onBrowse: (category) => setState(() {
                            filter = category;
                            page = 1;
                          }),
                      onEntry: showEntry),
                  History(
                      entries: entries,
                      filter: filter,
                      search: search,
                      onFilter: (v) => setState(() => filter = v),
                      onSearch: (v) => setState(() => search = v),
                      onEntry: showEntry),
                  SettingsScreen(
                      access: access,
                      preferences: preferences,
                      onPermission: () => setState(() => page = -2),
                      onDemo: startDemo,
                      run: run),
                ]),
          bottomNavigationBar: NavigationBar(
              selectedIndex: page,
              onDestinationSelected: (v) => setState(() => page = v),
              destinations: const [
                NavigationDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard_rounded),
                    label: 'Home'),
                NavigationDestination(
                    icon: Icon(Icons.inbox_outlined),
                    selectedIcon: Icon(Icons.inbox_rounded),
                    label: 'Inbox'),
                NavigationDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings_rounded),
                    label: 'Settings')
              ]),
        );
      }),
    );
  }
}

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen(
      {super.key,
      required this.access,
      required this.onPermission,
      required this.onDemo});
  final bool access;
  final VoidCallback onPermission, onDemo;
  @override
  Widget build(BuildContext context) => Scaffold(
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Spacer(),
                    Container(
                        padding: const EdgeInsets.all(22),
                        decoration: BoxDecoration(
                            color:
                                Theme.of(context).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(28)),
                        child: Icon(Icons.notifications_active_rounded,
                            size: 54,
                            color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: 30),
                    Text('Your notifications,\nfinally in flow.',
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 16),
                    Text(
                        'A calm, color-coded inbox for the alerts that matter to you. Your data stays on this device.',
                        style: Theme.of(context).textTheme.bodyLarge),
                    const Spacer(),
                    FilledButton.icon(
                        onPressed: onPermission,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Get started'),
                        style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 54))),
                    const SizedBox(height: 10),
                    OutlinedButton(
                        onPressed: onDemo,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52)),
                        child: const Text('Explore with sample notifications')),
                    const SizedBox(height: 16),
                  ]))));
}

class PermissionScreen extends StatelessWidget {
  const PermissionScreen(
      {super.key,
      required this.access,
      required this.onBack,
      required this.onGrant,
      required this.onDemo,
      required this.onContinue});
  final bool access;
  final VoidCallback onBack, onGrant, onDemo, onContinue;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(
          leading: IconButton(
              onPressed: onBack, icon: const Icon(Icons.arrow_back))),
      body: SafeArea(
          child: Padding(
              padding: const EdgeInsets.all(26),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 58, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: 22),
                    Text('Notification access',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    const Text(
                        'Notiflow needs Android notification listener access to display supported alerts from your apps. This grants broad access to notification content. Only enable it if you are comfortable with that access.'),
                    const SizedBox(height: 18),
                    const ListTile(
                        leading: Icon(Icons.lock_outline),
                        title: Text('Processed and stored on this device'),
                        subtitle: Text(
                            'No account, cloud upload, analytics, or internet required.')),
                    const ListTile(
                        leading: Icon(Icons.visibility_off_outlined),
                        title: Text('Sensitive content is withheld'),
                        subtitle: Text(
                            'Recognized codes and password alerts are redacted before storage. Android may also hide content.')),
                    const ListTile(
                        leading: Icon(Icons.tune),
                        title: Text('Suggestions you can correct'),
                        subtitle: Text(
                            'Notiflow does not silence or delete original Android alerts.')),
                    const Spacer(),
                    if (access)
                      FilledButton(
                          onPressed: onContinue,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                          child: const Text('Continue to dashboard'))
                    else
                      FilledButton(
                          onPressed: onGrant,
                          style: FilledButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52)),
                          child: const Text('Open Android access settings')),
                    TextButton(
                        onPressed: onDemo,
                        child: const Text('Try clearly labeled demo data')),
                  ]))));
}

class Dashboard extends StatelessWidget {
  const Dashboard(
      {super.key,
      required this.entries,
      required this.access,
      required this.onPermission,
      required this.onDemo,
      required this.onBrowse,
      required this.onEntry});
  final List<Entry> entries;
  final bool access;
  final VoidCallback onPermission, onDemo;
  final ValueChanged<String> onBrowse;
  final ValueChanged<Entry> onEntry;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return RefreshIndicator(
        onRefresh: () async {
          onBrowse('All');
        },
        child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
            children: [
              Text('Your overview',
                  style: theme.textTheme.headlineMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text('A clearer view of what arrived',
                  style: TextStyle(color: scheme.onSurfaceVariant)),
              const SizedBox(height: 20),
              if (!access)
                Card(
                    color: scheme.primaryContainer,
                    child: ListTile(
                        leading: const Icon(Icons.info_outline),
                        title: const Text('Live capture is off'),
                        subtitle: const Text(
                            'Grant Android notification access to collect real alerts.'),
                        trailing: const Icon(Icons.arrow_forward),
                        onTap: onPermission)),
              if (!access) const SizedBox(height: 12),
              Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF655DEB), Color(0xFF9589FF)]),
                      borderRadius: BorderRadius.circular(26)),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('TOTAL RECEIVED',
                            style: TextStyle(
                                color: Colors.white70,
                                letterSpacing: 1.3,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(height: 9),
                        Text('${entries.length}',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900)),
                        const SizedBox(height: 5),
                        const Text('Stored locally in your inbox',
                            style: TextStyle(color: Colors.white))
                      ])),
              const SizedBox(height: 22),
              Row(children: [
                Text('Categories',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                TextButton(
                    onPressed: () => onBrowse('All'),
                    child: const Text('View all'))
              ]),
              GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 4,
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 270,
                      childAspectRatio: 1.55,
                      crossAxisSpacing: 11,
                      mainAxisSpacing: 11),
                  itemBuilder: (_, i) {
                    final category = categories[i];
                    return InkWell(
                        borderRadius: BorderRadius.circular(22),
                        onTap: () => onBrowse(category),
                        child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: tone(category).withValues(alpha: .12),
                                borderRadius: BorderRadius.circular(22)),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Icon(symbol(category), color: tone(category)),
                                  Row(children: [
                                    Expanded(
                                        child: Text(category,
                                            maxLines: 1,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.w700))),
                                    Text(
                                        '${entries.where((e) => e.category == category).length}',
                                        style: const TextStyle(
                                            fontSize: 23,
                                            fontWeight: FontWeight.w800))
                                  ])
                                ])));
                  }),
              const SizedBox(height: 22),
              Row(children: [
                Text('Recent activity',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(
                    tooltip: 'Load demo samples',
                    onPressed: onDemo,
                    icon: const Icon(Icons.science_outlined))
              ]),
              if (entries.isEmpty)
                const EmptyInbox()
              else
                ...entries
                    .take(5)
                    .map((e) => EntryTile(entry: e, onTap: () => onEntry(e))),
            ]));
  }
}

class History extends StatelessWidget {
  const History(
      {super.key,
      required this.entries,
      required this.filter,
      required this.search,
      required this.onFilter,
      required this.onSearch,
      required this.onEntry});
  final List<Entry> entries;
  final String filter, search;
  final ValueChanged<String> onFilter, onSearch;
  final ValueChanged<Entry> onEntry;
  @override
  Widget build(BuildContext context) {
    final shown = entries
        .where((e) =>
            (filter == 'All' || e.category == filter) &&
            '${e.app} ${e.title} ${e.body}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    return Column(children: [
      Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Inbox',
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            TextField(
                onChanged: onSearch,
                decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Search notifications',
                    filled: true,
                    border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(16))))
          ])),
      SizedBox(
          height: 54,
          child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: ['All', ...categories]
                  .map((v) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                          label: Text(v),
                          selected: filter == v,
                          onSelected: (_) => onFilter(v))))
                  .toList())),
      Expanded(
          child: shown.isEmpty
              ? const EmptyInbox()
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  itemCount: shown.length,
                  itemBuilder: (_, i) => EntryTile(
                      entry: shown[i], onTap: () => onEntry(shown[i])))),
    ]);
  }
}

class EmptyInbox extends StatelessWidget {
  const EmptyInbox({super.key});
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.inbox_outlined,
                size: 52, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 14),
            const Text('Nothing here yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            const Text('New alerts or demo samples will appear here.',
                textAlign: TextAlign.center)
          ])));
}

class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.entry, required this.onTap});
  final Entry entry;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
              padding: const EdgeInsets.all(14),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                        color: tone(entry.category).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(13)),
                    child: Icon(symbol(entry.category),
                        color: tone(entry.category))),
                const SizedBox(width: 13),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Row(children: [
                        Expanded(
                            child: Text(entry.app,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold))),
                        Text(timeLabel(entry.time),
                            style: Theme.of(context).textTheme.bodySmall)
                      ]),
                      const SizedBox(height: 4),
                      Text(entry.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: entry.read
                                  ? FontWeight.normal
                                  : FontWeight.w700)),
                      if (entry.body.isNotEmpty)
                        Text(entry.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 8),
                      Wrap(spacing: 6, children: [
                        Tag(entry.category, tone(entry.category)),
                        if (entry.demo)
                          const Tag('SIMULATED', Color(0xFF7867D8))
                      ])
                    ]))
              ]))));
}

class Tag extends StatelessWidget {
  const Tag(this.label, this.color, {super.key});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w800)));
}

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.entry, required this.run});
  final Entry entry;
  final Future<void> Function(String, [Map<String, dynamic>?]) run;
  @override
  State<DetailScreen> createState() => _DetailState();
}

class _DetailState extends State<DetailScreen> {
  late String category;
  @override
  void initState() {
    super.initState();
    category = widget.entry.category;
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.entry;
    return Scaffold(
        appBar: AppBar(title: const Text('Notification details'), actions: [
          IconButton(
              tooltip: 'Delete local copy',
              onPressed: () async {
                await widget.run('delete', {'id': e.id});
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline))
        ]),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          Icon(symbol(category), size: 46, color: tone(category)),
          const SizedBox(height: 16),
          Text(e.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Text(e.body.isEmpty
              ? 'No readable message content was available.'
              : e.body),
          const SizedBox(height: 20),
          Wrap(spacing: 8, children: [
            Tag(category, tone(category)),
            if (e.demo) const Tag('SIMULATED', Color(0xFF7867D8))
          ]),
          const SizedBox(height: 20),
          Text(
              '${e.app}  •  ${e.time.toLocal()}\n${e.demo ? 'Simulated notification' : 'Captured Android notification'}',
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 28),
          Text('Correct category',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          const Text(
              'Your correction also sets a preference for future alerts from this app.'),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 6,
              children: categories
                  .map((v) => ChoiceChip(
                      label: Text(v),
                      selected: category == v,
                      onSelected: (_) async {
                        await widget
                            .run('correct', {'id': e.id, 'category': v});
                        if (mounted) setState(() => category = v);
                      }))
                  .toList()),
          const SizedBox(height: 30),
          if (!e.demo)
            OutlinedButton.icon(
                onPressed: () async {
                  try {
                    final ok = await _AppState.native
                            .invokeMethod<bool>('openApp', {'pkg': e.pkg}) ??
                        false;
                    if (!ok && context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text(
                              'This app cannot be opened from Notiflow.')));
                  } catch (_) {}
                },
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open associated app')),
          const SizedBox(height: 8),
          Text(
              'Read and delete actions affect only Notiflow’s local history, not Android’s original alert.',
              style: Theme.of(context).textTheme.bodySmall)
        ]));
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen(
      {super.key,
      required this.access,
      required this.preferences,
      required this.onPermission,
      required this.onDemo,
      required this.run});
  final bool access;
  final List<Map<String, String>> preferences;
  final VoidCallback onPermission, onDemo;
  final Future<void> Function(String, [Map<String, dynamic>?]) run;
  Future<void> confirm(
      BuildContext context, String title, String method) async {
    final yes = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: Text(title),
                content: const Text(
                    'This action changes only Notiflow’s local data.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Confirm'))
                ]));
    if (yes == true) await run(method);
  }

  @override
  Widget build(BuildContext context) =>
      ListView(padding: const EdgeInsets.all(20), children: [
        Text('Settings',
            style: Theme.of(context)
                .textTheme
                .headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        const Text('ACCESS & PRIVACY',
            style: TextStyle(fontWeight: FontWeight.bold)),
        SwitchListTile(
            value: access,
            onChanged: (_) => onPermission(),
            title: const Text('Android notification access'),
            subtitle: Text(access
                ? 'Enabled • manage in Android settings'
                : 'Off • tap to open Android settings')),
        const ListTile(
            leading: Icon(Icons.phonelink_lock_outlined),
            title: Text('On-device processing'),
            subtitle: Text(
                'Notification history stays in app-private SQLite storage. No network service or analytics.')),
        const Divider(),
        const Text('DEMONSTRATION',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ListTile(
            leading: const Icon(Icons.science_outlined),
            title: const Text('Load sample notifications'),
            subtitle: const Text('Clearly labeled simulated entries'),
            onTap: onDemo),
        ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: const Text('Remove demo entries'),
            onTap: () => confirm(context, 'Remove demo entries?', 'clearDemo')),
        const Divider(),
        const Text('LEARNED APP PREFERENCES',
            style: TextStyle(fontWeight: FontWeight.bold)),
        if (preferences.isEmpty)
          const ListTile(
              title: Text('No corrections saved yet'),
              subtitle: Text(
                  'Correct an item’s category to create an app preference.')),
        ...preferences.map((p) => ListTile(
            title: Text(p['pkg'] ?? ''),
            subtitle: Text('Future alerts → ${p['category']}'),
            trailing: IconButton(
                tooltip: 'Remove preference',
                icon: const Icon(Icons.close),
                onPressed: () => run('removePreference', {'pkg': p['pkg']})))),
        if (preferences.isNotEmpty)
          TextButton(
              onPressed: () => confirm(
                  context, 'Reset all preferences?', 'clearPreferences'),
              child: const Text('Reset classification preferences')),
        const Divider(),
        ListTile(
            leading: const Icon(Icons.delete_forever_outlined),
            title: const Text('Clear local notification history'),
            subtitle: const Text('Keeps your classification preferences'),
            onTap: () =>
                confirm(context, 'Clear all stored notifications?', 'clear')),
        const SizedBox(height: 15),
        const Text(
            'Classification uses local rules and explicit app preferences. This prototype does not contain a trained ML model or change original Android notifications.')
      ]);
}
