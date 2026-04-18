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
