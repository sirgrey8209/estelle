# New Workspace Dialog

> 새 워크스페이스 생성 다이얼로그

## 위치

`lib/ui/widgets/sidebar/new_workspace_dialog.dart`

---

## 역할

- Pylon 선택
- 폴더 탐색 및 선택
- 워크스페이스 이름 입력
- 새 폴더 생성/이름 변경

---

## Props

| Prop | 타입 | 설명 |
|------|------|------|
| `pylons` | `List<PylonWorkspaces>` | 연결된 Pylon 목록 |

---

## 상태 (State)

| 상태 | 타입 | 초기값 | 설명 |
|------|------|--------|------|
| `_selectedPylonIndex` | `int` | 0 | 선택된 Pylon 인덱스 |
| `_nameController` | `TextEditingController` | - | 이름 입력 컨트롤러 |
| `_selectedFolder` | `String?` | null | 선택된 폴더명 |

---

## 구조

```
┌────────────────────────────────────┐
│  새 워크스페이스                [X]  │  ← Header
├────────────────────────────────────┤
│  [🌙] [워크스페이스 이름 입력    ]   │  ← Pylon + Name
├────────────────────────────────────┤
│  📁 C:\workspace                [↑]  │  ← Path bar
├────────────────────────────────────┤
│  📁 estelle                         │  ← Folder list
│  📁 other-project              ✓   │
│  📁 ...                             │
│  ─────────────────────────────────  │
│  📁+ 새 폴더                        │
├────────────────────────────────────┤
│              [취소]  [생성]         │  ← Buttons
└────────────────────────────────────┘
```

---

## 동작

### Pylon 선택

| 조건 | 동작 |
|------|------|
| Pylon 아이콘 클릭 | 다음 Pylon으로 순환 (1개일 때 비활성화) |
| Pylon 변경 시 | 해당 Pylon의 폴더 목록 요청 |

### 폴더 탐색

| 제스처 | 동작 |
|--------|------|
| 탭 | 폴더 선택 (이름에 자동 입력) |
| 더블탭 | 폴더 내부로 진입 |
| 롱프레스 | 폴더 이름 변경 다이얼로그 |
| ↑ 버튼 | 상위 폴더로 이동 |

### 폴더 선택 상태

| 상태 | 표시 |
|------|------|
| 미선택 | 기본 배경 |
| 선택됨 | `sidebarSelected` 배경, 체크 아이콘, `accent` 색상 |

### 생성

1. 이름이 비어있으면 스낵바 표시
2. 선택된 폴더가 있으면: `{path}\{folder}` 경로
3. 선택된 폴더가 없으면: 현재 `{path}` 경로
4. `createWorkspace` 호출 후 다이얼로그 닫기

---

## 서브 다이얼로그

### _CreateFolderDialog

새 폴더 생성

- 텍스트 입력 필드
- 확인 시 `createFolder` 호출

### _RenameFolderDialog

폴더 이름 변경

- 현재 이름 미리 입력
- 변경 시 `renameFolder` 호출

---

## Provider 의존성

| Provider | 용도 |
|----------|------|
| `folderListProvider` | 폴더 목록 조회/관리 |
| `pylonWorkspacesProvider` | 워크스페이스 생성 |

---

## UI 스펙

### 크기

| 요소 | 값 |
|------|-----|
| 다이얼로그 너비 | 400px |
| 최대 높이 | 500px |
| 헤더 패딩 | 16px |
| 섹션 패딩 | 12px |

### 색상

| 요소 | 색상 |
|------|------|
| 선택된 폴더 배경 | `sidebarSelected` |
| 선택된 폴더 아이콘/체크 | `accent` |
| 미선택 폴더 아이콘 | `textMuted` |
| 에러 메시지 | `statusError` |

### 폰트

| 요소 | 크기 |
|------|------|
| 헤더 타이틀 | 18px, 600 |
| 폴더명 | 14px |
| 경로 | 13px |

---

## 관련 문서

- [../components/workspace-sidebar.md](../components/workspace-sidebar.md) - 워크스페이스 사이드바
- [../state/workspace-provider.md](../state/workspace-provider.md) - 워크스페이스 상태
