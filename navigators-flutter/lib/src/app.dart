import 'package:eden_platform_flutter/eden_platform.dart';
import 'package:eden_ui_flutter/eden_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'features/import/import_screen.dart';
import 'features/voters/voter_list_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

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

  Widget _buildHomeTab(AuthState auth) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigators'),
        actions: [
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
