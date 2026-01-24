# Worker System 기획

## 개요

대화 Claude와 워커 Claude를 분리하여, 일감 기반의 자동화된 코딩 시스템 구축

---

## 핵심 개념

### 용어
- **워크스페이스**: workingDir + Pylon 기준의 프로젝트 단위 (기존 데스크)
- **대화**: 계획/논의용 Claude 세션 (코딩 안 함)
- **태스크**: 일감 실행용 Claude 세션 (코딩 함)

### 구조

```
워크스페이스 (workingDir + Pylon)
├── 💬 대화 (여러 개 가능) [es-task-builder]
├── 📋 태스크 (여러 개) [es-task-worker]
└── task/ 폴더 (태스크 MD 파일들)
```

### 스킬 분리

| 스킬 | 역할 | 코딩 |
|------|------|------|
| `es-task-builder` | 계획, 논의, 태스크 생성 | 안 함 |
| `es-task-worker` | 태스크 실행 | 함 |

---

## 주요 컴포넌트

### Estelle MCP (Pylon 내장)
- 대화 Claude ↔ Pylon 통신
- task_create, task_list, worker_status 등

### Task 파일
- 위치: `{프로젝트}/task/*.md`
- 형식: Frontmatter (메타) + Markdown (플랜)
- wip/ 폴더 대체 예정

### 워커
- 워크스페이스당 1개
- FIFO 큐로 태스크 순차 실행

---

## 구현 단계

- **Phase 1**: MVP (UI 구조 변경, 기본 태스크 흐름)
- **Phase 2**: 우선순위, 긴급 끼워넣기
- **Phase 3**: Prerequisites, 워커 대화 연결, 배포 연동

---

*Created: 2026-01-24*
