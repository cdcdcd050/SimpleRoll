# SimpleRoll TODO

## CHAT_MSG_LOOT 파싱으로 롤 결과 추적 (TBC 호환)

TBC 클래식에서는 C_LootHistory API가 없어서 누가 입찰/차비를 눌렀는지 실시간 추적이 불가능하다.
대안으로 CHAT_MSG_LOOT 이벤트를 파싱하면 최종 굴림 결과를 추적할 수 있다.

### 채팅 메시지 예시
- koKR: "PlayerName님이 입찰 주사위를 굴려 [아이템]에 52를 획득했습니다"
- enUS: "PlayerName rolls Need for [Item]: 52"

### 구현 시 고려사항
- 로케일별 메시지 포맷이 다름 (koKR / enUS / deDE 등) -> 패턴 매칭 복잡
- 실시간이 아닌 결과만 추적 가능 (버튼 누른 시점 X, 서버가 결과 발표할 때 O)
- "누가 Need를 눌렀다"는 알 수 없고 "누가 몇을 굴렸는지" 최종만 알 수 있음
- LOOT_AWARDED_LOG 같은 별도 이벤트가 TBC에 있는지도 확인 필요

### 구현 방법
1. CHAT_MSG_LOOT 이벤트 등록
2. 메시지에서 플레이어명, 아이템 링크, 주사위 수치, 타입(Need/Greed) 파싱
3. activeRolls의 해당 슬롯에 결과 표시
4. HAS_LOOT_HISTORY가 false일 때만 이 폴백 사용
