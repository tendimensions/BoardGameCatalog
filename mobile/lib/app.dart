import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'providers/collection_provider.dart';
import 'screens/collection_screen.dart';
import 'screens/scanner_screen.dart';
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
  int _selectedIndex = 1;

  static const _tabs = [
    ScannerScreen(),
    CollectionScreen(),
    SettingsScreen(),
  ];

  static const _labels = ['Scan', 'Collection', 'Settings'];
  static const _icons = [
    Icons.qr_code_scanner,
    Icons.casino_outlined,
    Icons.settings_outlined,
  ];

  @override
  void initState() {
    super.initState();
    // Restore session on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthProvider>().initialize();
    });
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: const Color(0xFF1a1a2e),
        indicatorColor: const Color(0xFF7eb8f7).withAlpha(50),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: List.generate(
          _tabs.length,
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
