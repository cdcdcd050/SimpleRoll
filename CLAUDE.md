# SimpleRoll

WoW TBC 클래식 전용 그룹 롤(Need/Greed/Pass) UI 교체 애드온. 단일 파일 `SimpleRoll.lua`.

## 기능
- 블리자드 `GroupLootFrame` 숨기고 세로 나열형 커스텀 UI로 교체
- 슬롯: 아이콘 + 등급색 이름 + 입찰/차비/포기 버튼 + 고정 금색 타이머 바
- 선택/타임아웃 후 `CLOSE_DELAY`(3초) 뒤 자동 닫힘 (X버튼 없음)
- 프레임 드래그 이동, 위치 SavedVariables 저장
- koKR 기본, 영어 폴백

> **일괄 버튼 (모두 입찰/차비/포기)**: v1.3.0에서 버그로 제거됨. 추후 재구현 예정. 기존 코드는 `SimpleRoll_MassRoll.lua.disabled`에 보존 (TOC 미로드).

## 슬래시
- `/srsr` — 랜덤 3~5개 미리보기 (10초)
- `/srsr reset` — 위치 초기화

## 타이머
- 실제: `GetLootRollTimeLeft(rollID)` ms → `/1000`
- 테스트(rollID ≥ 9000): 고정 10초, `RollOnLoot` 호출 생략

## 코드 구조
- `ApplyRoll` → `MarkRolled` 단일 경로 (개별·일괄 공용)
- 타임아웃은 `MarkTimedOut` 헬퍼 (`SlotOnUpdate` + `CANCEL_LOOT_ROLL` 공용)
- `ReleaseSlot`은 forward declaration

## BoP 롤 확인 (중요)
`RollOnLoot(id, NEED/GREED)`를 **BoP 아이템**에 호출하면 서버가 `CONFIRM_LOOT_ROLL` 이벤트로 재확인을 요구하며, `ConfirmLootRoll(id, rollType)`을 호출해야 실제 롤이 등록된다. 이 처리를 빼먹으면 **파랑·보라 아이템 롤이 서버에 전혀 등록되지 않는** 치명적 버그가 된다 (v1.1.1 fix).

이 애드온은 `GroupLootFrame`을 숨기므로 `CONFIRM_LOOT_ROLL`을 직접 처리한다. 동작은 `SimpleRollDB.instantRoll` 옵션에 따라 갈린다 (v1.4.2):
- **체크(기본)**: 팝업 없이 즉시 `ConfirmLootRoll` — BoP 포함 모든 클릭이 즉시 실행
- **해제**: Blizzard 기본 팝업(`StaticPopup_Show("CONFIRM_LOOT_ROLL", ...)`)을 띄워 블리자드 기본 동작에 위임

버튼 OnClick 자체에는 커스텀 팝업이 없다 — 옵션은 BoP `CONFIRM_LOOT_ROLL` 처리에만 영향.
