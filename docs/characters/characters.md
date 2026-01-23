# Estelle 캐릭터 설정

Estelle 시스템의 각 구성요소는 우주/별 테마의 캐릭터로 표현됩니다.

---

## 캐릭터 목록

| 캐릭터 | 아이콘 | deviceId | 역할 | 설명 |
|--------|--------|----------|------|------|
| **Estelle** | 💫 | - | Relay 서버 | 모든 기기를 연결하는 중심 허브. 완벽한 관리자. |
| **Selene** | 🌙 | 1 | 집 PC | 자주 잠들지만 부드러운 휴식을 줌. |
| **Stella** | ⭐ | 2 | 회사 PC | 워커홀릭, 항상 깨어있음. Task DB 담당. |
| **Lucy** | 📱 | 100+ | Mobile | 막내, 능력은 부족하지만 항상 곁에 있음. |

---

## 이름의 의미

- **Estelle** - 프랑스어로 "별" (시스템 전체 이름이자 릴레이 서버)
- **Selene** - 그리스 신화의 달의 여신 (밤에 쉬는 집 PC)
- **Stella** - 라틴어로 "별" (항상 빛나는 회사 PC)
- **Lucy** - 라틴어 "Lux(빛)"에서 유래 (작지만 빛나는 모바일)

---

## 시스템 구성

```
                         ┌─────────────────┐
                         │     Estelle     │
                         │   💫 Relay      │
                         │    (Fly.io)     │
                         └────────┬────────┘
                                  │ WSS (443)
              ┌───────────────────┼───────────────────┐
              │                   │                   │
        ┌─────┴─────┐       ┌─────┴─────┐       ┌─────┴─────┐
        │  Selene   │       │  Stella   │       │   Lucy    │
        │  🌙 집    │       │  ⭐ 회사  │       │  📱 모바일 │
        │ deviceId:1│       │ deviceId:2│       │ deviceId: │
        │           │       │           │       │ 100+      │
        │  Pylon    │       │  Pylon    │       │  Android  │
        │     ↑     │       │     ↑     │       │  App      │
        │  Desktop  │       │  Desktop  │       │           │
        └───────────┘       └───────────┘       └───────────┘
```

---

## Device ID 체계

### 정적 ID (1-99): 미리 정의된 PC

| deviceId | 캐릭터 | deviceType | 설명 |
|----------|--------|------------|------|
| 1 | Selene | pylon | 집 PC |
| 2 | Stella | pylon | 회사 PC |

### 동적 ID (100+): 클라이언트

Desktop, Mobile 등이 접속 시 100 이상의 ID를 사용:
```
deviceId = 100 + random(0-899)
```

---

## Relay 설정

```javascript
// estelle-relay/src/index.js
const DEVICES = {
  1: { name: 'Selene', icon: '🌙', role: 'home', allowedIps: ['*'] },
  2: { name: 'Stella', icon: '⭐', role: 'office', allowedIps: ['*'] },
};
```

---

## UI 표시

### Desktop/Mobile 공통
- 연결된 기기 목록에 캐릭터 아이콘과 이름 표시
- 채팅 메시지에 발신자 캐릭터 아이콘 표시

### 아이콘 Fallback
알 수 없는 deviceId의 경우 deviceType으로 기본 아이콘 적용:
- pylon → 💻
- desktop → 🖥️
- mobile → 📱
- unknown → ❓

---

## 설정 위치

- **Relay**: `estelle-relay/src/index.js` - `DEVICES` 객체
- **Pylon**: `.env` 파일의 `DEVICE_ID` (정수)
- **Desktop**: Pylon에서 deviceInfo 전달받음
- **Mobile**: 동적 ID 자동 할당

---

*"우리는 각자의 빛으로 연결되어 있습니다."*

---

*Last updated: 2026-01-21*
