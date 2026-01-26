# Blob Transfer Protocol 리서치

## 개요

Estelle 시스템에서 대용량 데이터(파일, 이미지, 코드 등)를 전송하기 위한 프로토콜 설계.

현재 WebSocket 기반 JSON 메시지로는 대용량 데이터 전송에 한계가 있음.

---

## 현재 구조의 한계

### 1. JSON 기반 텍스트 전송
```
Client ←→ Relay ←→ Pylon
         (WSS)
```

- 모든 데이터가 JSON 문자열로 직렬화됨
- 바이너리 데이터는 Base64 인코딩 필요 (33% 오버헤드)
- 대용량 메시지 시 메모리 부담

### 2. 메시지 크기 제한
- WebSocket 프레임: 이론상 무제한, 실제로는 서버 설정에 따름
- Fly.io 기본 제한: 확인 필요
- 클라이언트 메모리: 모바일에서 대용량 처리 시 문제

### 3. 현재 사용 사례
- Claude 응답 텍스트: 수 KB ~ 수십 KB
- 도구 결과 (파일 읽기 등): 수 KB ~ 수백 KB
- 이미지/스크린샷: 수 MB (현재 미지원)

---

## 요구사항

### 필수
- [ ] 대용량 텍스트 전송 (코드 파일, 로그 등)
- [ ] 바이너리 전송 (이미지, 스크린샷)
- [ ] 청크 분할로 메모리 효율화
- [ ] 전송 진행률 표시
- [ ] 실패 시 재시도/재개

### 선택
- [ ] 압축 (gzip, brotli)
- [ ] 스트리밍 (실시간 로그 등)
- [ ] 우선순위 (긴급 메시지 끼워넣기)

---

## 설계 옵션

### Option A: 청크 메시지 방식

기존 WebSocket 채널 위에 청크 프로토콜 추가.

```javascript
// 첫 번째 청크 (메타데이터)
{
  type: 'blob_start',
  blobId: 'uuid',
  totalSize: 1048576,
  chunkSize: 65536,
  totalChunks: 16,
  mimeType: 'image/png',
  filename: 'screenshot.png'
}

// 데이터 청크
{
  type: 'blob_chunk',
  blobId: 'uuid',
  chunkIndex: 0,
  data: 'base64...'  // 또는 binary
}

// 완료
{
  type: 'blob_end',
  blobId: 'uuid',
  checksum: 'sha256...'
}
```

**장점:**
- 기존 인프라 재사용
- 구현 단순

**단점:**
- Base64 오버헤드 (텍스트 모드)
- 일반 메시지와 경합

### Option B: 별도 바이너리 채널

WebSocket binary 프레임 사용 또는 별도 HTTP 엔드포인트.

```
일반 메시지: WSS (JSON)
대용량 전송: HTTP/2 또는 WSS Binary
```

**장점:**
- 바이너리 효율적
- 일반 메시지 영향 없음

**단점:**
- 추가 연결 관리
- 인증 동기화 필요

### Option C: 파일 서버 방식

Pylon이 임시 HTTP 서버로 파일 제공.

```
1. Pylon → Relay → Client: { type: 'file_ready', url: 'http://pylon:9001/files/abc123' }
2. Client → Pylon: HTTP GET /files/abc123
```

**장점:**
- HTTP 인프라 활용 (Range, 재개 등)
- 대용량에 최적

**단점:**
- 로컬 네트워크에서만 동작 (외부 접근 불가)
- NAT 문제

### Option D: Relay 중계 파일 서버

Relay가 파일도 중계.

```
1. Pylon → Relay: blob 업로드
2. Relay: 임시 저장
3. Relay → Client: 다운로드 URL 제공
4. Client → Relay: HTTP GET
```

**장점:**
- NAT 문제 없음
- 중앙 관리

**단점:**
- Relay 부하 증가
- Fly.io 스토리지 비용

---

## 사용 시나리오

### 1. 스크린샷 공유 (Pylon → Client)
```
[Pylon]
1. Claude가 스크린샷 생성
2. 파일을 청크로 분할
3. blob_start → blob_chunk × N → blob_end 전송

[Client]
1. blob_start 수신 → 진행률 UI 표시
2. blob_chunk 수신 → 버퍼에 누적
3. blob_end 수신 → 재조립, 이미지 표시
```

### 2. 파일 업로드 (Client → Pylon)
```
[Client]
1. 사용자가 파일 선택
2. 청크로 분할
3. blob_start → blob_chunk × N → blob_end 전송

[Pylon]
1. 청크 수신 및 조립
2. 워크스페이스 폴더에 저장
3. Claude에게 파일 경로 전달
```

### 3. 대용량 코드 파일 전송
```
[Pylon]
1. Claude가 대용량 파일 읽기 (예: 10MB 로그)
2. 청크로 분할하여 전송
3. Client에서 스크롤 가능한 뷰어로 표시
```

---

## 프로토콜 상세 설계 (Option A 기준)

### 메시지 타입

| 타입 | 방향 | 설명 |
|------|------|------|
| `blob_start` | 양방향 | 전송 시작, 메타데이터 |
| `blob_chunk` | 양방향 | 데이터 청크 |
| `blob_end` | 양방향 | 전송 완료, 체크섬 |
| `blob_ack` | 양방향 | 청크 수신 확인 |
| `blob_cancel` | 양방향 | 전송 취소 |
| `blob_error` | 양방향 | 에러 발생 |

### blob_start
```javascript
{
  type: 'blob_start',
  blobId: 'uuid-v4',
  to: { deviceId: 100 },
  payload: {
    filename: 'screenshot.png',
    mimeType: 'image/png',
    totalSize: 1048576,      // bytes
    chunkSize: 65536,        // 64KB
    totalChunks: 16,
    encoding: 'base64',      // 'base64' | 'binary'
    compression: null,       // 'gzip' | null
    context: {               // 용도별 메타데이터
      type: 'claude_output', // 'claude_output' | 'user_upload' | 'file_transfer'
      deskId: 'desk-uuid',
      messageId: 'msg-uuid'
    }
  }
}
```

### blob_chunk
```javascript
{
  type: 'blob_chunk',
  blobId: 'uuid-v4',
  to: { deviceId: 100 },
  payload: {
    index: 0,
    data: 'base64-encoded-chunk...',
    size: 65536
  }
}
```

### blob_end
```javascript
{
  type: 'blob_end',
  blobId: 'uuid-v4',
  to: { deviceId: 100 },
  payload: {
    checksum: 'sha256:abc123...',
    totalReceived: 1048576
  }
}
```

### blob_ack (선택적)
```javascript
{
  type: 'blob_ack',
  blobId: 'uuid-v4',
  to: { deviceId: 1 },
  payload: {
    receivedChunks: [0, 1, 2],  // 수신 완료된 청크
    missingChunks: []           // 누락된 청크 (재전송 요청)
  }
}
```

---

## 구현 우선순위

### Phase 1: 기본 다운로드
1. Pylon에서 blob_start/chunk/end 전송
2. Client에서 수신 및 조립
3. 이미지 표시 (인라인 또는 다이얼로그)

### Phase 2: 진행률 및 에러 처리
1. 진행률 UI
2. 청크 누락 감지 및 재요청
3. 타임아웃 처리

### Phase 3: 업로드
1. Client에서 파일 선택
2. 청크 분할 및 전송
3. Pylon에서 수신 및 저장

### Phase 4: 최적화
1. Binary 프레임 지원
2. 압축 옵션
3. 병렬 청크 전송

---

## 기술 검토 사항

### WebSocket Binary Frame
- ws 라이브러리: 지원됨
- web_socket_channel (Flutter): 지원됨
- Relay 통과: 확인 필요

### Base64 vs Binary
| 방식 | 크기 오버헤드 | 호환성 | 구현 복잡도 |
|------|--------------|--------|------------|
| Base64 | +33% | JSON 호환 | 낮음 |
| Binary | 0% | 별도 처리 필요 | 중간 |

### 청크 크기
- 64KB: 일반적인 선택, 메모리 효율적
- 1MB: 전송 효율 높음, 메모리 부담
- 권장: 64KB (모바일 고려)

### 메모리 관리
- 스트리밍 조립: 청크를 파일로 직접 쓰기
- 버퍼 조립: 메모리에 누적 후 한번에 처리
- 권장: 작은 파일은 버퍼, 큰 파일은 스트리밍

---

## 구현 상태

### Phase 1: 기본 이미지 업로드 (2026-01-26 완료)

**선택: Option A (청크 메시지 방식)**

#### 변경된 파일

**estelle-shared:**
- `index.js` / `index.d.ts`: Blob 메시지 타입 추가 (blob_start, blob_chunk, blob_end, blob_ack, blob_request)

**estelle-app (Flutter):**
- `pubspec.yaml`: image_picker, path, crypto, uuid, mime 패키지 추가
- `lib/data/services/blob_transfer_service.dart`: Blob 송수신 서비스 (신규)
- `lib/ui/widgets/chat/input_bar.dart`: + 버튼 및 이미지 선택 UI 추가
- `lib/ui/widgets/chat/message_bubble.dart`: 이미지 표시 지원
- `lib/data/models/claude_message.dart`: AttachmentInfo 추가
- `lib/state/providers/relay_provider.dart`: BlobTransferService provider 추가

**estelle-pylon:**
- `src/blobHandler.js`: Blob 수신 및 저장 핸들러 (신규)
- `src/index.js`: Blob 핸들러 연동, Claude 이미지 경로 전달

**.gitignore:**
- `estelle-pylon/uploads/` 추가

#### 동작 방식

1. 클라이언트에서 + 버튼 클릭 → 이미지 선택
2. 이미지를 로컬 앱 폴더에 복사 (`Documents/estelle/images/`)
3. 동일 PC면 경로만 전달, 아니면 Blob 청크로 전송
4. Pylon에서 수신 후 `uploads/{conversationId}/` 에 저장
5. Claude에 `[첨부된 이미지: /path/to/image]` 형식으로 메시지 전달
6. Claude의 Read 도구로 이미지 읽기 가능

---

## 다음 단계

1. [x] Option 선택 (A: 청크 메시지 방식)
2. [ ] WebSocket binary frame Relay 통과 테스트 (현재 Base64 사용)
3. [x] 프로토타입 구현 (Client → Pylon 이미지)
4. [x] Flutter 이미지 표시 UI
5. [ ] 에러 처리 및 재시도 로직
6. [ ] Pylon → Client 이미지 전송 (역방향)
7. [ ] 진행률 UI
8. [ ] 압축 옵션

---

## 참고

- [WebSocket Binary Data](https://developer.mozilla.org/en-US/docs/Web/API/WebSocket/binaryType)
- [Chunked Transfer Encoding](https://en.wikipedia.org/wiki/Chunked_transfer_encoding)
- [Tus Protocol](https://tus.io/) - 재개 가능한 업로드 프로토콜

---

*Created: 2026-01-25*
