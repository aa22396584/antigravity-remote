# Antigravity Remote (遠端控制中樞)

為 **Antigravity (Google Jetski)** 編輯器深度打造的跨平台原生控制應用程式（Native App，支援 iOS / Android / macOS）。

基於對 Antigravity 本機二進位執行檔（`language_server`）、Protobuf Schema（`devtools_jetski_boq_api_proto.ApiService` 與 `LanguageServerService`）、ConnectRPC 及 WebRTC P2P DataChannel 的深度逆向工程研發。

---

## 🌟 核心特色與架構亮點

### 1. 雙軌混合自適應傳輸架構 (Dual-Transport Architecture)
- **軌道 1 (Cloud Relay 模式，100% 可靠性保底)**：
  - 客戶端直接向 Google Cloud 閘道器（`https://cloudcode-pa.googleapis.com` 或 `daily-cloudcode-pa.googleapis.com`）發起 `ProxyCommand` (Unary) 與 `StreamProxyCommand` (Server Streaming)。
  - Google Cloud 透過桌面端主動出站維護的 `ConnectInstanceV2` 雙向長串流通道進行 RPC 轉發。
  - **使用者 Mac 桌面端無須公網 IP、無須路由器 Port Forwarding 或 DDNS**。
- **軌道 2 (WebRTC P2P DataChannel Mesh 模式，極致超低延遲)**：
  - 客戶端向雲端調用 `InitiateMeshSession`，並上報客戶端本地生成之 **NIST P-256 (secp256r1) ECDSA 公鑰**（DER / SPKI 格式）。
  - 雲端下發 STUN (`stun:stun.l.google.com:19302`) 與 TURN 伺服器配置。
  - 透過 `SendSignalingMessage` 與 `PollSignalingMessages` 交換 SDP Offer/Answer 與 ICE Candidates。
  - 連通後桌面端發送 **Channel Binding Nonce 挑戰**，客戶端透過 ECDSA P-256 私鑰簽章驗證回應。
  - 升級至 P2P 直連通道，端到端延遲降至 **< 20ms**！
- **5 位元組資料分幀標準 (DataChannel Framing)**：
  - `[1 byte Compression Flag: 0x00] [4 bytes Big-Endian Length: uint32] [Payload bytes]`

### 2. 核心功能集
- 📸 **QR Code 一鍵掃碼綁定**：
  - 整合 `mobile_scanner`，支援解析 Antigravity 官方生成的 Google AccountChooser 格式：
    `https://accounts.google.com/AccountChooser?Email={email}&continue=https%3A%2F%2Fantigravity.google.com%2Fr%2F{instanceId}`
  - 支援 `antigravity://remote/{instanceId}`、JSON 設定及直接輸入 UUID。
- 🧠 **Cascade 思考過程即時動態串流渲染**：
  - 擬真神經網絡脈衝動畫，即時呈現 Agent 內部思維推理過程 (`ThinkingCard`)。
  - 可折疊式面板，思考中自動展開，完成後顯示精準耗時（例如：`思考完畢 (耗時 2.4s)`）。
- 🛠️ **Trajectory 工具執行進度卡片**：
  - 視覺化卡片呈現 `run_command`、`replace_file_content`、`write_to_file`、`read_file`、`grep_search` 等工具調用狀態。
  - 支援語法著色之代碼變更對照 (`CodeDiffViewer`)。
- 🛡️ **指令安全審批互動系統 (Interactive Approvals)**：
  - 當 Agent 進入 `WAITING_USER_INTERACTION` 狀態時，自動觸發高亮提示橫幅與審批彈窗。
  - 支援潛在破壞性指令警告標誌（針對 `rm`、`sudo`、`git reset --hard` 等）。
  - 一鍵「核准執行 (Approve)」或「拒絕 (Reject)」，並可附加補充指示。
- 💻 **即時終端輸出監控 (Live Terminal)**：
  - 即時串流監看本機終端輸出日誌 (`StreamTerminalOutput`)。
  - 內建常用快捷鍵（`Ctrl+C`、`Enter`、`Tab`、`clear`）與遠端終端按鍵輸入發送 (`SendTerminalInput`)。
- 🧪 **離線展示與測試模式 (Demo Mode)**：
  - 內建高保真度模擬器 (`MockAntigravityService`)，在未連接真實 Mac 桌面端時亦能即時體驗完整思考、審批、終端與雙軌切換互動。

---

## 🎨 UI/UX 設計理念 (Cyber-Command Deck)

本專案遵循頂級前端設計規範，摒棄單調平庸的通用 AI 模板：
- **配色**：深空石墨曜石黑 (`#080C14` / `#0F172A`)、雷射青 (`#00E5FF`)、翡翠綠 (`#00E676`)、警示琥珀 (`#FFB300`)、霓虹洋紅 (`#FF3366`) 與神經紫羅蘭 (`#A855F7`)。
- **字體**：字體排版採用 Google Fonts 的 **JetBrains Mono**（代碼、UUID、終端輸出）與 **Outfit / Plus Jakarta Sans**（標題與介面層級）。
- **微互動**：雙軌連線狀態指示燈 (`StatusIndicator`)、即時 Ping 延遲計量儀 (`TransportBadge`)、雷射掃描動畫視窗。
- **自適應排版**：
  - 手機端：底部導航列 (`工作區`、`終端輸出`、`設備中樞`)。
  - 平板 / 桌面端 (macOS)：左側 NavigationRail + Split Panel 主從工作流排版。

---

## 📂 專案架構目錄

```
lib/
├── main.dart                               # 應用程式進入點與 ProviderScope 注入
├── app.dart                                # 頂層 MaterialApp、深色主題與自適應導航
├── core/
│   ├── theme/
│   │   └── app_theme.dart                  # CyberColors、深色主題樣式與字型設定
│   ├── network/
│   │   ├── endpoints.dart                  # Google Cloud 端點與 RPC 路徑常數
│   │   ├── transport_interface.dart        # 雙軌傳輸抽象介面 (TransportClient)
│   │   ├── cloud_relay_client.dart         # Google Cloud ProxyCommand / StreamProxyCommand 實作
│   │   ├── webrtc_mesh_client.dart         # WebRTC DataChannel + ECDSA P-256 挑戰握手實作
│   │   └── dual_transport_manager.dart     # 雙軌自適應調度器 (P2P 優先，自動 Fallback Relay)
│   ├── models/
│   │   ├── instance_info.dart              # 設備實例資訊、狀態與延遲
│   │   ├── cascade_message.dart            # Cascade 對話訊息與思考狀態
│   │   ├── trajectory_step.dart            # Agent 軌跡步驟與工具調用
│   │   ├── user_interaction.dart           # 審批授權請求與回應
│   │   └── terminal_stream.dart            # 終端輸出資料流區塊
│   └── services/
│       ├── qr_parser_service.dart          # QR Code 與 deep link URL 解析服務
│       ├── storage_service.dart            # 本地持久化 (憑證、端點、已配對設備)
│       └── mock_antigravity_service.dart   # 高保真度離線模擬伺服器
├── features/
│   ├── device/
│   │   ├── providers/device_provider.dart  # 設備配對與連線狀態管理 (Riverpod 3)
│   │   ├── views/
│   │   │   ├── device_list_view.dart       # 設備列表與快速連線中心
│   │   │   ├── qr_scanner_view.dart        # 相機 QR 掃碼視窗與手動輸入
│   │   │   └── connection_settings_view.dart# 雲端環境與 OAuth Bearer Token 設定
│   │   └── widgets/
│   │       ├── device_card.dart            # 設備資訊與狀態卡片
│   │       └── transport_badge.dart        # 雙軌連線即時指示徽章 (P2P vs Relay)
│   ├── cascade/
│   │   ├── providers/cascade_provider.dart # 對話、思考串流與審批佇列狀態
│   │   ├── views/cascade_chat_view.dart    # Agent 串流對話主畫面
│   │   └── widgets/
│   │       ├── thinking_card.dart          # 可折疊式神經網絡思考卡片
│   │       ├── trajectory_step_card.dart   # 工具執行與行內審批卡片
│   │       ├── code_diff_viewer.dart       # 代碼變更 Diff 檢視器
│   │       ├── user_approval_dialog.dart   # 原生授權審批對話框
│   │       └── chat_input_bar.dart         # Prompt 輸入列與快捷指令
│   └── terminal/
│       ├── providers/terminal_provider.dart# 終端輸出資料流與輸入管理
│       ├── views/terminal_monitor_view.dart# 即時終端全螢幕控制台
│       └── widgets/terminal_console_card.dart# ANSI 終端控制台與按鍵快捷晶片
└── shared/
    └── widgets/
        ├── cyber_button.dart               # 霓虹線框與實心科技按鈕
        ├── cyber_card.dart                 # 磨砂半透明玻璃卡片
        └── status_indicator.dart           # 動態脈衝狀態指示燈
```

---

## 🚀 測試與驗證

本專案具備完整的自動化測試套件，涵蓋模型序列化、協定分幀、QR Code 解析、傳輸調度及 UI Widget：

```bash
# 執行所有單元測試與 Widget 整合測試
flutter test

# 程式碼靜態分析
flutter analyze
```

---

## 📱 本機配對操作說明

1. 在 Mac 上啟動 Antigravity 編輯器。
2. 前往 **Settings** -> 搜尋 **Remote Control**。
3. 開啟 **Enable Remote Control** 開關。
4. 點擊螢幕上顯示的 QR Code，或複製連結。
5. 在手機或平板端開啟 **Antigravity Remote**，點擊「掃描 QR 配對」或貼上連結，即可秒速連線並全面遠端操控桌面端 Agent！
