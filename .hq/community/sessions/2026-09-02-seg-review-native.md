# 2026-09-02 · seg-review-native (cpp-reviewer, Claude Opus 5, 네이티브 워커)

작업: FLS segmentation PR 2건(stonefish#1 코어 · stonefish_sim#30) main 머지 전 적대적 검증.
근거: ground 4 (저자가 자기 작업을 승인할 수 없다). 세션 모델은 Fable 5.1, 워커는 opus —
같은 벤더라 가족 다양성은 없고 컨텍스트 분리만 얻는다. 그래서 **같은 브리프를 같은 커밋에
대해 codex(oracle 역할, `--backend codex --ground 4`)에도 동시에 보냈다** — 그쪽은 wrapper
ledger에 남으므로 이 파일은 네이티브 워커의 유일한 기록이다.

브리프: 세션 scratchpad `brief_native.md` / `brief_codex.md`(디프 인라인). 검사 항목 A–H
(버퍼 크기 연쇄·GL 바인딩·셰이더 산술·NewDataReady 순서·비segmentation 회귀면·파서 범위·
ROS 층·문서 정합). 보고서: `review_native.md`, `review_codex.md`(둘 다 scratchpad, 비추적).

## 결과 — 두 가족 모두 APPROVE-WITH-NITS, 차단 결함 0

| # | 지적 | 네이티브 | codex | 세션 재검증 |
|:--|:--|:--|:--|:--|
| 1 | `segPBO` 매핑 실패가 index-1 콜백을 막지 않음 → 새 stamp에 초기화 안 된/이전 라벨이 실림 | MINOR | MINOR | 확인 — `OpenGLFLS.cpp:283-298` 가드 2개 독립, `FLS.cpp:146` 값초기화 없음 |
| 2 | `<segmentation>`을 `<robot>`/`<link>`/`<part>`에 두면 경고 없이 무시 | MINOR | (F항에서 범위만 기술) | 확인 — 호출부 `ScenarioParser.cpp:1127·1456·1548` 셋뿐 |
| 3 | `stonefish_ros2/README.md` 소나 토픽 표에 `/fls/segmentation` 행 없음 | MINOR | — | 확인 |
| 4 | `InitGraphics` 재호출 시 `segmentationData` 누수 | NIT | NIT | 확인 — 기존 `displayData`와 동형, `/settings`로는 도달 불가 |
| 5 | 구독자 0일 때도 매 스캔 512 KB 복사·publish | — | MINOR | 확인 — 기존 image/display 경로도 동일하게 무가드 |

**겹친 지적은 #1·#4 두 건** — 2026-08-30 측정(11건 중 겹침 거의 없음)과 달리 이번엔 코드가
작아(+141/+82) 두 가족이 같은 곳을 봤다. 두 보고서 모두 "확인·정상" 항목 A–H 를 함수·줄
번호로 근거를 댔고, 세션이 4건을 직접 코드로 재확인했다.

## 세션 판정(저자)

- #1: 값초기화 `new GLushort[n]()` 적용 — 최악을 "임의 id"에서 "전부 배경"으로 바꾸는 2글자.
  가드 결합(라벨 실패 시 강도 프레임도 드롭)은 **안 함** — segmentation을 안 쓰는 SLAM 구독자에게
  새 프레임 드롭 원인을 만든다.
- #2: CONVENTIONS §2.8 에 "태그가 읽히는 위치" 한 문장 + 코어 CHANGELOG 문구에 `<animated>` 추가.
  robot/link 지원·경고는 범위 밖 — 사용자 결정으로 넘김.
- #3: README 표 행 1개.
- #4·#5: 기존 형제 경로와 동형 — 이 PR 에서 손대지 않음.

적용 여부는 사용자 승인 대기(열린 PR 에 push 하는 외향 행위).
