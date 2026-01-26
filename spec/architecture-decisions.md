# Architecture Decisions

> 왜 이렇게 설계했는가

---

## 1. Relay는 순수 라우터

### 결정
Relay는 메시지 내용을 해석하지 않고, 인증 + 라우팅만 수행한다.

### 이유
- **단순성**: Relay 코드가 단순해짐. 버그 가능성 감소.
- **확장성**: 새 메시지 타입 추가 시 Relay 수정 불필요.
- **배포 안정성**: Relay 업데이트 빈도 최소화. Fly.io 재시작 부담 감소.

### 결과
- 모든 비즈니스 로직은 Pylon에 집중
- Relay는 `to`, `broadcast` 필드만 보고 라우팅
- 메시지 스키마 변경이 Relay에 영향 없음

---

## 2. Pylon이 Single Source of Truth

### 결정
모든 상태(워크스페이스, 대화, Claude 세션)는 Pylon이 관리한다. App은 표시만.

### 이유
- **일관성**: 여러 App이 접속해도 동일한 상태 보장
- **오프라인 복구**: App 재접속 시 Pylon에서 전체 상태 받아옴
- **충돌 방지**: 상태 변경은 항상 Pylon을 통해서만

### 결과
- App의 Provider들은 Pylon에서 받은 데이터를 캐싱
- 사용자 액션 → Pylon에 요청 → Pylon이 상태 변경 → App에 브로드캐스트
- App은 로컬 상태 직접 수정 안 함

---

## 3. Session Viewer 시스템

### 결정
App이 특정 대화를 "보고 있음"을 Pylon에 알린다.

### 이유
- **효율성**: 안 보는 대화의 스트리밍 데이터 전송 불필요
- **UX**: 다른 기기에서 같은 대화 보면 실시간 동기화

### 동작
```
App: { type: 'view_session', conversationId: 'xxx' }
Pylon: 해당 App을 viewer로 등록
Pylon: 이후 해당 대화 업데이트는 viewer들에게만 전송
```

### 주의
- 대화 전환 시 이전 대화 unview 필요
- 연결 해제 시 자동 unview

---

## 4. Permission Mode 3단계

### 결정
권한 처리를 3단계로 구분: `default`, `acceptEdits`, `bypassPermissions`

### 이유
- **default**: 모든 권한 요청을 App에서 확인. 안전하지만 번거로움.
- **acceptEdits**: 파일 수정은 자동 허용, 위험한 작업(삭제, bash)만 확인. 일반적 사용.
- **bypassPermissions**: 모든 권한 자동 허용. 신뢰할 수 있는 작업에만.

### 구현
```javascript
// claudeManager.js
if (permissionMode === 'bypassPermissions') {
  return { allow: true };
}
if (permissionMode === 'acceptEdits' && tool.type === 'edit') {
  return { allow: true };
}
// 그 외: App에 permission_request 전송
```

---

## 5. Device ID 체계

### 결정
- 고정 ID (1-99): Pylon용. Relay에 하드코딩.
- 동적 ID (100+): App용. 접속 시 자동 발급.

### 이유
- **Pylon 식별**: 집/회사 PC를 명확히 구분
- **App 유연성**: 여러 기기 동시 접속 허용

### 구현
```javascript
// relay/index.js
const DEVICES = {
  1: { name: 'Selene', role: 'home' },
  2: { name: 'Stella', role: 'office' },
};
const DYNAMIC_DEVICE_ID_START = 100;
```

---

## 6. 로컬 연결 우선

### 결정
같은 PC의 Desktop App은 Relay 대신 로컬 WebSocket(9999 포트)으로 연결.

### 이유
- **지연 감소**: 네트워크 왕복 없음
- **오프라인 작동**: 인터넷 없어도 로컬 PC 제어 가능
- **Relay 부하 감소**

### 구현
```dart
// relay_service.dart
if (kIsWeb || !Platform.isWindows) {
  _connectToRelay();
} else {
  _tryLocalFirst();  // 실패 시 Relay로 fallback
}
```

---

## 7. 메시지 저장 구조

### 결정
대화별로 별도 JSON 파일에 저장. `messages/{conversationId}.json`

### 이유
- **단순성**: 파일 단위 읽기/쓰기
- **성능**: 전체 대화 목록 로드 불필요
- **백업 용이**: 파일 복사만으로 백업

### 형식
```json
{
  "conversationId": "xxx",
  "workspaceId": "yyy",
  "messages": [...],
  "updatedAt": "2026-01-25T..."
}
```

---

## 8. 태스크 파일 시스템

### 결정
태스크를 MD 파일로 관리. `task/YYYYMMDD-title.md`

### 이유
- **가시성**: 파일 탐색기에서 직접 확인/편집 가능
- **버전 관리**: Git으로 태스크 히스토리 추적
- **유연성**: Frontmatter로 메타데이터, 본문은 자유 형식

### 형식
```markdown
---
id: uuid
title: 버튼 색상 변경
status: pending
createdAt: 2026-01-25T10:00:00Z
---

## 목표
...
```

---

*이 문서는 "왜"에 집중합니다. "어떻게"는 코드와 주석을 참고하세요.*
