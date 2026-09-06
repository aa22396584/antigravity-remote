import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';
import '../providers/device_provider.dart';

class ConnectionSettingsView extends ConsumerStatefulWidget {
  const ConnectionSettingsView({super.key});

  @override
  ConsumerState<ConnectionSettingsView> createState() => _ConnectionSettingsViewState();
}

class _ConnectionSettingsViewState extends ConsumerState<ConnectionSettingsView> {
  late TextEditingController _tokenController;

  @override
  void initState() {
    super.initState();
    final currentToken = ref.read(deviceProvider).accessToken ?? '';
    _tokenController = TextEditingController(text: currentToken);
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final deviceState = ref.watch(deviceProvider);
    final deviceNotifier = ref.read(deviceProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('連線與雲端設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Demo Mode Switch
          CyberCard(
            borderColor: deviceState.isDemoMode ? CyberColors.emerald : CyberColors.subtleBorder,
            hasGlow: deviceState.isDemoMode,
            glowColor: CyberColors.emeraldGlow,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: CyberColors.emerald.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.science, color: CyberColors.emerald, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '離線展示與測試模式 (Demo Mode)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: CyberColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '在未連接真實 Mac 桌面端時，模擬完整 Agent 思考、審批與終端互動',
                        style: TextStyle(
                          fontSize: 12,
                          color: CyberColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: deviceState.isDemoMode,
                  activeThumbColor: CyberColors.emerald,
                  onChanged: (val) => deviceNotifier.toggleDemoMode(val),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 2. Cloud Endpoint Environment
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.cloud_sync, size: 18, color: CyberColors.cyan),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google Cloud 端點伺服器',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final env in CloudEnvironment.values) ...[
                  InkWell(
                    onTap: () => deviceNotifier.setEnvironment(env),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: deviceState.environment == env
                            ? CyberColors.cyan.withOpacity(0.12)
                            : CyberColors.surfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: deviceState.environment == env
                              ? CyberColors.cyan
                              : CyberColors.subtleBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            deviceState.environment == env
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: deviceState.environment == env
                                ? CyberColors.cyan
                                : CyberColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  env.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: deviceState.environment == env
                                        ? Colors.white
                                        : CyberColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  env.url,
                                  style: AppTheme.codeFont(
                                    color: CyberColors.textMuted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 3. OAuth Bearer Token
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.key, size: 18, color: CyberColors.amber),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Google OAuth2 Access Token (Bearer)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  '直接向 Google Cloud codecode-pa 閘道器認證。支援 Bearer Token 或 Google 登入憑證。',
                  style: TextStyle(fontSize: 12.5, color: CyberColors.textSecondary),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  style: AppTheme.codeFont(color: CyberColors.textCode, fontSize: 12),
                  maxLines: 2,
                  decoration: const InputDecoration(
                    hintText: 'ya29.a0AfH6SM...',
                  ),
                  onChanged: (val) => deviceNotifier.setAccessToken(val.trim()),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    CyberButton(
                      text: '生成測試 Token',
                      isOutlined: true,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      onPressed: () {
                        final mockToken = 'mock-oauth-ya29.${DateTime.now().millisecondsSinceEpoch}';
                        _tokenController.text = mockToken;
                        deviceNotifier.setAccessToken(mockToken);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Transport Protocol Telemetry
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.hub, size: 18, color: CyberColors.violet),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '雙軌傳輸規格說明 (Dual-Transport Architecture)',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: CyberColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                const Text(
                  '• 軌道 1 (Cloud Relay)：調用 ProxyCommand / StreamProxyCommand，由 Google Cloud 轉發至桌面端，100% 穿透任何防火牆。\n'
                  '• 軌道 2 (WebRTC P2P DataChannel)：基於 InitiateMeshSession、STUN/TURN、ECDSA P-256 挑戰回應，端到端超低延遲 (<20ms)。\n'
                  '• 資料分幀：5 位元組長度前綴 [0x00][Length][Payload]。',
                  style: TextStyle(fontSize: 12.5, color: CyberColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
