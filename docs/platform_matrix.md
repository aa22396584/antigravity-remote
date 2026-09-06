# Antigravity Remote 平台能力矩陣 (Platform Capability Matrix)

**Audit Revision**: `2026-09-06`  
**規格標記**:  
- `[Verified]` 已在目標平台驗證並具備自動化/實機測試  
- `[Experimental]` 基礎代碼已實作，但部分原生外掛或依賴環境需進一步真機驗收  
- `[Unsupported]` 平台不支援，已提供手動替代入口或停用保護  

---

## 1. 跨平台功能支援矩陣 (OS × Feature Matrix)

| 功能模組 | Android | iOS | macOS | Windows | Linux | Web |
|---|---|---|---|---|---|---|
| **響應式 UI / Cyber 主題** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` |
| **Cloud Relay (HTTPS/WSS)** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Experimental]` (受限 CORS) |
| **WebRTC P2P DataChannel** | `[Verified]` | `[Verified]` | `[Verified]` | `[Experimental]` | `[Experimental]` | `[Experimental]` |
| **ECDSA P-256 (純 Dart)** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` |
| **相機掃碼 (mobile_scanner)** | `[Verified]` | `[Verified]` | `[Verified]` | `[Unsupported]` (手動輸入替代) | `[Unsupported]` (手動輸入替代) | `[Experimental]` |
| **手動配對 / ID 輸入** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` |
| **Deep Link 自動切換** | `[Verified]` | `[Verified]` | `[Verified]` | `[Experimental]` | `[Unsupported]` | `[Experimental]` |
| **安全憑證加密儲存** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Experimental]` (Local Storage) |
| **終端 CJK/Emoji UTF-8 解碼** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` |
| **審批 Diff 高亮與命令複製** | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` | `[Verified]` |

---

## 2. 平台特定設定說明

### 2.1 Android (minSdk 24, targetSdk 34)
- **相機權限**: `android.permission.CAMERA` 設置為可選硬體特徵 (`android.hardware.camera.any`)，無相機設備仍可安裝並使用手動配對。
- **Release 簽名**: 讀取根目錄 `key.properties` 進行安全簽名，未配置時不再假借 debug 簽名交付。

### 2.2 macOS / iOS
- **Entitlements**: 配置 `com.apple.security.network.client` 與 `com.apple.security.network.server`，支援本機 STUN/TURN 與 Relay 流量。
- **Info.plist**: 宣告 `NSCameraUsageDescription` 用於 QR 掃碼。

### 2.3 桌面端 (Windows / Linux)
- 在不支援原生相機掃描之環境下，App 提供醒目之「手動輸入配對網址或 ID」入口，禁止初始化未支援之相機外掛。
