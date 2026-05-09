import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/app_state.dart';
import 'screens/index_screen.dart';
import 'screens/search_screen.dart';
import 'screens/stats_screen.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const SearchEngineApp(),
    ),
  );
}

class SearchEngineApp extends StatelessWidget {
  const SearchEngineApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mini Search Engine',
      debugShowCheckedModeBanner: false,
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const MainShell(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1565C0), // Deep blue seed
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      inputDecorationTheme: InputDecorationTheme(
        fillColor: colorScheme.surfaceContainerHighest.withOpacity(0.4),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final theme = Theme.of(context);
    final isWide = MediaQuery.of(context).size.width > 720;

    final screens = [
      const IndexScreen(),
      const SearchScreen(),
      const StatsScreen(),
    ];

    final navItems = [
      NavigationRailDestination(
        icon: const Icon(Icons.folder_open_outlined),
        selectedIcon: const Icon(Icons.folder_open),
        label: const Text('Index'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.search_outlined),
        selectedIcon: const Icon(Icons.search),
        label: const Text('Search'),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.bar_chart_outlined),
        selectedIcon: const Icon(Icons.bar_chart),
        label: const Text('Stats'),
      ),
    ];

    return Scaffold(
      body: Row(children: [
        // ── Navigation Rail ──────────────────────────────────────────────
        NavigationRail(
          extended: isWide,
          minExtendedWidth: 190,
          selectedIndex: state.currentTab.tabIndex,
          onDestinationSelected: (i) => state.navigate(AppTab.values[i]),
          leading: Padding(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
            child: isWide
                ? Column(children: [
                    Icon(Icons.manage_search_rounded,
                        size: 36, color: theme.colorScheme.primary),
                    const SizedBox(height: 4),
                    Text('Mini Search',
                        style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary)),
                    const SizedBox(height: 4),
                    Text('Engine',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ])
                : Icon(Icons.manage_search_rounded,
                    size: 30, color: theme.colorScheme.primary),
          ),
          destinations: navItems,
        ),
        const VerticalDivider(width: 1),

        // ── Main content ─────────────────────────────────────────────────
        Expanded(
          child: Container(
            color: theme.colorScheme.surface,
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: MediaQuery.of(context).size.height,
                ),
                child: screens[state.currentTab.tabIndex],
              ),
            ),
          ),
        ),
      ]),
    );
  }
}
