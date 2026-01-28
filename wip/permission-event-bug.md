# 메시지 동기화 버그 수정

> 2026-01-27 분석 시작, 2026-01-28 업데이트, 버그 3,4 수정

## 증상

- 대화가 길어지면 간헐적으로 메시지가 안 옴
- 툴이 노란색(진행 중) 상태에서 멈춤
- 앱 재시작해도 permission UI 안 뜸
- 재시작 후 history는 정상 로드됨

---

## 발견된 버그

### 버그 1: 대화 전환 시 이벤트 누락 (미수정)

**원인:**
```javascript
// estelle-pylon/src/index.js - sendClaudeEvent()
const viewers = this.getSessionViewers(sessionId);
if (viewers.size > 0) {  // ← viewers 없으면 안 보냄!
  this.send({ ...message, to: Array.from(viewers) });
}
this.localServer?.broadcast(message);  // desktop만 받음
```

- 다른 대화로 전환 → `registerSessionViewer`에서 기존 대화 viewers 제거
- 기존 대화에서 이벤트(result, state:idle 등) 발생 → viewers 없어서 앱에 안 감
- `localServer.broadcast`는 실행되어 desktop만 받음

**영향:**
- 다른 대화 보다가 돌아오면 상태가 여전히 working으로 표시됨

---

### 버그 2: 대화 재진입 시 pendingEvent 복원 안 됨 ✅ 수정됨

**커밋:** `848b659`

**수정 내용:**
- Pylon: `conversation_select` 처리 시 `pendingEvent` 전송 추가
- pendingEvent가 있으면 state:permission과 함께 전송

---

### 버그 3: 대화 재진입 시 상태 미복원 ✅ 수정됨

**원인:**
- 앱이 다른 대화 보는 중에 작업 완료됨 (result, state:idle)
- viewers 없어서 앱에 안 감 (버그 1)
- 다시 돌아옴 → history_result 받음
- `hasActiveSession: false` → **하지만 상태를 idle로 안 바꿈**

**수정:**
```dart
// estelle-app/lib/state/providers/claude_provider.dart - _handleHistoryResult()
if (hasActiveSession) {
  // working 상태 복원
} else {
  // 작업 완료 상태로 변경
  _ref.read(claudeStateProvider.notifier).state = 'idle';
  _ref.read(isThinkingProvider.notifier).state = false;
  _ref.read(workStartTimeProvider.notifier).state = null;
}
```

---

---

### 버그 4: pendingEvents 삭제 누락 ✅ 수정됨

**원인:**
```javascript
// estelle-pylon/src/claudeManager.js
stop(sessionId) {
  this.sessions.delete(sessionId);
  this.pendingPermissions.clear();
  this.pendingQuestions.clear();
  // ❌ pendingEvents 삭제 안 함!
}

// finally 블록도 마찬가지
finally {
  this.sessions.delete(sessionId);
  // ❌ pendingEvents 삭제 안 함!
}
```

- 세션 강제 종료 시 pendingEvents가 남아있음
- 대화 재진입 시 오래된 퍼미션 요청이 다시 표시됨

**수정:**
- `stop()`: `this.pendingEvents.delete(sessionId)` 추가
- `finally`: `this.pendingEvents.delete(sessionId)` 추가

---

## 수정 현황

| 버그 | 상태 | 비고 |
|------|------|------|
| 버그 1 | 미수정 | 근본적 해결 필요 |
| 버그 2 | ✅ 수정됨 | 커밋 848b659 |
| 버그 3 | ✅ 수정됨 | App 수정 |
| 버그 4 | ✅ 수정됨 | Pylon 수정 |

---

## 수정 계획

### 버그 1 수정 (추후)

**방안 1:** 중요 이벤트는 broadcast
```javascript
const importantEvents = ['permission_request', 'askQuestion', 'result', 'state'];
if (importantEvents.includes(event.type)) {
  this.send({ ...message, broadcast: 'clients' });
}
```

**방안 2:** viewers 없어도 마지막 시청자에게 전송

---

## 테스트 시나리오

### 버그 3 테스트
1. 대화 A에서 Claude 작업 시작
2. 대화 B로 전환
3. 대화 A에서 작업 완료 (result, state:idle)
4. 대화 A로 돌아감
5. **기대:** idle 상태, 작업 완료 메시지 표시

---

## 관련 파일

- `estelle-pylon/src/index.js`
- `estelle-pylon/src/claudeManager.js` (버그 4 수정)
- `estelle-app/lib/state/providers/claude_provider.dart` (버그 3 수정)
