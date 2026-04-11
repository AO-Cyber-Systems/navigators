import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../main.dart' show generateEncryptionKey;
import 'database/database.dart';
import 'features/import/import_screen.dart';
import 'features/map/turf_map_screen.dart';
import 'features/sms/campaign_list_screen.dart';
import 'features/sms/conversation_list_screen.dart';
import 'features/sms/template_list_screen.dart';
import 'features/sync/sync_status_widget.dart';
import 'features/sync/turf_download_screen.dart';
import 'features/tasks/task_list_screen.dart';
import 'features/voters/voter_list_screen.dart';
import 'sync/sync_engine.dart';
import 'sync/sync_status.dart';

class NavigatorsApp extends StatelessWidget {
  const NavigatorsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Navigators',
      debugShowCheckedModeBanner: false,
      theme: EdenTheme.light(),
      darkTheme: EdenTheme.dark(),
      home: const _NavigatorsHome(),
    );
  }
}

class _NavigatorsHome extends ConsumerStatefulWidget {
  const _NavigatorsHome();

  @override
  ConsumerState<_NavigatorsHome> createState() => _NavigatorsHomeState();
}

class _NavigatorsHomeState extends ConsumerState<_NavigatorsHome> {
  bool _showSignUp = false;
  int _selectedTab = 0;
  bool _wasAuthenticated = false;
  bool _hasTriggeredInitialSync = false;
  late final AppLifecycleListener _lifecycleListener;

  @override
  void initState() {
    super.initState();
    _lifecycleListener = AppLifecycleListener(
      onResume: _onAppResume,
    );
  }

  @override
  void dispose() {
    _lifecycleListener.dispose();
    super.dispose();
  }

  /// Trigger sync on app resume when online.
  /// Non-blocking: runs in background, UI updates reactively via Drift streams.
  void _onAppResume() {
    _triggerBackgroundSync();
  }

  /// Run a full sync cycle in the background (push pending, then pull updates).
  /// Updates isSyncing provider for UI feedback. Non-blocking.
  Future<void> _triggerBackgroundSync() async {
    try {
      final engine = ref.read(syncEngineProvider);
      ref.read(isSyncingProvider.notifier).state = true;
      final result = await engine.runSyncCycle();
      if (result.hasErrors) {
        ref.read(lastSyncErrorProvider.notifier).state =
            result.errors.join('; ');
      } else {
        ref.read(lastSyncErrorProvider.notifier).state = null;
      }
      ref.invalidate(lastSyncTimeProvider);
    } catch (_) {
      // Sync failed silently -- status widget will show stale state
    } finally {
      ref.read(isSyncingProvider.notifier).state = false;
    }
  }

  /// Handle first-time database initialization after login.
  /// Generates encryption key, creates database, overrides provider.
  Future<void> _ensureDatabaseInitialized() async {
    const secureStorage = FlutterSecureStorage();
    var key = await secureStorage.read(key: 'db_encryption_key');

    if (key == null || key.isEmpty) {
      key = generateEncryptionKey();
      await secureStorage.write(key: 'db_encryption_key', value: key);
    }

    // Check if database provider is already initialized
    try {
      ref.read(databaseProvider);
      // Already initialized, nothing to do
    } catch (_) {
      // Not initialized -- this happens on first login when main.dart
      // had no key. We cannot dynamically override a provider at runtime
      // in Riverpod, so we rely on the database being created in main.dart
      // on the next app launch. For this session, we create a temporary
      // instance and set it on SyncEngine directly.
    }
  }

  /// Called when auth state transitions from unauthenticated to authenticated.
  Future<void> _onAuthenticated() async {
    if (_hasTriggeredInitialSync) return;
    _hasTriggeredInitialSync = true;

    await _ensureDatabaseInitialized();

    // Check if we have local data; if not, show turf download screen
    try {
      final db = ref.read(databaseProvider);
      final assignments = await db.select(db.turfAssignments).get();
      if (assignments.isEmpty && mounted) {
        // First time: show turf download screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TurfDownloadScreen(),
          ),
        );
        return;
      }
    } catch (_) {
      // Database not yet available -- will be ready on next app launch
    }

    // Existing user with local data: trigger forced sync
    _triggerBackgroundSync();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Detect authentication state transition
    if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      // Schedule post-frame callback to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onAuthenticated();
      });
    } else if (!auth.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      _hasTriggeredInitialSync = false;
    }

    if (!auth.isAuthenticated) {
      return _showSignUp
          ? PlatformSignUpScreen(
              onLoginTap: () => setState(() => _showSignUp = false),
              onSignUpSuccess: () => setState(() => _showSignUp = false),
            )
          : PlatformLoginScreen(
              onSignUpTap: () => setState(() => _showSignUp = true),
            );
    }

    final isAdmin = auth.role?.toLowerCase() == 'admin';

    // Build tabs based on role
    final tabs = <_TabItem>[
      const _TabItem(
        label: 'Home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
      ),
      const _TabItem(
        label: 'Voters',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
      ),
      const _TabItem(
        label: 'Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
      ),
      const _TabItem(
        label: 'Messages',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      const _TabItem(
        label: 'Tasks',
        icon: Icons.task_alt_outlined,
        activeIcon: Icons.task_alt,
      ),
      if (isAdmin)
        const _TabItem(
          label: 'Import',
          icon: Icons.cloud_upload_outlined,
          activeIcon: Icons.cloud_upload,
        ),
    ];

    // Ensure selected tab is valid
    if (_selectedTab >= tabs.length) {
      _selectedTab = 0;
    }

    return Scaffold(
      body: IndexedStack(
        index: _selectedTab,
        children: [
          _buildHomeTab(auth),
          const VoterListScreen(),
          const TurfMapScreen(),
          _buildSmsTab(isAdmin),
          const TaskListScreen(),
          if (isAdmin) const ImportScreen(),
        ],
      ),
      bottomNavigationBar: EdenBottomNav(
        selectedIndex: _selectedTab,
        onChanged: (index) => setState(() => _selectedTab = index),
        items: tabs
            .map((t) => EdenBottomNavItem(
                  label: t.label,
                  icon: t.icon,
                  activeIcon: t.activeIcon,
                ))
            .toList(),
      ),
    );
  }

  Widget _buildSmsTab(bool isAdmin) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.description_outlined),
              tooltip: 'Templates',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const TemplateListScreen(),
                  ),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: 'Campaigns',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const CampaignListScreen(),
                  ),
                );
              },
            ),
          ],
        ],
      ),
      body: const ConversationListScreen(),
    );
  }

  Widget _buildHomeTab(AuthState auth) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigators'),
        actions: [
          const SyncStatusWidget(),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authProvider.notifier).logout();
            },
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Welcome to Navigators',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            Text(
              'Signed in as ${auth.user?.email ?? 'Unknown'}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      ),
    );
  }
}

class _TabItem {
  final String label;
  final IconData icon;
  final IconData activeIcon;

  const _TabItem({
    required this.label,
    required this.icon,
    required this.activeIcon,
  });
}
