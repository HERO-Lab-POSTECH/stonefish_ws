# INDEX — stonefish_ws

> 10 posts · regenerated 2026-09-01 by `hq index`

## decision
- `decision/002` [subject: naming-rules-codify] codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산 — codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산
- `decision/004` [subject: docker-env-genesis] docker 환경 자산 생성 관찰 (2026-07-23, omp-env) — docker 환경 자산 생성 관찰 (2026-07-23, omp-env)
- `decision/009` [subject: phase2-deferred-queue] Phase 2 이월 작업 큐 N1~N13 — "지금 당장에만 제외"의 실물 목록 — Phase 2 계획이 이번 사이클에서 뺀 13개 작업의 정본 목록. 사용자가 "제외는 지금 당장만, 끝나면 곧바로 다음"이라는 조건으로 승인했으므로 이 목록은 백로그가 아니라 예약된 다음 사이클이다.

## finding
- `finding/001` [subject: cross-repo-architecture-map] 아키텍처 맵 (2026-08-21, code-review-graph 측정) — 아키텍처 맵 (2026-08-21, code-review-graph 측정)
- `finding/003` [subject: control-mode-volatile-qos] control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다 — control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다
- `finding/006` [subject: omx-bootstrap-smoke] omx bootstrap smoke (container) — omx bootstrap smoke (container)
- `finding/007` [subject: velocity-vs-cascade-cross-track] velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다 — velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다
- `finding/008` [subject: code-health-audit-2026-09] 양 repo 코드 건강 감사 — 37건 적대 검증 결과 (CONFIRMED 29 · PARTIAL 8 · REFUTED 0) — 세 분석(slam 스윕·sim 스윕·localization 심층)의 버그 주장 37건을 발견별 독립 반박 시도로 검증 — 29 확정, 8 부분 성립, 0 반증. 최대 신규 사실: 시뮬 실제 소나 틸트 80° vs slam config 30° 불일치.
- `finding/010` [subject: path-coverage-gaps] 경로 커버리지 공백 — 값이 아니라 도달 가능성이 깨지는 결함 — Phase 3 여섯 브랜치의 결함이 전부 '코드는 맞는데 거기로 가는 길이 없는' 부류였다. 계측이 자기 질문에서만 침묵한 사례, AST 배선 테스트가 통과하며 죽는 구멍 3종, write-only 플래그가 로그를 거짓말하게 만든 사례 — 셋 다 값 검사로는 안 잡힌다. 다음 사이클용 규칙 4개와 판별력 확인법 포함.

## review
- `review/005` [subject: git-compliance-review] git 규칙 준수 검토 (2026-07-23, 배포 준비 세션) — git 규칙 준수 검토 (2026-07-23, 배포 준비 세션)
