# 작업완료 기능

## 개요
채팅창 메뉴에 "작업완료" 버튼을 추가하여 세션 정리(로그 이동 + 커밋) 및 삭제까지 한 번에 처리하는 기능.

## 상태 흐름

```
idle → finishing → finished → idle/deleted
```

| 상태 | 설명 |
|------|------|
| `finishing` | 작업완료 진행 중 (Claude가 커밋&로그 작업 중) |
| `finished` | 작업완료 완료 (다이얼로그 대기 상태) |

## 구현 플로우

```
[앱] 작업완료 버튼 클릭
       ↓
[앱] finish_work control 요청
       ↓
[Pylon] status = 'finishing' 저장 (영속)
[Pylon] Claude에게 정리 메시지 전송
       ↓
[Claude 작업 완료 (idle)]
       ↓
[Pylon] status = 'finished' + finish_work_complete 이벤트
       ↓
[앱] 다이얼로그 표시: "세션을 삭제하시겠습니까?"
  - 예 → 대화 삭제
  - 아니오 → cancel_finish → idle 복원
```

## 재시작/재접속 처리

### Pylon 재시작 시
- `finishing` 상태 대화 자동 감지
- 작업완료 메시지 재전송 (자동 복구)

### 앱 재접속 시
- `finished` 상태 대화 선택 시 자동으로 다이얼로그 표시

## 변경된 파일

### Pylon
- `src/workspaceStore.js`
  - `getFinishingConversations()` 추가
  - `getFinishedConversations()` 추가
  - 상태 주석에 finishing/finished 추가

- `src/index.js`
  - `handleClaudeControl`: `finish_work`, `cancel_finish` 처리
  - `handleFinishWork()`: finishing 상태 변경 + Claude 메시지 전송
  - `handleCancelFinish()`: finished → idle 복원
  - `checkFinishWorkComplete()`: 완료 시 finished 상태 + 이벤트 전송
  - `resumeFinishingConversations()`: 시작 시 finishing 대화 자동 재처리

### 앱
- `lib/data/models/workspace_info.dart`
  - `ConversationStatus`에 `finishing`, `finished` 추가
  - `dotStatus`, `priority` getter 수정

- `lib/state/providers/workspace_provider.dart`
  - `FinishWorkCompleteEvent` 클래스 추가
  - `finishWorkCompleteProvider` 추가
  - `_handleFinishWorkComplete()` 핸들러 추가

- `lib/ui/widgets/chat/chat_area.dart`
  - `ConsumerStatefulWidget`으로 변경
  - `finishWorkCompleteProvider` 리스닝
  - `finished` 상태 대화 선택 시 자동 다이얼로그
  - 메뉴에 "작업완료" 버튼 추가

## Claude에게 보내는 메시지

```
현재 세션에서 작업된 내용을 정리해주세요:
1. wip/ 폴더의 작업 문서를 log/ 폴더로 이동 (날짜 prefix 추가)
2. 변경사항 커밋

완료되면 알려주세요.
```

## 상태: 구현 완료

- [x] Pylon 상태 관리 (finishing/finished)
- [x] Pylon 재시작 시 자동 재처리
- [x] 앱 이벤트 리스닝 및 다이얼로그
- [x] 앱 재접속 시 finished 상태 처리
- [x] 빌드 확인
