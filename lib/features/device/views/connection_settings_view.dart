import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/endpoints.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';
import '../providers/device_provider.dart';

class ConnectionSettingsView extends ConsumerStatefulWidget {
  const ConnectionSettingsView({super.key});

  @override
  ConsumerState<ConnectionSettingsView> createState() =>
      _ConnectionSettingsViewState();
}

class _ConnectionSettingsViewState
    extends ConsumerState<ConnectionSettingsView> {
  late TextEditingController _tokenController;
  late String _tokenDraft;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    final currentToken = ref.read(deviceProvider).accessToken ?? '';
    _tokenController = TextEditingController(text: currentToken);
    _tokenDraft = currentToken;
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
      appBar: AppBar(title: const Text('連線與雲端設定')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Storage Degraded Banner (Issue #32)
          if (deviceState.bootState == BootState.degraded)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: CyberColors.amber.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: CyberColors.amber.withOpacity(0.4)),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: CyberColors.amber,
                    size: 18,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '儲存系統降級：安全憑證儲存初始化失敗，目前以記憶體模式運行，設定將不會持久化保存。',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: CyberColors.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // 1. Demo Mode Switch
          CyberCard(
            borderColor: deviceState.isDemoMode
                ? CyberColors.emerald
                : CyberColors.subtleBorder,
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
                  child: const Icon(
                    Icons.science,
                    color: CyberColors.emerald,
                    size: 22,
                  ),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
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
                  '向 Google Cloud 閘道器認證。支援 Bearer Token 或手動匯入憑證。',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CyberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tokenController,
                  obscureText: _obscureToken,
                  maxLines: 1,
                  enableSuggestions: false,
                  autocorrect: false,
                  style: AppTheme.codeFont(
                    color: CyberColors.textCode,
                    fontSize: 12,
                  ),
                  decoration: InputDecoration(
                    hintText: 'ya29.a0AfH6SM...',
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureToken ? Icons.visibility_off : Icons.visibility,
                        color: CyberColors.textSecondary,
                        size: 20,
                      ),
                      onPressed: () =>
                          setState(() => _obscureToken = !_obscureToken),
                      tooltip: _obscureToken ? '顯示憑證' : '隱藏憑證',
                    ),
                  ),
                  onChanged: (val) => setState(() => _tokenDraft = val.trim()),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (deviceState.accessToken != null &&
                        deviceState.accessToken!.isNotEmpty)
                      CyberButton(
                        text: '清除憑證 / 登出',
                        isOutlined: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onPressed: () async {
                          await deviceNotifier.logout();
                          _tokenController.clear();
                          setState(() => _tokenDraft = '');
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('已清除憑證並中斷連線'),
                                backgroundColor: CyberColors.surfaceElevated,
                              ),
                            );
                          }
                        },
                      ),
                    if (deviceState.isDemoMode)
                      CyberButton(
                        text: '生成測試 Token',
                        isOutlined: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        onPressed: () {
                          final mockToken =
                              'mock-oauth-ya29.${DateTime.now().millisecondsSinceEpoch}';
                          _tokenController.text = mockToken;
                          setState(() => _tokenDraft = mockToken);
                          deviceNotifier.setAccessToken(mockToken);
                        },
                      ),
                    CyberButton(
                      text: '儲存 Token',
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      onPressed: () async {
                        await deviceNotifier.setAccessToken(_tokenDraft);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).hideCurrentSnackBar();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('已安全儲存 OAuth Access Token'),
                              backgroundColor: CyberColors.surfaceElevated,
                            ),
                          );
                        }
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
                  '• 軌道 1 (Cloud Relay)：調用 ProxyCommand / StreamProxyCommand，由 Google Cloud 轉發至桌面端，適用於各類 NAT 與跨網段環境。\n'
                  '• 軌道 2 (WebRTC P2P DataChannel)：基於 InitiateMeshSession、STUN/TURN、ECDSA P-256 挑戰回應，直接建立端到端加密資料串流。\n'
                  '• 資料分幀：5 位元組長度前綴 [0x00][Length][Payload]。',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CyberColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 5. Diagnostics and Logs (Issue #32)
          CyberCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(
                      Icons.bug_report,
                      size: 18,
                      color: CyberColors.emerald,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '連線診斷與日誌 (Diagnostics)',
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
                  '匯出經安全去識別化與憑證遮蔽之連線診斷日誌，協助排除連線故障。',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: CyberColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                CyberButton(
                  text: '查看 / 複製診斷報告',
                  isOutlined: true,
                  icon: Icons.assignment_outlined,
                  onPressed: () {
                    final report = ref
                        .read(deviceProvider.notifier)
                        .exportDiagnosticReport();
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: CyberColors.surfaceElevated,
                        title: const Text('安全診斷日誌 (已去識別化)'),
                        content: SingleChildScrollView(
                          child: SelectableText(
                            report,
                            style: AppTheme.codeFont(
                              fontSize: 11,
                              color: CyberColors.textCode,
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: const Text('關閉'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
