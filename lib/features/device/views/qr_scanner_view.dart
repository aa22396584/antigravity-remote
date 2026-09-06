import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/services/qr_parser_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/cyber_button.dart';
import '../../../shared/widgets/cyber_card.dart';

class QrScannerView extends StatefulWidget {
  const QrScannerView({super.key});

  @override
  State<QrScannerView> createState() => _QrScannerViewState();
}

class _QrScannerViewState extends State<QrScannerView>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scannerController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late AnimationController _animController;
  late Animation<double> _scanLineAnimation;
  final TextEditingController _manualInputController = TextEditingController();
  bool _isProcessing = false;
  bool _isCommitting = false;
  bool _showManualDialog = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _scanLineAnimation = Tween<double>(begin: 0.05, end: 0.95).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _animController.dispose();
    _manualInputController.dispose();
    super.dispose();
  }

  Future<void> _commitTarget(ParsedRemoteTarget target) async {
    if (_isCommitting || !mounted) return;
    _isCommitting = true;
    _isProcessing = true;
    try {
      await _scannerController.stop();
    } catch (_) {}
    if (mounted) {
      Navigator.of(context).pop(target);
    }
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_isProcessing || _isCommitting || _showManualDialog) return;

    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.isNotEmpty) {
        final parsed = QrParserService.parse(rawValue);
        if (parsed != null) {
          _commitTarget(parsed);
          break;
        }
      }
    }
  }

  void _openManualDialog() {
    setState(() => _showManualDialog = true);
    try {
      _scannerController.stop();
    } catch (_) {}
  }

  void _closeManualDialog() {
    setState(() => _showManualDialog = false);
    if (!_isCommitting && !_isProcessing) {
      try {
        _scannerController.start();
      } catch (_) {}
    }
  }

  void _submitManual() {
    if (_isCommitting) return;
    final text = _manualInputController.text.trim();
    if (text.isEmpty) return;

    final parsed = QrParserService.parse(text);
    if (parsed != null) {
      _commitTarget(parsed);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('無法識別該連結或 Instance ID 格式'),
          backgroundColor: CyberColors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final scanBoxSize = screenWidth * 0.72;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('掃描 Antigravity 配對碼'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on, color: CyberColors.cyan),
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: '切換手電筒',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios, color: CyberColors.cyan),
            onPressed: () => _scannerController.switchCamera(),
            tooltip: '切換相機鏡頭',
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Live Camera Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _handleBarcode,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.videocam_off, size: 48, color: CyberColors.amber),
                      const SizedBox(height: 16),
                      Text(
                        '無法啟動相機 (相機已被佔用或無權限)',
                        style: TextStyle(color: CyberColors.textPrimary, fontSize: 16),
                      ),
                      const SizedBox(height: 12),
                      CyberButton(
                        text: '切換為手動輸入 ID',
                        onPressed: () => setState(() => _showManualDialog = true),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // 2. Viewfinder Overlay
          Center(
            child: SizedBox(
              width: scanBoxSize,
              height: scanBoxSize,
              child: Stack(
                children: [
                  // Corner brackets
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: CyberColors.cyan.withOpacity(0.4), width: 1.5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  // Animated Scanning Laser Line
                  AnimatedBuilder(
                    animation: _scanLineAnimation,
                    builder: (context, child) {
                      return Positioned(
                        top: scanBoxSize * _scanLineAnimation.value,
                        left: 10,
                        right: 10,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            color: CyberColors.cyan,
                            boxShadow: [
                              BoxShadow(
                                color: CyberColors.cyan.withOpacity(0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 3. Bottom Action Bar
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: CyberColors.subtleBorder),
                  ),
                  child: const Text(
                    '對準 Antigravity 設定頁面之 Remote Control QR Code',
                    style: TextStyle(color: CyberColors.textSecondary, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 14),
                CyberButton(
                  text: '手動輸入配對網址或 ID',
                  isOutlined: true,
                  icon: Icons.keyboard,
                  onPressed: _openManualDialog,
                ),
              ],
            ),
          ),

          // 4. Manual Input Modal
          if (_showManualDialog)
            Container(
              color: Colors.black87,
              padding: const EdgeInsets.all(24),
              child: Center(
                child: CyberCard(
                  borderColor: CyberColors.cyan,
                  hasGlow: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            '手動輸入配對資訊',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: CyberColors.textPrimary,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: CyberColors.textMuted),
                            onPressed: _closeManualDialog,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        '可輸入完整網址、antigravity:// 連結或 instanceId：',
                        style: TextStyle(fontSize: 13, color: CyberColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _manualInputController,
                        style: AppTheme.codeFont(color: CyberColors.cyan, fontSize: 13),
                        maxLines: 3,
                        decoration: const InputDecoration(
                          hintText: '例如: https://antigravity.google.com/r/2114863e-6436-4398-b26f-8672c1bd5e4b-v2',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _closeManualDialog,
                            child: const Text('取消', style: TextStyle(color: CyberColors.textMuted)),
                          ),
                          const SizedBox(width: 10),
                          CyberButton(
                            text: '確認綁定',
                            onPressed: _submitManual,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
