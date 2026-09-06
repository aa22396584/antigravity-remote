# Antigravity Remote Protocol Compatibility Specification

**Audit Revision**: `2026-09-06`  
**Client Version**: `1.0.0+1`  
**Host Target**: Google Antigravity / Jetski Remote Host Protocol  

---

## 1. 架構概述與通訊通道 (Architecture & Transport Channels)

Antigravity Remote 使用雙軌傳輸 (Dual-Transport) 架構：
1. **Cloud Relay (軌道 1)**：透過 Google Cloud `cloudcode-pa.googleapis.com` 閘道器轉發 RPC 與串流命令至目標桌面端，支援跨網路與嚴格 NAT 穿透。
2. **WebRTC P2P DataChannel (軌道 2)**：基於 `InitiateMeshSession` 協商 STUN/TURN 候選者，並以 NIST P-256 (secp256r1) 密鑰進行 Channel Binding 雙向挑戰回應握手，建立端到端低延遲資料通道。

---

## 2. API 端點規格 (API Endpoints & RPC Schemas)

### 2.1 Cloud Relay 閘道端點

| 方法 / Endpoint | 傳輸協定 | 外層格式 | 說明 |
|---|---|---|---|
| `POST /v1/ProxyCommand` | HTTPS POST | `application/json` (Base64 Payload) | 一元命令調用 (Unary RPC) |
| `POST /v1/StreamProxyCommand` | HTTPS POST (Chunked Stream) | NDJSON / Chunked Base64 | 串流事件接收 (Streaming RPC) |
| `POST /v1/InitiateMeshSession` | HTTPS POST | `application/json` | WebRTC Mesh 候選交換與 SDP 握手 |
| `GET /v1/PollMeshEvents` | HTTPS GET | `application/json` | 長輪詢非同步 ICE 候選與狀態變更 |

### 2.2 核心 RPC 路徑 (Service Methods)

| RPC 服務路徑 | 模式 | 描述 |
|---|---|---|
| `/exa.LanguageServerService/SendUserCascadeMessage` | Unary | 提交 Prompt 至 Cascade Agent 工作區 |
| `/exa.LanguageServerService/StreamCascadeReactiveUpdates` | Server Stream | 訂閱 Cascade Agent 思考過程、工具調用與審批狀態 |
| `/exa.LanguageServerService/RespondToUserApproval` | Unary | 對待審批的工具執行請求提交同意或拒絕回覆 |
| `/exa.LanguageServerService/CancelCascadeTask` | Unary | 中止正在運行中的 Cascade 任務 |
| `/exa.LanguageServerService/SendTerminalInput` | Unary | 向指定終端會話發送使用者輸入與按鍵 (Ctrl+C 等) |
| `/exa.LanguageServerService/StreamTerminalOutput` | Server Stream | 訂閱遠端終端輸出訊框 (ANSI / UTF-8 byte stream) |

---

## 3. WebRTC P2P 分幀與頻道多工規範 (Framing & Channel Multiplexing)

### 3.1 5-byte 前綴訊框格式

所有透過 WebRTC DataChannel 傳輸之二進位封包均遵循 5 位元組前綴格式：

```
+---------------+------------------------+------------------------------------+
| Flag (1 Byte) | Length (4 Bytes, BE)   | Payload (Variable Length Bytes)   |
+---------------+------------------------+------------------------------------+
```

- **Flag 0x00 (Control / Unary RPC)**: 一元請求與 Channel Binding 認證握手。
- **Flag 0x01 (Cascade Stream)**: Cascade 訊息、思考鏈與工具調用串流。
- **Flag 0x02 (Terminal Stream)**: 終端機即時輸出位元組串流。

### 3.2 認證狀態機與防禦閘門 (Fail-Closed Gate)

1. **`unauthenticated`**: 連線建立初始狀態。除 `Flag 0x00` 控制頻道之 `channel_binding_challenge` 之外，所有業務封包一律阻絕拋棄。
2. **`challengePending`**: 收到 Nonce 挑戰後，以本地 P-256 私鑰完成確定性 RFC 6979 簽名並送出，等待對端確認。
3. **`authenticated`**: 收到對端合法之 `channel_binding_ack` 且簽名驗證無誤後方放行業務資料流通。

---

## 4. 錯誤狀態碼映射與安全去識別化 (Error Codes & Diagnostics)

```
AUTH_TOKEN_EXPIRED      - 401 Unauthorized (不可自動重試)
AUTH_FORBIDDEN          - 403 Forbidden (無權限控制目標主機)
HOST_OFFLINE            - 遠端實體離線或失聯
OUTCOME_UNKNOWN         - 在途寫入 RPC 未獲得遠端 ACK 確認 (禁止盲目重試以防重複執行)
PROTOCOL_UNSUPPORTED    - 遠端協議版本不相容
```

所有本機診斷記錄與匯出報告皆強制遮蔽 `Bearer`、`ya29.` Token、密鑰與使用者私人對話，確保連線日誌可安全匯出用於支援診斷。
