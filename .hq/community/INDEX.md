# INDEX — stonefish_ws

> 13 posts · regenerated 2026-09-02 by `hq index`

## decision
- `decision/002` [subject: naming-rules-codify] codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산 — codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산
- `decision/004` [subject: docker-env-genesis] docker 환경 자산 생성 관찰 (2026-07-23, omp-env) — docker 환경 자산 생성 관찰 (2026-07-23, omp-env)
- `decision/009` [subject: phase2-deferred-queue] Phase 2 이월 작업 큐 N1~N13 — "지금 당장에만 제외"의 실물 목록 — Phase 2 계획이 이번 사이클에서 뺀 13개 작업의 정본 목록. 사용자가 "제외는 지금 당장만, 끝나면 곧바로 다음"이라는 조건으로 승인했으므로 이 목록은 백로그가 아니라 예약된 다음 사이클이다.
- `decision/013` [subject: sonar-segmentation-label-source] 소나 segmentation 라벨 소스를 .scn class id로 정한다 — lookId·objectId는 파싱 순서 인덱스라 look이나 물체를 하나 추가하면 값이 밀리고, 이미 녹화한 bag의 GT가 에러 없이 오라벨이 된다 — 학습 데이터에선 치명적. 그래서 .scn의 <segmentation class="N"/>로 명시한다. 한 물체가 look 여러 개를 써도 라벨은 하나(turbine base/main). 인스턴스 분리는 connected components에 맡기고 만들지 않는다. 표 정본은 sim docs/CONVENTIONS.md §2.8.

## finding
- `finding/001` [subject: cross-repo-architecture-map] 아키텍처 맵 (2026-08-21, code-review-graph 측정) — 아키텍처 맵 (2026-08-21, code-review-graph 측정)
- `finding/003` [subject: control-mode-volatile-qos] control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다 — control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다
- `finding/006` [subject: omx-bootstrap-smoke] omx bootstrap smoke (container) — omx bootstrap smoke (container)
- `finding/007` [subject: velocity-vs-cascade-cross-track] velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다 — velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다
- `finding/008` [subject: code-health-audit-2026-09] 양 repo 코드 건강 감사 — 37건 적대 검증 결과 (CONFIRMED 29 · PARTIAL 8 · REFUTED 0) — 세 분석(slam 스윕·sim 스윕·localization 심층)의 버그 주장 37건을 발견별 독립 반박 시도로 검증 — 29 확정, 8 부분 성립, 0 반증. 최대 신규 사실: 시뮬 실제 소나 틸트 80° vs slam config 30° 불일치.
- `finding/010` [subject: path-coverage-gaps] 경로 커버리지 공백 — 값이 아니라 도달 가능성이 깨지는 결함 — Phase 3 여섯 브랜치의 결함이 전부 '코드는 맞는데 거기로 가는 길이 없는' 부류였다. 계측이 자기 질문에서만 침묵한 사례, AST 배선 테스트가 통과하며 죽는 구멍 3종, write-only 플래그가 로그를 거짓말하게 만든 사례 — 셋 다 값 검사로는 안 잡힌다. 다음 사이클용 규칙 4개와 판별력 확인법 포함.
- `finding/011` [subject: regression-verification-nondeterministic] 재현되지 않는 시뮬레이터에서 변경의 무해함을 판정하는 법 — 빌드 간 프레임 해시 비교가 0건 일치라 회귀처럼 보였으나 같은 빌드 재실행 대조군도 0건이었다 — 판별력 0인 실험의 음성은 증거가 아니다. 대신 같은 빌드 안에서 위험 변경을 1000배 증폭한 dose-response로 판정(효과 TVD 0.0078 < 잡음바닥 0.0064). 대조군 먼저·비교는 시스템 안에서·구조적 논거 병행이라는 규칙 3개.
- `finding/012` [subject: sonar-segmentation-label-intensity-divergence] 소나 GT 라벨은 부채꼴 가장자리에서 강도와 갈린다 — FLS bin은 샘플을 누적하지 않고 하나만 고르므로 라벨이 잘 정의된다. 다만 수직 부채꼴 가장자리에 스친 물체는 bin 승자가 되어 라벨은 정확히 붙는데 lobe 보정이 강도를 0으로 눌러, GT 마스크가 강도 이미지에 안 보이는 물체를 표시한다(실측: 라벨 13.7m 정확, 강도 0.31 < 배경 0.91). 중앙에 두면 38~70으로 정상. SSS/MSIS는 누적 방식이라 별도 설계 필요.

## review
- `review/005` [subject: git-compliance-review] git 규칙 준수 검토 (2026-07-23, 배포 준비 세션) — git 규칙 준수 검토 (2026-07-23, 배포 준비 세션)
