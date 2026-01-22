# 선택적 이벤트 라우팅

## 상태: COMPLETED

## 배경
현재 모든 claude_event가 모든 클라이언트에 브로드캐스트됨.
→ 불필요한 트래픽 (스트리밍 텍스트, tool output 등)

## 변경 내용

### 이벤트 분류

| 이벤트 | 전송 방식 | 이유 |
|--------|----------|------|
| `desk_status` | broadcast | 사이드바에서 모든 데스크 상태 표시 |
| `desk_list_result` | broadcast | 데스크 목록 동기화 |
| `claude_event` | **선택한 클라이언트만** | 트래픽 최적화 |
| `message_history` | 요청한 클라이언트만 | 이미 to 필드 사용 중 |

### 구현 완료

#### 1. Pylon 수정 (`estelle-pylon/src/index.js`)
- `deskViewers` Map 추가: `Map<deskId, Set<clientDeviceId>>`
- `desk_select` 메시지 핸들러 추가
- `registerDeskViewer()`, `unregisterDeskViewer()`, `getDeskViewers()` 메서드 추가
- `sendClaudeEvent()` 수정: `broadcast: 'clients'` → `to: [deviceIds]` 배열 전송
- `client_disconnect` 핸들러 추가

#### 2. Relay 수정 (`estelle-relay/src/index.js`)
- 클라이언트 연결 해제 시 Pylon에 `client_disconnect` 알림 전송
- `to` 필드 배열 지원 추가: `to: [105, 106]` 또는 `to: [{ deviceId: 105 }, ...]`

#### 3. Flutter 클라이언트 수정
- `relay_service.dart`: `selectDesk()` 메서드 추가
- `claude_provider.dart`: 데스크 선택 시 `selectDesk()` 호출

### 메시지 형식

```json
// 클라이언트 → Pylon
{
  "type": "desk_select",
  "to": { "deviceId": 1, "deviceType": "pylon" },
  "payload": { "deskId": "xxx" }
}

// Pylon → 시청 중인 클라이언트들 (배열)
{
  "type": "claude_event",
  "to": [105, 106, 107],
  "payload": { "deskId": "xxx", "event": { ... } }
}

// Relay → Pylon (클라이언트 연결 해제 시)
{
  "type": "client_disconnect",
  "payload": { "deviceId": 105, "deviceType": "desktop" }
}
```

### 고려사항
- 클라이언트 연결 해제 시 deskViewers에서 자동 제거 ✓
- 한 클라이언트가 여러 데스크를 볼 수 있는가? → 현재는 1개만 (새 선택 시 이전 제거)
- 로컬 서버는 그대로 브로드캐스트 유지 (보통 1개 연결)

---
작성일: 2026-01-22
완료일: 2026-01-22
