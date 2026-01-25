# MessageList 스크롤 문제 해결 계획

## 문제 분석

### 현재 문제
1. 첫 시작 시 맨 아래로 스크롤되지 않음
2. FAB 버튼 클릭 시 두 번 눌러야 맨 아래로 이동

### 근본 원인
`maxScrollExtent`는 **현재 렌더링된 항목만** 고려하여 계산됨. 동적 크기의 메시지(길이가 다른 채팅)에서는 정확하지 않음.

> "We don't know at the time that you call jumpTo how long the list is, since all of the sizes are variable and are lazily built as we scroll down the list."
> — [Flutter GitHub Issue #71742](https://github.com/flutter/flutter/issues/71742)

### 현재 접근법의 한계
```dart
_scrollController.animateTo(_scrollController.position.maxScrollExtent, ...)
```
- `addPostFrameCallback` 사용해도 `maxScrollExtent`가 부정확
- 여러 프레임 딜레이를 줘도 동적 크기 항목에서는 불안정

---

## 해결책: `reverse: true` 사용

채팅 앱에서 권장되는 표준 패턴.
([참고: smarx.com](https://smarx.com/posts/2020/08/automatic-scroll-to-bottom-in-flutter/))

### 작동 원리
- `reverse: true` 설정 시 ListView가 아래에서 위로 렌더링
- **스크롤 위치 0 = 맨 아래** (실제로는 리스트의 끝)
- 초기 로드 시 자동으로 맨 아래에서 시작
- 새 메시지 추가 시 자연스럽게 아래에 표시

### 장점
1. 초기 로드 문제 자동 해결 (offset 0에서 시작)
2. FAB 버튼: `jumpTo(0)`으로 즉시 맨 아래 이동
3. `maxScrollExtent` 계산 문제 회피
4. 채팅 앱의 표준 패턴

### 주의사항
1. **데이터 순서**: 최신 메시지가 인덱스 0이 되어야 함 (reversed)
2. **히스토리 로딩**: 스크롤 방향 반대 (하단 → 상단으로 스크롤 시 로드)
3. **짧은 리스트**: `shrinkWrap: true` + `Align(topCenter)` 필요

---

## 구현 계획

### 변경 파일
- `estelle-app/lib/ui/widgets/chat/message_list.dart`

### 1단계: ListView 설정 변경
```dart
ListView.builder(
  controller: _scrollController,
  reverse: true,  // 추가
  // shrinkWrap: true,  // 짧은 리스트 대응 (선택적)
  ...
)
```

### 2단계: 메시지 인덱스 계산 변경
```dart
// Before (reverse: false)
final message = messages[msgIndex];

// After (reverse: true) - 역순 접근
final message = messages[messages.length - 1 - msgIndex];
```

또는 데이터 자체를 뒤집기:
```dart
final reversedMessages = messages.reversed.toList();
```

### 3단계: 히스토리 로딩 방향 변경
```dart
// Before: 상단(pixels <= 100)에서 히스토리 로드
if (position.pixels <= 100) { loadMoreHistory(); }

// After: 하단(maxScrollExtent 근처)에서 히스토리 로드
if (position.pixels >= position.maxScrollExtent - 100) { loadMoreHistory(); }
```

### 4단계: 스크롤 버튼 로직 변경
```dart
// Before
_scrollController.animateTo(maxScrollExtent, ...);

// After (reverse: true에서 맨 아래 = offset 0)
_scrollController.animateTo(0, ...);
```

### 5단계: 스크롤 버튼 표시 조건 변경
```dart
// Before: 하단에서 200px 이상 떨어지면 표시
final shouldShow = position.pixels < position.maxScrollExtent - 200;

// After: 상단(offset 0)에서 200px 이상 떨어지면 표시
final shouldShow = position.pixels > 200;
```

### 6단계: 자동 스크롤 제거
`reverse: true` 사용 시 새 메시지가 자동으로 맨 아래에 표시되므로
`_scrollToBottom()` 호출 불필요 (선택적으로 유지 가능)

### 7단계: 로딩 인디케이터 위치 변경
현재 상단에 있는 "이전 메시지 로드" 인디케이터 → 하단으로 이동
(reverse 시 리스트 끝이 화면 상단에 표시됨)

---

## 구현 순서

1. [ ] ListView에 `reverse: true` 추가
2. [ ] 메시지 인덱스 계산 역순으로 변경
3. [ ] 히스토리 로딩 트리거 방향 변경 (상단→하단)
4. [ ] 로딩 인디케이터 위치 조정
5. [ ] `_scrollToBottom` → `_scrollToEnd` 로직 변경 (jumpTo(0))
6. [ ] 스크롤 버튼 표시 조건 변경
7. [ ] `_isNearBottom` 로직 반전
8. [ ] 불필요한 코드 정리 (`_initialScrollDone` 등)
9. [ ] 테스트

---

## 예상 결과
- 첫 시작 시 맨 아래에서 시작 (자동)
- FAB 버튼 클릭 시 즉시 맨 아래로 이동
- 안정적인 히스토리 로딩
- 깔끔한 코드 구조
