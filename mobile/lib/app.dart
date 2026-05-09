import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/collection_provider.dart';
import 'providers/list_provider.dart';
import 'screens/collection_screen.dart';
import 'screens/lists_screen.dart';
import 'screens/scan_mode_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/setup_screen.dart';

class BoardGameCatalogApp extends StatelessWidget {
  const BoardGameCatalogApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CollectionProvider()),
        ChangeNotifierProvider(create: (_) => ListProvider()),
      ],
      child: MaterialApp(
        title: 'Board Game Catalog',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: const ColorScheme.dark(
            surface: Color(0xFF0f0f0f),
            primary: Color(0xFF7eb8f7),
            onSurface: Color(0xFFdddddd),
          ),
          scaffoldBackgroundColor: const Color(0xFF0f0f0f),
          useMaterial3: true,
        ),
        home: const _AppShell(),
      ),
    );
  }
}

class _AppShell extends StatefulWidget {
  const _AppShell();

  @override
  State<_AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<_AppShell> {
  // Index into _bodyTabs (Collection=0, Lists=1, Settings=2).
  // Scan is handled as a pushed route and never becomes the active body tab.
  int _bodyIndex = 0;

  // Navigation bar destinations: Collection(0), Lists(1), Scan(2), Settings(3).
  // Scan routes to a separate screen instead of switching the active body tab.
  static const _bodyTabs = [
    CollectionScreen(),
    ListsScreen(),
    SettingsScreen(),
  ];

  static const _labels = ['Collection', 'Lists', 'Scan', 'Settings'];
  static const _icons = [
    Icons.casino_outlined,
    Icons.list_alt_outlined,
    Icons.qr_code_scanner,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
  }

  void _onNavTap(int i) {
    if (i == 2) {
      // Scan tab — push the mode-selection screen as a route
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const ScanModeScreen()),
      );
    } else {
      setState(() => _bodyIndex = i > 2 ? i - 1 : i);
    }
  }

  int get _selectedNavIndex {
    return switch (_bodyIndex) {
      0 => 0,
      1 => 1,
      _ => 3,
    };
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Still loading stored key
    if (auth.state == AuthState.unknown) {
      return const Scaffold(
        backgroundColor: Color(0xFF0f0f0f),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF7eb8f7)),
        ),
      );
    }

    // No key saved — show setup
    if (!auth.isLoggedIn) {
      return const SetupScreen();
    }

    // Main app with bottom nav
    return Scaffold(
      backgroundColor: const Color(0xFF0f0f0f),
      body: IndexedStack(index: _bodyIndex, children: _bodyTabs),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1a1a2e),
        indicatorColor: const Color(0xFF7eb8f7).withAlpha(50),
        // Scan launches a route instead of becoming the active tab.
        selectedIndex: _selectedNavIndex,
        onDestinationSelected: _onNavTap,
        destinations: List.generate(
          _labels.length,
          (i) => NavigationDestination(
            icon: Icon(_icons[i], color: const Color(0xFF555555)),
            selectedIcon: Icon(_icons[i], color: const Color(0xFF7eb8f7)),
            label: _labels[i],
          ),
        ),
      ),
    );
  }
}
