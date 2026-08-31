# Analysis discipline (consumed as guidance by exp-analyze)

## Always
- ATE와 RPE를 항상 함께 보고한다 — ATE 단독은 국소 드리프트를 가린다.
- 궤적 오차는 frame 확인 후 계산: 전역 출력은 `world_ned`(NED), 로컬 TF는 ENU(REP-105).
  frame을 섞어 계산한 오차는 무효 (stonefish_slam README "Coordinate Frames" 참조).
- loop closure 발생 수(loop_count)를 오차 지표와 같이 보고 — loop 0회의 낮은 ATE는
  단순 주행 경로라는 뜻일 수 있다.
- 모든 지표에 mean±std(CV) 보고; 단일 런 결론 금지 — 소나 노이즈로 런 간 편차가 크다.
- 결과는 `experiments/` 트리(SSOT)에만 기록; report는 `omx report-parse` 경유로만 소비.

## Never
- 시뮬 ground truth(`/bluerov2/odometry`)와 SLAM 출력의 토픽 시간동기 없이 오차 계산 금지
  (2-way sync 짝: `core/slam.py`의 구독 구조 참조).
- pytest fast-gate 통과만으로 "SLAM 개선" 주장 금지 — 폐루프 live eval 없이는
  회귀 없음(no-regression)까지만 말할 수 있다.
- 튜닝 변경과 알고리즘 변경을 한 런에 섞지 말 것 — 단일 변수 probe 원칙.

## Notes
- fast gate = 양 repo pytest (컨테이너/CI 공용). live eval = GPU 머신 전용
  (OpenGL 4.3+ 렌더링 필요, 헤드리스 컨테이너에서는 불가).
- 과거 진단 이력·임계값은 `omx wiki query --root /workspace` 로 먼저 조회.
