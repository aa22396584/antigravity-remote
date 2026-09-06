import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/cascade/views/cascade_chat_view.dart';
import 'features/device/views/device_list_view.dart';
import 'features/terminal/views/terminal_monitor_view.dart';

class AntigravityRemoteApp extends ConsumerStatefulWidget {
  const AntigravityRemoteApp({super.key});

  @override
  ConsumerState<AntigravityRemoteApp> createState() => _AntigravityRemoteAppState();
}

class _AntigravityRemoteAppState extends ConsumerState<AntigravityRemoteApp> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Antigravity Remote',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: Builder(
        builder: (context) {
          final isWide = MediaQuery.of(context).size.width >= 800;

          final pages = [
            CascadeChatView(
              onOpenTerminal: () => setState(() => _currentIndex = 1),
            ),
            const TerminalMonitorView(),
            DeviceListView(
              onOpenChat: () => setState(() => _currentIndex = 0),
            ),
          ];

          if (isWide) {
            // Desktop / Tablet Master-Detail Navigation Rail
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: _currentIndex,
                    backgroundColor: CyberColors.surface,
                    indicatorColor: CyberColors.cyan.withOpacity(0.2),
                    selectedIconTheme: const IconThemeData(color: CyberColors.cyan),
                    unselectedIconTheme: const IconThemeData(color: CyberColors.textMuted),
                    selectedLabelTextStyle: const TextStyle(
                      color: CyberColors.cyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    unselectedLabelTextStyle: const TextStyle(
                      color: CyberColors.textMuted,
                      fontSize: 12,
                    ),
                    leading: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: CyberColors.cyan.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: CyberColors.cyan.withOpacity(0.5)),
                        ),
                        child: const Icon(Icons.hub, color: CyberColors.cyan, size: 24),
                      ),
                    ),
                    onDestinationSelected: (index) {
                      setState(() => _currentIndex = index);
                    },
                    labelType: NavigationRailLabelType.all,
                    destinations: const [
                      NavigationRailDestination(
                        icon: Icon(Icons.chat_bubble_outline),
                        selectedIcon: Icon(Icons.chat_bubble),
                        label: Text('工作區'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.terminal_outlined),
                        selectedIcon: Icon(Icons.terminal),
                        label: Text('終端輸出'),
                      ),
                      NavigationRailDestination(
                        icon: Icon(Icons.devices_outlined),
                        selectedIcon: Icon(Icons.devices),
                        label: Text('設備中樞'),
                      ),
                    ],
                  ),
                  const VerticalDivider(width: 1, color: CyberColors.subtleBorder),
                  Expanded(child: pages[_currentIndex]),
                ],
              ),
            );
          }

          // Mobile Bottom Navigation Bar
          return Scaffold(
            body: IndexedStack(
              index: _currentIndex,
              children: pages,
            ),
            bottomNavigationBar: Container(
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: CyberColors.subtleBorder, width: 1),
                ),
              ),
              child: NavigationBar(
                selectedIndex: _currentIndex,
                backgroundColor: CyberColors.surface,
                indicatorColor: CyberColors.cyan.withOpacity(0.2),
                height: 64,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                },
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.chat_bubble_outline, color: CyberColors.textMuted),
                    selectedIcon: Icon(Icons.chat_bubble, color: CyberColors.cyan),
                    label: '工作區',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.terminal_outlined, color: CyberColors.textMuted),
                    selectedIcon: Icon(Icons.terminal, color: CyberColors.cyan),
                    label: '終端輸出',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.devices_outlined, color: CyberColors.textMuted),
                    selectedIcon: Icon(Icons.devices, color: CyberColors.cyan),
                    label: '設備中樞',
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
