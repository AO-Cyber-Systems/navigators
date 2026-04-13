import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
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
import 'features/dashboard/admin_dashboard_screen.dart';
import 'features/dashboard/navigator_dashboard_screen.dart';
import 'features/dashboard/team_dashboard_screen.dart';
import 'features/events/event_list_screen.dart';
import 'features/leaderboard/leaderboard_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/sync/sync_status_widget.dart';
import 'features/sync/turf_download_screen.dart';
import 'features/tasks/task_list_screen.dart';
import 'features/training/training_list_screen.dart';
import 'features/voters/voter_list_screen.dart';
import 'services/volunteer_service.dart';
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
  String _selectedNavId = 'home';
  bool _wasAuthenticated = false;
  bool _hasTriggeredInitialSync = false;
  bool _onboardingComplete = true;
  bool _onboardingChecked = false;
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

  void _onAppResume() {
    _triggerBackgroundSync();
  }

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

  Future<void> _ensureDatabaseInitialized() async {
    // On web, database is initialized in main.dart; nothing to do here.
    if (kIsWeb) return;

    const secureStorage = FlutterSecureStorage();
    var key = await secureStorage.read(key: 'db_encryption_key');

    if (key == null || key.isEmpty) {
      key = generateEncryptionKey();
      await secureStorage.write(key: 'db_encryption_key', value: key);
    }

    try {
      ref.read(databaseProvider);
    } catch (_) {
      // Not initialized -- relies on next app launch
    }
  }

  Future<void> _onAuthenticated() async {
    if (_hasTriggeredInitialSync) return;
    _hasTriggeredInitialSync = true;

    await _ensureDatabaseInitialized();

    try {
      final volunteerService = ref.read(volunteerServiceProvider);
      final status = await volunteerService.getOnboardingStatus();
      final complete = status['onboardingComplete'] == true;
      if (mounted) {
        setState(() {
          _onboardingComplete = complete;
          _onboardingChecked = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _onboardingChecked = true);
      }
    }

    try {
      final db = ref.read(databaseProvider);
      final assignments = await db.select(db.turfAssignments).get();
      if (assignments.isEmpty && mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const TurfDownloadScreen(),
          ),
        );
        return;
      }
    } catch (_) {
      // Database not yet available
    }

    _triggerBackgroundSync();
  }

  /// Build the nav items list based on role.
  List<EdenNavItem> _buildNavItems(bool isAdmin) {
    return [
      const EdenNavItem(
        id: 'home',
        label: 'Dashboard',
        icon: Icons.home_outlined,
        activeIcon: Icons.home,
      ),
      const EdenNavItem(
        id: 'voters',
        label: 'Voters',
        icon: Icons.people_outline,
        activeIcon: Icons.people,
      ),
      const EdenNavItem(
        id: 'map',
        label: 'Map',
        icon: Icons.map_outlined,
        activeIcon: Icons.map,
      ),
      const EdenNavItem(
        id: 'messages',
        label: 'Messages',
        icon: Icons.chat_bubble_outline,
        activeIcon: Icons.chat_bubble,
      ),
      const EdenNavItem(
        id: 'tasks',
        label: 'Tasks',
        icon: Icons.task_alt_outlined,
        activeIcon: Icons.task_alt,
      ),
      const EdenNavItem(
        id: 'events',
        label: 'Events',
        icon: Icons.event_outlined,
        activeIcon: Icons.event,
      ),
      const EdenNavItem.divider(),
      const EdenNavItem(
        id: 'leaderboard',
        label: 'Leaderboard',
        icon: Icons.leaderboard_outlined,
        activeIcon: Icons.leaderboard,
      ),
      const EdenNavItem(
        id: 'training',
        label: 'Training',
        icon: Icons.school_outlined,
        activeIcon: Icons.school,
      ),
      if (isAdmin)
        const EdenNavItem(
          id: 'import',
          label: 'Import',
          icon: Icons.cloud_upload_outlined,
          activeIcon: Icons.cloud_upload,
        ),
    ];
  }

  /// Build the body widget for the selected nav item.
  Widget _buildBody(AuthState auth, bool isAdmin) {
    return switch (_selectedNavId) {
      'home' => _buildDashboardBody(auth),
      'voters' => const VoterListScreen(),
      'map' => const TurfMapScreen(),
      'messages' => _buildMessagesBody(isAdmin),
      'tasks' => const TaskListScreen(),
      'events' => const EventListScreen(),
      'leaderboard' => const LeaderboardScreen(),
      'training' => const TrainingListScreen(),
      'import' when isAdmin => const ImportScreen(),
      _ => _buildDashboardBody(auth),
    };
  }

  Widget _buildDashboardBody(AuthState auth) {
    final role = auth.role?.toLowerCase() ?? '';
    return switch (role) {
      'admin' => const AdminDashboardScreen(),
      'super_navigator' => const TeamDashboardScreen(),
      _ => const NavigatorDashboardScreen(),
    };
  }

  Widget _buildMessagesBody(bool isAdmin) {
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

  /// Get a display title for the current nav section.
  String _navTitle() {
    return switch (_selectedNavId) {
      'home' => 'Dashboard',
      'voters' => 'Voters',
      'map' => 'Map',
      'messages' => 'Messages',
      'tasks' => 'Tasks',
      'events' => 'Events',
      'leaderboard' => 'Leaderboard',
      'training' => 'Training',
      'import' => 'Import',
      _ => 'Dashboard',
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    // Detect authentication state transition
    if (auth.isAuthenticated && !_wasAuthenticated) {
      _wasAuthenticated = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onAuthenticated();
      });
    } else if (!auth.isAuthenticated && _wasAuthenticated) {
      _wasAuthenticated = false;
      _hasTriggeredInitialSync = false;
      _onboardingComplete = true;
      _onboardingChecked = false;
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

    // Onboarding gate
    if (auth.isAuthenticated && _onboardingChecked && !_onboardingComplete) {
      return OnboardingScreen(
        onComplete: () => setState(() => _onboardingComplete = true),
      );
    }

    final isAdmin = auth.role?.toLowerCase() == 'admin';
    final navItems = _buildNavItems(isAdmin);
    final body = _buildBody(auth, isAdmin);

    final user = EdenLayoutUser(
      name: auth.user?.displayName ?? auth.user?.email ?? 'User',
      email: auth.user?.email,
      initials: _initials(auth),
      onTap: () => _showUserMenu(context, auth),
    );

    final topBarActions = <Widget>[
      const SyncStatusWidget(),
    ];

    // Use responsive layout: desktop sidebar on wide screens, mobile bottom nav on narrow
    if (EdenResponsive.isDesktop(context)) {
      return EdenDesktopLayout(
        navItems: navItems,
        selectedId: _selectedNavId,
        onNavChanged: (id) => setState(() => _selectedNavId = id),
        body: body,
        logo: Text(
          'Navigators',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        collapsedLogo: const Icon(Icons.navigation, size: 20),
        user: user,
        topBar: EdenTopBarConfig(
          title: _navTitle(),
          actions: topBarActions,
        ),
      );
    }

    // Tablet: sidebar collapsed by default
    if (EdenResponsive.isTablet(context)) {
      return EdenDesktopLayout(
        navItems: navItems,
        selectedId: _selectedNavId,
        onNavChanged: (id) => setState(() => _selectedNavId = id),
        body: body,
        logo: Text(
          'Navigators',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        collapsedLogo: const Icon(Icons.navigation, size: 20),
        user: user,
        initiallyCollapsed: true,
        topBar: EdenTopBarConfig(
          title: _navTitle(),
          actions: topBarActions,
        ),
      );
    }

    // Mobile: bottom nav
    return EdenMobileLayout(
      navItems: navItems,
      selectedId: _selectedNavId,
      onNavChanged: (id) => setState(() => _selectedNavId = id),
      body: body,
      user: user,
      logo: Text(
        'Navigators',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
      ),
      topBar: EdenTopBarConfig(
        title: _navTitle(),
        actions: topBarActions,
      ),
    );
  }

  String? _initials(AuthState auth) {
    final name = auth.user?.displayName;
    if (name == null || name.isEmpty) return null;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  void _showUserMenu(BuildContext context, AuthState auth) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor:
                          Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                      child: Text(
                        _initials(auth) ?? '?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            auth.user?.displayName ?? 'User',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          if (auth.user?.email != null)
                            Text(
                              auth.user!.email,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (auth.role != null)
                            Text(
                              auth.role!,
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text('Logout'),
                onTap: () {
                  Navigator.pop(ctx);
                  ref.read(authProvider.notifier).logout();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
