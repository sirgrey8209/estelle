# 앱별 Unread 알림 관리

## 목표
Pylon에서 각 앱(클라이언트)별로 "unread 알림을 이미 보냈는지" 추적하여:
1. 불필요한 unread 중복 전송 방지
2. 앱이 대화에 진입하면 다시 알림 가능 상태로 리셋

---

## 현재 구조

### Pylon
```javascript
// sessionViewers: 대화별 시청 중인 앱 목록
sessionViewers = Map<conversationId, Set<clientDeviceId>>
```

- 앱이 대화 선택 → `registerSessionViewer(appId, conversationId)`
- 앱 연결 끊김 → `unregisterSessionViewer(appId)`
- 메시지 전송 시 → `getSessionViewers(conversationId)` 확인

---

## 추가할 구조

### Pylon에 추가: 앱별 unread 알림 전송 기록
```javascript
// appUnreadSent: 앱별로 이미 unread 알림을 보낸 대화 목록
appUnreadSent = Map<appId, Set<conversationId>>

// 예시
{
  'app-1': Set(['conv-xyz']),      // app-1에게 conv-xyz가 unread라고 알림 보냄
  'app-2': Set(['conv-abc', 'conv-xyz']),
}
```

---

## 이벤트 흐름

### 1. 앱 연결 시
```
앱 연결 → Pylon
  └─ appUnreadSent[appId] = 빈 Set
```

### 2. 앱이 대화 선택 시
```
앱에서 대화 선택 → Pylon (select_conversation)
  ├─ sessionViewers 업데이트 (기존 로직)
  ├─ 해당 대화의 unread 해제
  └─ appUnreadSent[appId]에서 해당 대화 제거  ← 다음에 안 보면 다시 알림 가능
```

### 3. Claude 이벤트 발생 시
```
Claude 이벤트 발생 (conversationId)
  │
  ├─ 보고 있는 앱 (sessionViewers에 있음)
  │   └─ 실시간 이벤트 전송 (claude_event)
  │
  └─ 안 보고 있는 앱 (sessionViewers에 없음)
      │
      ├─ appUnreadSent[appId]에 conversationId 있음
      │   └─ 아무것도 안 함 (이미 알림 보냄)
      │
      └─ appUnreadSent[appId]에 conversationId 없음
          ├─ unread 상태 전송 (conversation_status: unread)
          └─ appUnreadSent[appId]에 conversationId 추가
```

### 4. 앱 연결 해제 시
```
앱 연결 끊김 → Pylon (client_disconnect)
  ├─ sessionViewers에서 제거 (기존 로직)
  └─ appUnreadSent에서 앱 제거
```

---

## 상태 전이 (앱 관점)

```
[앱이 대화를 보고 있음]
        │
        │ [메시지 발생]
        ▼
   실시간 이벤트 수신
        │
        │ [다른 대화로 이동]
        ▼
[앱이 대화를 안 봄] + unreadSent에서 제거됨
        │
        │ [메시지 발생]
        ▼
   unread 알림 전송 + unreadSent에 추가
        │
        │ [또 메시지 발생]
        ▼
   아무것도 안 함 (이미 알림 보냄)
        │
        │ [다시 대화 선택]
        ▼
[앱이 대화를 보고 있음] + unreadSent에서 제거됨 (리셋)
```

---

## 구현 체크리스트

### Pylon
- [x] `appUnreadSent` Map 추가 (index.js)
- [x] 앱 연결 시 `appUnreadSent[appId] = new Set()` 초기화
- [x] 앱 연결 해제 시 `appUnreadSent.delete(appId)`
- [x] `select_conversation` 시 `appUnreadSent[appId].delete(conversationId)`
- [x] Claude 이벤트 전송 로직 수정:
  - 보고 있는 앱 → 실시간 전송
  - 안 보고 있는 앱 → unreadSent 확인 후 1회만 unread 전송

### 앱
- [x] (기존 로직 유지 - conversation_status 이벤트에서 unread 처리)

---

## 완료
- 2026-01-30 구현 완료
- 로그: `log/2026-01-30-status-dot-refactor.md`
