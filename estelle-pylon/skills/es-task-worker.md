# es-task-worker

워커용 스킬입니다. 태스크 파일을 읽고 구현합니다.

## 역할

- 태스크 파일을 읽고 플랜 파악
- 순서대로 코드 구현
- 완료/실패 시 태스크 상태 업데이트

## 사용 가능한 도구

모든 코딩 도구 사용 가능:
- Read - 파일 읽기
- Edit - 파일 수정
- Write - 파일 생성
- Bash - 명령어 실행
- Glob, Grep - 검색
- Task - 에이전트

## 실행 흐름

### 1. 태스크 파일 읽기

워커 시작 시 인자로 받은 태스크 파일 경로를 읽습니다.

```
/es-task-worker C:\workspace\estelle\task\20260124-버튼-변경.md를 꼼꼼히 구현 부탁해.
```

### 2. 플랜 파악

태스크 파일의 구조:
```markdown
---
id: 550e8400-e29b-41d4-a716-446655440000
title: 버튼 색상 변경
status: pending
createdAt: 2026-01-24T10:00:00Z
startedAt:
completedAt:
error:
---

## 목표
...

## 플랜
1. ...
2. ...
```

### 3. 순서대로 구현

- 플랜의 각 단계를 순서대로 실행
- 코드 수정, 파일 생성, 테스트 등 필요한 작업 수행
- 문제 발생 시 해결 시도

### 4. 완료 처리

**성공 시:**
태스크 파일의 frontmatter 업데이트:
```yaml
status: done
completedAt: 2026-01-24T11:30:00Z
```

**실패 시:**
```yaml
status: failed
completedAt: 2026-01-24T11:30:00Z
error: [에러 내용 간략히]
```

## Frontmatter 업데이트 방법

Edit 도구로 frontmatter 부분만 수정:

```
Edit 도구 사용:
- file_path: [태스크 파일 경로]
- old_string: "status: pending" 또는 "status: running"
- new_string: "status: done"

추가로:
- old_string: "completedAt:"
- new_string: "completedAt: 2026-01-24T11:30:00Z"
```

## 주의사항

1. **플랜 순서 준수**: 플랜에 명시된 순서대로 작업
2. **테스트 확인**: 가능하면 변경 사항 테스트
3. **상태 업데이트**: 작업 완료/실패 시 반드시 상태 업데이트
4. **에러 기록**: 실패 시 원인을 error 필드에 간략히 기록

## 예시 실행

**입력:**
```
/es-task-worker C:\workspace\estelle\task\20260124-버튼-변경.md를 꼼꼼히 구현 부탁해.
```

**Claude 동작:**
1. 태스크 파일 읽기
2. 목표와 플랜 파악
3. 플랜 단계별 실행
   - 관련 파일 읽기
   - 코드 수정
   - 필요시 테스트
4. 완료 시 frontmatter 업데이트

**출력:**
```
태스크 "버튼 색상 변경"을 완료했습니다.

수행한 작업:
1. src/theme/colors.ts에서 primary 색상을 #BF616A로 변경
2. 관련 컴포넌트 확인 완료

태스크 상태를 done으로 업데이트했습니다.
```

---

*이 스킬은 태스크 파일의 플랜을 실행합니다. 계획 수립은 es-task-builder에서 합니다.*
