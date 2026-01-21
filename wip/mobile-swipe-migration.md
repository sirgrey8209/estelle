# 모바일 스와이프 UI 마이그레이션

## 목표
데스크톱 버전의 UI/기능을 모바일로 마이그레이션하되, 데스크 섹션과 채팅 섹션을 좌우 스와이프로 전환

## 완료된 작업

### 1. 프로젝트 구조 파악
- 데스크톱: `estelle-desktop/src/App.jsx` - 좌측 사이드바(Pylon/Desk 목록) + 우측 채팅
- 모바일: `estelle-mobile/.../MainActivity.kt` - Kotlin + Jetpack Compose

### 2. build.gradle.kts 수정
```kotlin
// HorizontalPager를 위한 foundation 의존성 추가
implementation("androidx.compose.foundation:foundation")
```

### 3. MainActivity.kt import 추가
```kotlin
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.PagerState
import androidx.compose.foundation.pager.rememberPagerState
import kotlinx.coroutines.launch
```

---

## 남은 작업

### 4. EstelleApp 함수 수정
- `HorizontalPager` 적용 (2페이지: 데스크 목록 / 채팅)
- `bottomBar` (NavigationBar) 제거
- 페이지 인디케이터 추가 (선택)

```kotlin
// 예시 구조
@Composable
fun EstelleApp(viewModel: MainViewModel = viewModel()) {
    val pagerState = rememberPagerState(pageCount = { 2 })

    Scaffold(
        topBar = { /* 기존 TopAppBar 유지 */ }
        // bottomBar 제거
    ) { padding ->
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.padding(padding).fillMaxSize()
        ) { page ->
            when (page) {
                0 -> DeskListPage(viewModel, pagerState)
                1 -> ChatPage(viewModel)
            }
        }
    }
}
```

### 5. DeskListPage 컴포저블 생성
데스크톱 사이드바와 유사한 UI:
- Pylon 그룹별 데스크 목록 (LazyColumn)
- 각 Pylon 헤더 (아이콘 + 이름 + 새 데스크 버튼)
- 데스크 항목 (들여쓰기, 상태 표시)
- 데스크 선택 시 자동으로 ChatPage로 스와이프

### 6. ChatPage 컴포저블 생성
기존 `ClaudeScreen`에서 `DeskSelector` 제거:
- 상단에 현재 선택된 데스크 표시 (헤더)
- 메시지 목록
- 컨트롤 바 (Stop/New Session)
- 입력창

### 7. (선택) 페이지 인디케이터
- 하단 또는 상단에 현재 페이지 표시 (점 2개)

---

## 참고: 데스크톱 사이드바 구조 (App.jsx)

```
┌─────────────────┐
│ Pylons          │  ← 섹션 헤더
├─────────────────┤
│ 💻 Stella    [+]│  ← Pylon 그룹 (새 데스크 버튼)
│   └ main     ●  │  ← 데스크 (상태 점)
│   └ test        │
├─────────────────┤
│ 🌙 Selene    [+]│
│   └ work        │
└─────────────────┘
```

---

## 파일 위치
- `estelle-mobile/app/build.gradle.kts` - 의존성
- `estelle-mobile/app/src/main/java/com/nexus/android/MainActivity.kt` - UI 코드
- `estelle-mobile/app/src/main/java/com/nexus/android/MainViewModel.kt` - 상태 관리

---

작성일: 2026-01-22
