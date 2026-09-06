# 更新日誌 (Changelog)

所有關於 **Antigravity Remote** 的顯著變更均記錄於此文件中。
本專案遵循 [Semantic Versioning](https://semver.org/lang/zh-TW/) 規範。

---

## [1.1.0] - 2026-09-06

### 🚀 版本總覽 (Release Overview)

本次 **v1.1.0** 是一次具有里程碑意義的重大架構與可靠性升級。本版本全面落實了 **2026-09 全面功能／UIUX／實際使用稽核（涵蓋 34 項專案 Issues 規範）**，徹底重構了底層通訊狀態機、安全握手協議、審批防護、終端解碼與響應式互動佈局。

全套專案通過 **158 項全自動化單元與 Widget 整合測試**，並在 `flutter analyze` 與 `dart format` 下達到 **0 警告、0 錯誤、100% 格式規範**。

---

### 🛡️ 5 大 P0 核心安全與控制可靠性防禦 (P0 Security & Control Reliability)

1. **修正切換／刪除裝置後控制目標不一致與舊連線殘留 (Issue #1)**
   - 實作原子清理流程與目標實體 Factory 依賴注入機制。
   - 切換主機或刪除裝置時，立即中斷舊有的雙軌傳輸、撤銷正在進行中的連線輪詢、重置對話上下文、清除待審批隊列與終端日誌緩衝，杜絕指令誤發往非目標主機的潛在風險。

2. **WebRTC DataChannel RequestID 關聯映射與跨串流隔離 (Issue #2)**
   - 終結過去 FIFO 盲目配對的架構缺陷，為所有 P2P 一元 RPC 請求加入唯一遞增的 `requestId`。
   - 建立 `0x00` 控制頻道、`0x01` Cascade 思考串流與 `0x02` 終端輸出串流的實體多工隔離，將底層 ConnectRPC 狀態碼嚴格映射至 `RpcException`。

3. **禁止非冪等在途寫入 RPC 於 P2P→Relay 間盲目重送 (Issue #3)**
   - 嚴格區分 `PreFlightException`（握手或連線前失敗，允許安全回退）與 `InFlightRpcException`（指令已送出但未獲 ACK）。
   - 針對破壞性非冪等寫入操作（如終端指令執行、文件覆寫）實施防重複重發閘門，防止網路抖動造成多次扣動扳機。

4. **審批操作等待遠端 200 OK 確認與失敗狀態保留 (Issue #4)**
   - 審批請求改為非同步防抖並等待遠端伺服器返回成功確認。
   - 遠端處理失敗或超時時，完整保留待審批狀態與步驟資訊，禁止介面樂觀假成功；加入防連點併發互斥保護。

5. **WebRTC P2P 握手 Fail-Closed 狀態機安全閘門 (Issue #10)**
   - 嚴格實施「預設阻絕 (Fail-Closed)」握手狀態機 (`unauthenticated` -> `challengePending` -> `authenticated`)。
   - 在未收到桌面端合法的 `channel_binding_ack` 且通過純 Dart NIST P-256 挑戰簽名之前，全面封鎖所有業務封包與敏感指令。

---

### 🎨 P1 / P2 UI/UX 與終端人機工程體驗升級 (UI/UX & Terminal Experience)

1. **聊天輸入與交付狀態追蹤 (Issue #19, #20)**
   - 引入 `MessageDeliveryStatus` 完整生命週期追蹤（發送中、已送達、發送失敗）。
   - 發送失敗時提供原位重試與一鍵草稿還原快照（Draft Snapshot）。
   - 串流思考期間智慧停用 Quick Chips，並在已有文字時採追加而非覆寫。
   - 支援桌面端 Enter 直接送出與 Shift+Enter 換行。

2. **智慧串流跟隨與閱讀手勢 (Smart Auto-Scroll)**
   - 實作無干擾智慧捲動手勢：使用者手動向上滑動檢視歷史記錄時，自動解鎖捲動鎖定，不再強制將畫面拽到底部。
   - 畫面右下角浮動顯示「回到即時 ⇣」按鈕，點擊立即平滑回航最新串流輸出。

3. **800dp 響應式佈局與桌面狀態保留 (Issue #21, #22, #26)**
   - 導入大螢幕 `NavigationRail` 與小螢幕 `CyberNavigationBar` 自適應切換。
   - 採用 `IndexedStack` 與持久狀態容器，保證在標籤切換或視窗縮放時不丟失輸入草稿、終端機輸出緩衝與捲動位置。
   - 支援桌面全域快捷鍵 (`Cmd/Ctrl + 1/2/3`) 瞬時切換模組。

4. **終端機 UTF-8 多位元組解碼與長時效能防護 (Issue #23, #24)**
   - 實作 `Utf8ChunkDecoder`，徹底解決中文 (3-byte) 與 Emoji (4-byte) 跨分包傳輸造成的破字亂碼。
   - 分離 `sendRaw`（如 `Ctrl+C` 發送 `\x03` 不帶換行）與 `sendInput`，避免終端出現非預期的雙重回顯。
   - 終端日誌配置 1000 訊框有界環形緩衝區（Ring Buffer），超限時自動尾部修剪並呈現截斷提示，杜絕長時運行記憶體洩漏。
   - 所有虛擬按鍵均滿足最小 `44x44` 點擊熱區規範並附帶 Tooltip 輔助說明。

5. **審批 Diff 語法著色與一鍵複製 (Issue #27)**
   - 內建 `CodeDiffViewer`，即時解析 unified diff hunk，提供新舊行號、代碼增刪著色高亮。
   - 支援複製完整 Diff、複製變更內容等一鍵操作；審批對話框呈現單行等寬命令與醒目高危標籤。

6. **斷線指數退避自動重連與任務取消 (Issue #25)**
   - `DualTransportManager` 實裝 1s 至 30s 隨機抖動指數退避重連機制。
   - 支援調用 `CancelCascadeTask`，可隨時自行動端遠程中止桌面端進行中的長時間任務。

---

### 🔐 儲存降級、憑證安全與真實延遲量測 (Storage Fallback & Security)

1. **儲存降級優雅運行橫幅 (Issue #32)**
   - 當底層安全儲存或 SharedPreferences 初始化異常時，無縫降級至記憶體快取模式，並於頂部彈出儲存降級警示橫幅，確保 App 永不崩潰白屏。

2. **憑證安全遮蔽與診斷日誌脫敏 (Issue #14, #31, #32)**
   - 系統診斷匯出全面過濾遮蔽 `Bearer`、`ya29.` OAuth Token、金鑰與私人對話，日誌安全合規。
   - 裝置憑證清除 (Token Purge) 流程強化，登出時確保本地密鑰完全抹除。

3. **移除假連線與真實延遲量測 (Issue #6, #7)**
   - 徹底移除過去硬編碼之假延遲（28ms）與模擬灌水邏輯。
   - 實作真實網路 RTT 延遲探測，嚴格隔離 Demo 離線模擬與 Live 真實環境。

4. **Deep Link 預覽防釣魚與嚴格 QR 解析 (Issue #16, #17, #18)**
   - 修復單引號 JSON 解析例外，加入釣魚網域與外部跳轉遞迴深度上限檢查。
   - 接收到外部 Deep Link 喚醒時，彈出預覽確認對話框，經使用者授權後方可切換目標裝置。

5. **NIST P-256 純 Dart DER 嚴格解碼 (Issue #30)**
   - 嚴格校驗 SPKI / DER ASN.1 結構與 P-256 跨實作金鑰向量，避免接受畸形簽名。

---

### 🧪 自動化測試與工程質量指標 (Verification Record)

- ✅ **全套自動化測試**：`158 passed` (0 failed, 0 skipped)。
- ✅ **靜態代碼分析**：`flutter analyze` -> `No issues found!`。
- ✅ **代碼格式規範**：`dart format --set-exit-if-changed .` -> `0 changed`。
- ✅ **Android 生產打包**：`flutter build apk --release` -> 112.8MB 生產級 APK。
- ✅ **平台能力支援**：參見 [平台能力矩陣](docs/platform_matrix.md) 與 [協議相容性規格](docs/protocol/compatibility.md)。
