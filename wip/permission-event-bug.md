# Permission 이벤트 전달 버그 수정

> 2026-01-27 분석 완료

## 증상

- 대화가 길어지면 간헐적으로 메시지가 안 옴
- 툴이 노란색(진행 중) 상태에서 멈춤
- 앱 재시작해도 permission UI 안 뜸
- 재시작 후 history는 정상 로드됨

---

## 발견된 버그

### 버그 1: 대화 전환 시 permission_request 누락

**원인:**
```javascript
// estelle-pylon/src/index.js:1305-1313
const viewers = this.getSessionViewers(sessionId);
if (viewers.size > 0) {  // ← viewers 없으면 안 보냄!
  this.send({ ...message, to: Array.from(viewers) });
}
this.localServer?.broadcast(message);  // desktop만 받음
```

- 다른 대화로 전환 → `registerSessionViewer`에서 기존 대화 viewers 제거
- 기존 대화에서 `permission_request` 발생 → viewers 없어서 앱에 안 감
- `localServer.broadcast`는 실행되어 desktop만 받음

**영향:**
- 다른 대화 보다가 돌아오면 permission UI 안 뜸

---

### 버그 2: 대화 재진입 시 pendingEvent 복원 안 됨 (★ 더 심각)

**원인:**

Pylon - `conversation_select` 처리:
```javascript
// estelle-pylon/src/index.js:537-551
this.send({
  type: 'history_result',
  payload: {
    messages,
    hasActiveSession,
    workStartTime
    // pendingEvent 없음!
  }
});
```

App - `_handleHistoryResult`:
```dart
// claude_provider.dart:136-181
// pendingEvent 처리 로직 없음
```

**영향:**
- 앱 재시작해도 permission UI 안 뜸 → 영원히 멈춤

---

## 수정 계획

### 1단계: 버그 2 수정 (우선)

**Pylon 수정** - `estelle-pylon/src/index.js`

`conversation_select` 처리 부분 (522-555줄):
```javascript
// pendingEvent 가져오기
const pendingEvent = this.claudeManager.getPendingEvent(conversationId);

this.send({
  type: 'history_result',
  to: from.deviceId,
  payload: {
    // ... 기존 필드들
    pendingEvent  // 추가
  }
});
```

**App 수정** - `estelle-app/lib/state/providers/claude_provider.dart`

`_handleHistoryResult()` (136-181줄):
```dart
// 기존 처리 후...

// pendingEvent 복원
final pendingEvent = payload['pendingEvent'] as Map<String, dynamic>?;
if (pendingEvent != null) {
  _handleClaudeEvent(pendingEvent);
}
```

---

### 2단계: 버그 1 수정

**Pylon 수정** - `estelle-pylon/src/index.js`

`sendClaudeEvent()` (1305-1313줄):
```javascript
// 중요 이벤트는 viewers 없어도 broadcast
const importantEvents = ['permission_request', 'askQuestion'];
if (importantEvents.includes(event.type)) {
  this.send({
    ...message,
    broadcast: 'clients'  // 모든 클라이언트에게
  });
} else if (viewers.size > 0) {
  this.send({ ...message, to: Array.from(viewers) });
}
```

---

## 테스트 시나리오

### 버그 2 테스트
1. Edit 툴 사용하는 대화 시작
2. permission 뜨기 전에 앱 종료
3. 앱 재시작 → 해당 대화 선택
4. **기대:** permission UI가 떠야 함

### 버그 1 테스트
1. 대화 A에서 Claude 작업 시작
2. 대화 B로 전환
3. 대화 A에서 permission_request 발생
4. 대화 A로 돌아감
5. **기대:** permission UI가 떠야 함

---

## 관련 파일

- `estelle-pylon/src/index.js`
- `estelle-pylon/src/claudeManager.js`
- `estelle-app/lib/state/providers/claude_provider.dart`
