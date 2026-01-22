# 메시지 스토어 최적화

## 상태: COMPLETED

## 배경
현재 messageStore:
- 매 작업마다 전체 파일을 읽고 씀
- 메모리 캐시 없음
- 페이징 미지원

## 개선 사항

### 1. 메모리 캐시
- 데스크별 메시지 배열을 메모리에 유지
- 첫 load 시에만 파일에서 읽음
- 이후에는 메모리에서 직접 접근

### 2. Debounced 파일 저장
- 매번 저장하지 않고 2초 debounce
- 프로세스 종료 시 즉시 저장 (`saveAll()`)

### 3. 페이징 지원
- `load(deskId, { limit, offset })` 형식
- 기본 limit = 200 (MAX_MESSAGES_PER_DESK)

### 4. 메모리 정리
- 시청자가 없는 데스크의 캐시는 저장 후 해제
- `deskViewers`와 연동 (`registerDeskViewer`, `unregisterDeskViewer`)

## 구현 완료

### messageStore.js 변경
```javascript
class MessageStore {
  constructor() {
    this.cache = new Map();      // deskId → messages[]
    this.dirty = new Set();      // 저장 필요한 deskId
    this.saveTimers = new Map(); // debounce timers
  }

  load(deskId, options = {}) { ... }     // 페이징 지원
  ensureCache(deskId) { ... }            // 캐시 확보
  saveNow(deskId) { ... }                // 즉시 저장
  scheduleSave(deskId) { ... }           // debounced 저장
  unloadCache(deskId) { ... }            // 캐시 해제
  saveAll() { ... }                      // 종료 시 전체 저장
}
```

### index.js 변경
- `registerDeskViewer()`: 이전 데스크 시청자 0명 → `unloadCache()`
- `unregisterDeskViewer()`: 데스크 시청자 0명 → `unloadCache()`
- SIGINT 핸들러: `messageStore.saveAll()` 추가

## 수정 파일
- `estelle-pylon/src/messageStore.js` - 전면 재작성
- `estelle-pylon/src/index.js` - 캐시 해제 로직 추가

---
작성일: 2026-01-22
완료일: 2026-01-22
