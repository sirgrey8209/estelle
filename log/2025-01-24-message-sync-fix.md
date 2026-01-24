# Estelle 버그 수정 및 미완성 기능 플랜

**상태: ✅ 구현 완료 (2025-01-24)**

## 버그 현상
- 히스토리가 길어지면 앱에서 메시지가 잘 안오는 케이스 발생
- 에디트가 떴는데 권한 질문이 안오는 경우
- 오랜 시간 답변이 안오는 경우
- 재접속하면 정상화되는 경우 있음
- 데스크 전환 시 send/stop 상태가 꼬이는 문제

---

## 수정 항목 요약

| # | 작업 | 위치 | 예상 시간 |
|---|------|------|----------|
| 0 | desk_sync_result에서 상태 복원 | App | 15분 |
| 1 | 히스토리 저장 시 output/input 길이 제한 | Pylon | 1시간 |
| 2 | 퍼미션 모드 적용 (handlePermission) | Pylon | 30분 |
| 3 | 퍼미션 모드 UI | App | 1시간 |

---

## #0. desk_sync_result에서 상태 복원 (15분)

### 문제
Pylon은 `status`, `hasActiveSession`을 보내는데 앱에서 무시함.
→ 데스크 전환 시 상태가 꼬임 (working인데 idle 표시)

### 수정
```dart
// estelle-app claude_provider.dart - _handleDeskSyncResult()
void _handleDeskSyncResult(Map<String, dynamic>? payload) {
  // 기존 코드...

  // ✅ 추가
  final hasActiveSession = payload['hasActiveSession'] as bool? ?? false;

  if (hasActiveSession) {
    _ref.read(claudeStateProvider.notifier).state = 'working';
    _ref.read(isThinkingProvider.notifier).state = true;
  } else if (pendingEvent != null) {
    _ref.read(claudeStateProvider.notifier).state = 'permission';
  } else {
    _ref.read(claudeStateProvider.notifier).state = 'idle';
  }
}
```

---

## #1. 툴 output/input 길이 제한 (1시간)

### 문제
- `output`에 Read/Bash 결과 등 수천~수만 자가 들어감
- `toolInput`도 Edit의 new_string 등 클 수 있음
- 히스토리에 쌓이면서 sync/페이징 시 엄청난 데이터 전송

### 해결 방향: 단순하게 길이 제한 + 요약

| 상황 | 처리 |
|------|------|
| 실시간 스트리밍 | ✅ 전체 전송 (기존과 동일) |
| 히스토리 저장 | ⚡ 길이 제한 (500자?) + 요약 정보 |
| 히스토리 로딩 | ⚡ 제한된 내용만 전송 |

### Pylon: messageStore에서 저장 시 truncate
```javascript
// estelle-pylon/src/messageStore.js
const MAX_OUTPUT_LENGTH = 500;
const MAX_INPUT_LENGTH = 300;

// toolInput 요약 (저장용)
function summarizeToolInput(toolName, input) {
  // 파일 관련 도구는 경로만
  if (['Read', 'Edit', 'Write'].includes(toolName)) {
    return { file_path: input.file_path };
  }
  // Bash는 command의 첫 줄만
  if (toolName === 'Bash') {
    const firstLine = (input.command || '').split('\n')[0];
    return {
      command: firstLine.length > MAX_INPUT_LENGTH
        ? firstLine.slice(0, MAX_INPUT_LENGTH) + '...'
        : firstLine
    };
  }
  // 기타는 그대로 (단, 값이 길면 truncate)
  return truncateObjectValues(input, MAX_INPUT_LENGTH);
}

// output 요약 (저장용)
function summarizeOutput(output) {
  if (!output || output.length <= MAX_OUTPUT_LENGTH) return output;
  return output.slice(0, MAX_OUTPUT_LENGTH) + `\n... (${output.length} chars total)`;
}

completeToolCall(deskId, toolName, success, result, error) {
  messages[i] = {
    ...msg,
    type: 'tool_complete',
    toolInput: summarizeToolInput(toolName, msg.toolInput),  // 요약
    success,
    output: summarizeOutput(result),  // 요약
    error
  };
}
```

### 효과
- 별도 저장소 불필요
- 클릭해서 더 보기 기능 불필요 (어차피 지나간 건 truncate)
- 실시간은 전체 보여주고, 히스토리는 요약만

---

## #2~3. 퍼미션 모드 완성 (1시간 30분)

### 현황

| 구성요소 | 상태 |
|---------|------|
| estelle-shared | ✅ `PermissionMode` 상수 정의 |
| Pylon - deskStore | ✅ get/set 저장/불러오기 |
| Pylon - 메시지 핸들러 | ✅ `claude_set_permission_mode` 처리 |
| Pylon - claudeManager | ❌ 모드 체크 안함 |
| App - UI | ❌ 미구현 |

### #2. Pylon: handlePermission에서 모드 체크
```javascript
// estelle-pylon/src/claudeManager.js
async handlePermission(deskId, toolName, input) {
  const mode = deskStore.getPermissionMode();

  // bypassPermissions: 모든 도구 자동 허용
  if (mode === 'bypassPermissions') {
    console.log(`[ClaudeManager] Bypass mode - auto-allow: ${toolName}`);
    return { behavior: 'allow', updatedInput: input };
  }

  // acceptEdits: Edit, Write, Bash 등 자동 허용
  if (mode === 'acceptEdits') {
    const editTools = ['Edit', 'Write', 'Bash', 'NotebookEdit'];
    if (editTools.includes(toolName)) {
      console.log(`[ClaudeManager] AcceptEdits mode - auto-allow: ${toolName}`);
      return { behavior: 'allow', updatedInput: input };
    }
  }

  // 기존 로직 (사용자에게 권한 요청)...
}
```

### #3. App: 퍼미션 모드 UI
- 설정 또는 데스크 컨텍스트 메뉴에 모드 선택 추가
- `claude_set_permission_mode` 메시지 전송
- (선택) 현재 모드 상태바 표시

---

## 예상 효과

- 히스토리 sync: 수십 MB → 수백 KB
- 상태 꼬임 문제 해결
- 퍼미션 모드 정상 동작

---

## 추가 고려사항

- [ ] 퍼미션 모드를 데스크별로 할지 전역으로 할지?
- [ ] truncate 길이 최적값 테스트 (500자? 300자?)

---

## 참고 파일

- `estelle-pylon/src/claudeManager.js` - 권한 핸들링
- `estelle-pylon/src/messageStore.js` - 히스토리 저장
- `estelle-pylon/src/deskStore.js` - 퍼미션 모드 저장
- `estelle-app/lib/state/providers/claude_provider.dart` - 상태 관리

---

## 구현 완료 내역

### 수정된 파일

1. **estelle-app/lib/state/providers/claude_provider.dart**
   - `_handleDeskSyncResult()`에서 `hasActiveSession` 읽어서 상태 복원

2. **estelle-pylon/src/messageStore.js**
   - `summarizeToolInput()` - 도구별 input 요약
   - `summarizeOutput()` - output 500자 제한
   - `truncateObjectValues()` - 객체 값 truncate 헬퍼
   - `addToolStart()`, `updateToolComplete()` 수정

3. **estelle-pylon/src/claudeManager.js**
   - `handlePermission()`에서 퍼미션 모드 체크 추가
   - bypassPermissions, acceptEdits 모드 지원

4. **estelle-app/lib/data/services/relay_service.dart**
   - `setPermissionMode()` 메서드 추가

5. **estelle-app/lib/ui/widgets/settings/permission_mode_section.dart** (신규)
   - 퍼미션 모드 선택 UI 위젯

6. **estelle-app/lib/ui/widgets/settings/settings_screen.dart**
   - PermissionModeSection 추가
