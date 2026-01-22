# 데스크 아키텍처

## 상태: DONE

## 요구사항 ✅ 구현됨
- 앱 접속 시 자동으로 데스크 선택
- 마지막 선택 데스크 기억 (deviceId + deskId)
- 해당 데스크가 없으면 첫 번째 데스크 선택

## 멀티 Pylon 구조
```
App 접속
    ↓
desk_list (broadcast: 'pylons')
    ↓
┌─ Pylon 1 (Stella/회사) → desk_list_result [X, Y]  ← 우선순위 1
└─ Pylon 2 (Selene/집) → desk_list_result [A, B]    ← 우선순위 2
```

**Pylon 순서 고정:** 회사(1) → 집(2)

## 자동 선택 로직

```
desk_list_result 수신 (Pylon X)
    ↓
lastSelectedDesk (deviceId + deskId)가 이 목록에 있나?
    ├─ Yes → 바로 접속! (완료)
    └─ No → 대기

모든 Pylon에서 desk_list_result 수신 완료
    ↓
여전히 선택 안 됨 → 회사(1) 첫 번째 데스크, 없으면 집(2) 첫 번째 데스크
```

### "모든 Pylon 수신 완료" 판단
- `device_status`에서 연결된 Pylon 수 확인
- 해당 수만큼 `desk_list_result` 받으면 완료

## 저장 데이터

```dart
// SharedPreferences
{
  'estelle_last_desk': {
    'deviceId': 2,        // Pylon device ID
    'deskId': 'xxx-xxx'   // Desk ID
  }
}
```

## 구현 위치

### App (Flutter)
1. `SharedPreferences`로 lastSelectedDesk 저장/로드
2. `desk_list_result` 수신 핸들러에서:
   - lastSelectedDesk 확인
   - 있으면 즉시 선택
3. 모든 Pylon 응답 완료 시:
   - 아직 선택 안 됐으면 첫 번째 데스크
4. 데스크 선택 시 lastSelectedDesk 저장

### 관련 파일
- `lib/state/providers/desk_provider.dart` - 데스크 목록 관리
- `lib/data/services/relay_service.dart` - desk_select 전송

## 데스크 상태 정의 ✅ 구현됨

### 상태 (status)
| 상태 | 설명 | UI 표시 |
|------|------|---------|
| `idle` | 대기 상태 (메시지 수신 가능) | 🟢 초록색 점 |
| `working` | Claude 작업 중 | 🟡 노란색 점 (점멸) |
| `waiting` | 사용자 입력 대기 (질문/권한) | 🔴 붉은색 점 |
| `error` | 오류 발생 | ❌ X 표시 |

**참고:** `shutdown` 제거됨. 프로세스 존재 여부는 내부 구현으로 처리.

### 데스크 정보 구조
```javascript
{
  deskId: 'uuid',
  name: '작업명',
  workingDir: 'C:\\path\\to\\project',
  status: 'idle',           // idle | working | waiting | error
  claudeSessionId: 'xxx',   // 세션 ID (resume용, 내부 관리)
  lastActivity: 1234567890, // 마지막 활동 시간
}
```

**제거된 필드:**
- `hasActiveSession` → 앱에서 불필요
- `canResume` → 앱에서 불필요 (Pylon이 알아서 처리)
- `shutdown` 상태 → `idle`로 통합

## 히스토리 기반 접근

```
앱 접속 → desk_select
    ↓
Pylon: messageStore에서 히스토리 로드
    ↓
앱에 히스토리 전송 → 화면 표시
    ↓
메시지 전송 시 Pylon이 알아서 resume/새세션 처리
```

### 히스토리 페이징 ✅ 구현됨

```
스크롤 상단 근처 도달 (pixels <= 100)
    ↓
App → Pylon: history_request { deskId, limit: 50, offset }
    ↓
Pylon → App: history_result { messages, hasMore, totalCount }
    ↓
메시지 prepend + 스크롤 위치 보존
```

**구현 파일:**
- `estelle-pylon/src/index.js` - history_request 핸들러
- `estelle-app/lib/data/services/relay_service.dart` - requestHistory()
- `estelle-app/lib/state/providers/claude_provider.dart` - 페이징 상태
- `estelle-app/lib/ui/widgets/chat/message_list.dart` - 스크롤 감지

**엣지 케이스 (추후 실험 필요):**
- `waiting` 상태에서 연결 끊김 → 재접속 시 질문 복원?
- 프로세스 죽음 후 resume → 이전 질문 다시 나오나?

### 상태 업데이트 흐름
```
1. 초기 로드
   App → Pylon: desk_list
   Pylon → App: desk_list_result (각 데스크의 현재 status 포함)

2. 상태 변경 시
   Pylon에서 status 변경 발생 (idle→working, working→waiting 등)
       ↓
   Pylon → Relay: desk_status (broadcast: 'apps')
       ↓
   전체 앱 클라이언트에게 브로드캐스트
```

### 데스크 구독 (Viewing)
```
App → Pylon: desk_select { deskId }
    ↓
Pylon: deskViewers.set(deskId, [...viewers, clientId])
    ↓
이후 해당 데스크의 claude_event만 수신
```

- 한 클라이언트는 한 번에 하나의 데스크만 구독
- 다른 데스크 선택 시 이전 구독 해제 → 새 구독 등록
- 연결 끊김 시 자동 구독 해제 (`client_disconnect`)

**브로드캐스트 대상:**
- `desk_status` → 모든 앱 클라이언트 (전체 브로드캐스트)
- `claude_event` → 해당 데스크 시청자만 (선택적 라우팅)

## UI/UX 방향 ✅ 구현됨

### 공통
- 위/아래 컴팩트하게 → 모바일 가시성 향상 (헤더/입력바 패딩 축소)

### Desktop
- 좌우 너무 넓지 않게
- 좌측 정렬 디자인

### Mobile
- 좌우 레이아웃 고려 (스와이프)

---
작성일: 2026-01-22
