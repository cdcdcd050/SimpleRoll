# SimpleRoll

## 개요
- **제작자**: CH00
- **용도**: WoW TBC 클래식 전용 그룹 롤(Need/Greed/Pass) UI 교체 애드온
- **참고**: BlockyLootFrame의 컨셉을 참고하되 코드는 완전히 새로 작성 (라이센스 문제 없음)
- **저장 방식**: SavedVariables (계정 공용, 캐릭별 아님)

## 파일 구조
```
SimpleRoll/
├── SimpleRoll.toc      -- TBC(20505) 전용
├── SimpleRoll.lua       -- 전체 코드 (단일 파일)
├── CLAUDE.md            -- 이 문서
└── TODO.md              -- 추후 구현 예정 기능
```

## 핵심 기능
- 블리자드 기본 GroupLootFrame 숨기고 커스텀 UI로 교체
- 하나의 메인 프레임에 여러 롤 아이템을 세로로 나열
- 각 아이템: 아이콘 + 등급 색상 이름 + 입찰/차비/포기 버튼 + 타이머 바
- 버튼 클릭 시 개별 슬롯 유지 (전부 선택 완료 후 1.5초 뒤 일괄 닫힘)
- **모두 차비** 버튼 (전체 차비) + **모두 포기** 버튼 (전체 포기)
- 프레임 드래그 이동 (헤더 + 슬롯 영역 모두 가능)
- 위치 SavedVariables로 저장/복원
- 한글 UI 기본 (koKR), 영어 폴백

## 슬래시 명령어
- `/srsr` — 미리보기 (랜덤 3~5개 아이템, 10초 타이머)
- `/srsr reset` — 위치 초기화
- `/simpleroll` — 위와 동일

## UI 레이아웃
```
┌─────────────────────────────────────┐
│                                     │
│ [아이콘] 아이템이름  [입찰][차비][X]│ ← 슬롯
│ ▓▓▓▓▓▓▓▓░░░ 45초                   │ ← 타이머
│ [아이콘] 아이템이름  [입찰][차비][X]│
│ ▓▓▓▓▓▓▓▓░░░ 45초                   │
│ [모두 차비] [모두 포기]             │ ← 하단 버튼
└─────────────────────────────────────┘
```

## 디자인
- **배경**: `Interface\DialogFrame\UI-DialogBox-Background`
- **테두리**: `Interface\DialogFrame\UI-DialogBox-Gold-Border` (금색 클래식)
- **버튼**: 블리자드 기본 `UI-GroupLoot-Dice/Coin/Pass-Up`
- **타이머 바**: 초록(>50%) → 노랑(>25%) → 빨강 색상 전환
- **슬롯 테두리 + 아이콘 배경**: 아이템 등급 색상 반영
- **프레임 너비**: 298px
- **툴팁**: 각 슬롯 바로 위에 표시 (`ANCHOR_TOP`), 비교 툴팁은 WoW 자동 배치. 버튼에는 툴팁 없음

## 버튼 배치
- **슬롯 내 (왼→오)**: 입찰(주사위) → 차비(동전) → 포기(X)
- **하단 (왼→오)**: 모두 차비(파란색) → 모두 포기(빨간색)

## 닫힘 조건
1. **X 버튼 클릭** — 수동으로 모든 슬롯 닫기 (UIPanelCloseButton)
2. **타이머 만료 (미선택)** — 시간 초과 시 슬롯 제거, 마지막 슬롯이면 창 닫힘
3. **롤 완료(C_LootHistory, WotLK+)** — 승자 결정 후 5~8초 뒤 슬롯 만료
4. **롤 완료(CHAT_MSG_LOOT, TBC)** — 승자/전원포기 결과 수신 후 30초 뒤 자동 닫힘
5. **CANCEL_LOOT_ROLL 이벤트** — 미선택 시 즉시 제거, 선택 완료 시 30초 대기 (TBC)
6. **테스트 롤** — 모든 슬롯 선택 완료 시 1.5초 후 정리

## 롤 결과 추적 (클라이언트별 분기)

### WotLK 3.3+ (C_LootHistory API 존재)
- 내 선택 후 슬롯 유지, 카운터/상태 텍스트 표시
- 다른 플레이어 선택 시 버튼 카운터 업데이트
- 롤 완료 시 승자 표시 후 5~8초 뒤 자동 만료
- 이벤트: `LOOT_HISTORY_ROLL_CHANGED`, `LOOT_HISTORY_ROLL_COMPLETE`

### TBC (C_LootHistory 없음 → CHAT_MSG_LOOT 파싱)
- 버튼 클릭 → 비활성화 + 상태 표시, 슬롯 유지 (닫지 않음)
- 서버 타이머 만료 후에도 슬롯 유지 (결과 대기)
- `CHAT_MSG_LOOT` 메시지 파싱으로 롤 결과 추적:
  - `GlobalStringToPattern()`: WoW 글로벌 문자열을 Lua 패턴으로 변환 (한글 `|1X;Y;` 문법 입자 처리)
  - 개별 롤 결과 (Need/Greed/Pass) → `입찰:2  차비:1  포기:1` 형태로 상태 텍스트 업데이트
  - 승자 결정 (`LOOT_ROLL_WON`) → 승자 이름 표시 + 30초 카운트다운
  - 전원 포기 (`LOOT_ROLL_ALL_PASSED`) → "전원 포기" 표시 + 30초 카운트다운
- `CANCEL_LOOT_ROLL` 수신 시: 이미 선택한 슬롯은 제거하지 않고 30초 대기 (채팅 결과 수신 기회)
- 30초 카운트다운: 타이머 바를 파란색으로 재활용하여 잔여 시간 표시
- 이벤트 등록: `SafeRegisterEvent` (pcall 래핑)

## 타이머
- **실제 롤**: `GetLootRollTimeLeft(rollID)`로 서버에서 남은 시간(ms) 수신, `/1000` 변환
- **테스트 롤(`/srsr`)**: 고정 10초

## 테스트 롤 vs 실제 롤
- 테스트: rollID 9000+ → `RollOnLoot` 호출 안 함, `GetItemInfo`로 실제 아이템 데이터
- 실제: `START_LOOT_ROLL` 이벤트 → `GetLootRollItemInfo` + `RollOnLoot`
- UI 렌더링 코드(`AddRoll`, `AcquireSlot`, `UpdateLayout`)는 동일 경로

## 코드 구조 주의사항
- `ReleaseSlot`은 forward declaration 사용 (`local ReleaseSlot` 선언 후 하단에서 함수 할당)
  - 상단의 모두 포기/모두 차비 콜백에서 참조하기 때문

## 추후 구현 (TODO.md 참조)
- 드래그로 프레임 크기 조정
