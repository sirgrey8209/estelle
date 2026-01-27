# 웹 버전 초기 로딩 스피너 멈춤 현상 수정

## 날짜
2026-01-27

## 문제
- 웹 버전 앱 시작 시 "Connecting..." 스피너가 18~20초간 멈춤
- 스피너 애니메이션이 동작하지 않고 정지된 상태로 유지됨

## 원인 분석 과정

1. **초기 가설**: WebSocket 연결 대기 중 블로킹
   - `RelayService.connect()`에 로그 추가하여 추적
   - WebSocket 연결을 비활성화해도 동일한 블로킹 발생 → 원인 아님

2. **두 번째 가설**: Flutter Web 렌더러(CanvasKit) 초기화
   - `--web-renderer html` 옵션으로 HTML 렌더러 테스트
   - 동일한 블로킹 발생 → 원인 아님

3. **최종 발견**: 브라우저 Performance 탭 프로파일링
   - `_httpFetchFontAndSaveToDevice` 함수가 메인 스레드를 6초 이상 점유
   - **`GoogleFonts.notoColorEmoji()` 호출이 원인**

## 근본 원인
`app_theme.dart`에서 테마 빌드 시점에 `GoogleFonts.notoColorEmoji()`를 호출하여 Google 서버에서 대용량 폰트(수 MB)를 동기적으로 다운로드. 이 과정에서 메인 스레드가 블로킹되어 애니메이션 포함 모든 UI 업데이트가 정지됨.

```dart
// 문제의 코드
static ThemeData get darkTheme {
  GoogleFonts.notoColorEmoji();  // ← 블로킹 원인
  return ThemeData(...);
}
```

## 해결
해당 폰트 로딩 비활성화 (시스템 에모지 폰트 사용)

```dart
static ThemeData get darkTheme {
  // GoogleFonts.notoColorEmoji();  // 비활성화
  return ThemeData(...);
}
```

## 변경 파일
- `estelle-app/lib/core/theme/app_theme.dart`

## 향후 개선 방안 (필요시)
1. 에모지 폰트를 assets에 로컬 번들링
2. 앱 로딩 완료 후 비동기로 폰트 로딩
3. 폰트 프리로딩 설정 사용

## 교훈
- `google_fonts` 패키지는 폰트를 런타임에 HTTP로 다운로드함
- 대용량 폰트(특히 Noto Color Emoji)는 초기 로딩에 심각한 지연 유발
- Flutter Web에서 동기적 네트워크 요청은 메인 스레드 블로킹 가능
