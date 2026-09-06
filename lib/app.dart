import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/services/deep_link_service.dart';
import 'core/services/qr_parser_service.dart';
import 'core/theme/app_theme.dart';
import 'features/cascade/providers/cascade_provider.dart';
import 'features/cascade/views/cascade_chat_view.dart';
import 'features/device/providers/device_provider.dart';
import 'features/device/views/device_list_view.dart';
import 'features/terminal/views/terminal_monitor_view.dart';

class AntigravityRemoteApp extends ConsumerStatefulWidget {
  const AntigravityRemoteApp({super.key});

  @override
  ConsumerState<AntigravityRemoteApp> createState() => _AntigravityRemoteAppState();
}

class _AntigravityRemoteAppState extends ConsumerState<AntigravityRemoteApp> {
  int _currentIndex = 0;
  final GlobalKey<ScaffoldMessengerState> _scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeepLinks();
    });
  }

  void _initDeepLinks() {
    final deepLinkService = ref.read(deepLinkServiceProvider);
    deepLinkService.init(onTargetReceived: _onDeepLinkTarget);
  }

  void _onDeepLinkTarget(ParsedRemoteTarget target) {
    // 1. 自動綁定 / 切換設備
    ref.read(deviceProvider.notifier).addDevice(
          instanceId: target.instanceId,
          name: target.email != null ? 'Antigravity (${target.email})' : null,
          hostname: target.hostname,
        );

    // 2. 若包含 Cascade ID，自動切換 Cascade
    if (target.cascadeId != null) {
      ref.read(cascadeProvider.notifier).switchCascade(target.cascadeId!);
    }

    // 3. 自動導航至「工作區」
    if (mounted) {
      setState(() {
        _currentIndex = 0;
      });

      final shortId = target.instanceId.length > 12
          ? '${target.instanceId.substring(0, 12)}...'
          : target.instanceId;

      _scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: CyberColors.emerald, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '已透過 Deep Link 自動連線設備: $shortId',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: CyberColors.surfaceElevated,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: CyberColors.emerald),
          ),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
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
            resizeToAvoidBottomInset: false,
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
