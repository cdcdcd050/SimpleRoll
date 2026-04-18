# SimpleRoll

WoW TBC 클래식 전용 그룹 롤(Need/Greed/Pass) UI 교체 애드온. 단일 파일 `SimpleRoll.lua`.

## 기능
- 블리자드 `GroupLootFrame` 숨기고 세로 나열형 커스텀 UI로 교체
- 슬롯: 아이콘 + 등급색 이름 + 입찰/차비/포기 버튼 + 고정 금색 타이머 바
- 일괄 버튼: 모두 입찰 / 모두 차비 / 모두 포기
- 선택/타임아웃 후 `CLOSE_DELAY`(3초) 뒤 자동 닫힘 (X버튼 없음)
- 프레임 드래그 이동, 위치 SavedVariables 저장
- koKR 기본, 영어 폴백

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
`RollOnLoot(id, NEED/GREED)`를 **BoP 아이템**에 호출하면 서버가 `CONFIRM_LOOT_ROLL` 이벤트로 재확인을 요구하며, `ConfirmLootRoll(id, rollType)`을 호출해야 실제 롤이 등록된다. 블리자드 `GroupLootFrame`이 이 이벤트를 받아 YES/NO 팝업을 띄우지만, 이 애드온은 해당 프레임을 숨기므로 이벤트를 직접 처리한다 — 모두 입찰/차비 시 아이템 수만큼 팝업이 쌓이면 UX가 무너지고, 애드온 버튼을 누른 것 자체가 이미 명시적 선택이므로 **팝업 없이 즉시 `ConfirmLootRoll`로 자동 확인**한다. 이 처리를 빼먹으면 **파랑·보라 아이템 롤이 서버에 전혀 등록되지 않는** 치명적 버그가 된다 (v1.1.1 fix).
