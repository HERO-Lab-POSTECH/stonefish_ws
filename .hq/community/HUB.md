# object_detection_to_2d_mapping — 목표물 인식·3D 복원·위치 인식 검증 라인

<!-- The prose half of the board. board.json is what hooks read; this is what people
     read. Keep them consistent: a decision recorded here that contradicts the board
     is a bug in one of the two. -->

## Goal

이 워크트리의 장기 목표: 목표물 인식(완료, sim `stonefish_sonar_yolo` + slam CFAR) 위에
3D 복원(PCL XYZI처럼 3D 좌표+index)을 얹고, 위치 인식 알고리즘(FFT/ICP/DL)을 검증해
최종 파이프라인을 구현한다. 그 전제 작업으로 이번 세션은 (1) 코드 정리·버그 수정,
(2) `.hq` 최신화, (3) `.graphify` 최신화를 수행한다. "done" = 양 repo 테스트 초록 +
정리·수정 커밋 머지 가능 상태 + 두 인덱스 최신.

## The request, verbatim

> 위 작업을 진행하기 전에 전체적인 코드 정리와 .hq 및 .graphify 업데이트를 이번
> 세션에서 진행.
> Goal. 1. 코드 정리 및 버그 수정. 2. .hq 폴더 최신화. 3. .graphify 폴더 최신화.
> Process. 1. 코드 분석(omc·graphify 최대 활용, omo cross model 활용, 결과로 .hq·
> .graphify 1차 최신화·문서화, compact) 2. 코드 정리·버그 수정 계획 수립(기업 표준
> 정리·모듈화·단순화, 버그 수정 계획, 문헌·인터넷 조사로 고도화 검토, 사용자 검토
> 요청, compact) 3. 구현 4. .hq·.graphify 최신화. 코드 수정 시 중요 분기마다 git
> commit으로 관리.

## Decisions

| # | Date | Decision | Because | Reversal cost | By |
|:--|:-----|:---------|:--------|:--------------|:---|
| D1 | 2026-09-01 | cross-model 상담은 Claude 티어 분리(fable 세션 ↔ opus 분석 ↔ sonnet 스윕)로 수행 | 이 머신에 vendor CLI가 claude뿐(codex·agy·gemini 미설치), CLI 설치는 사람 결정 | 낮음 — CLI 설치 시 vendor 상담으로 전환 | Claude(세션) |
| D2 | 2026-09-01 | omo 스토어 층(rules/·HUB.md·agents/·sessions/)을 `.hq/community/`에 시드 | 8/31 omp·omx 통합 때 omo 층은 시드된 적 없음 — 사용자 지적으로 발견 | 없음 (추가만) | 사용자 지시 |
| D3 | 2026-09-01 | codex·agy 설치 완료 — 이후 상담은 wrapper 경유 cross-vendor로 전환 (D1 대체) | D1의 전제(claude-only)가 소멸. 벤더 로더 설치·인증 실측은 다음 세션 프리플라이트에서 | 낮음 — CLI 제거 시 D1 방식 복귀 | 사용자 |
| D4 | 2026-09-01 | 벤더 로더를 프로젝트 스코프로 설치 — codex `.codex/config.toml`+skills, agy `.agents/skills/` | omo `shared-context.md` 절차. agy는 project scope만 가능(user scope `~/.agents/`는 모든 에이전트 공용이라 오염) | 없음 (추가만, git 미추적) | Claude(세션) |
| D5 | 2026-09-01 | codex는 `yolo:true` role로만 라우팅한다 | 이 컨테이너에서 bubblewrap이 namespace를 못 만들어 샌드박스 경로의 codex는 파일을 하나도 못 읽으면서 에러 대신 "unavailable"만 답한다(조용한 실패). `explore`·`security`(yolo:false)는 사람이 `~/.codeagent/models.json`을 고쳐야 살아난다 | 낮음 — models.json 1줄 | Claude(세션, 실측) |
| D6 | 2026-09-01 | 소나 틸트(config 30° vs 실물 80°) 코드 처방을 이번 사이클에서 **보류**하고 계측(I11)을 먼저 붙인다 | 적대 검증 LOC-3: 평탄 해저 무보정 ICP는 병진을 **과소** 추정하며 `cos(tilt)` 곱은 오차를 악화(30°: 0.89→0.77, 80°: 0.18→0.03). 문헌 조사의 "저비용 cos 보정" 권고를 세션이 기각 | 낮음 — 계측 결과가 나오면 그때 처방 | Claude(세션), 사용자 승인 대기 |
| D7 | 2026-09-01 | god-method 분해(§4.4)와 SSM/NSSM 중복 통합(§4.2)을 이번 사이클에서 **제외** | 특성화 테스트 선작성이 그 자체로 한 사이클 분량이고, 버그 수정과 섞으면 회귀 원인 분리가 불가능 | 중 — 다음 사이클로 예약 | Claude(세션), 사용자 승인 대기 |
| D8 | 2026-09-01 | Phase 2 계획 승인. 새 브랜치는 **PR #16·#24 선머지 후 `main`**, `blueboat_sea.scn`은 교체가 아니라 **삭제** | 두 PR은 몇 줄짜리 빌드 경고 수정이라 선머지가 리뷰 diff를 깨끗하게 한다. blueboat 시나리오는 include 가 깨져 **한 번도 launch 된 적이 없어** 삭제해도 잃는 동작이 없고, 어느 world 를 의도했는지 코드로 확정 불가한 상태의 추측 교체는 검증된 적 없는 씬을 새로 만들 뿐이다 | 낮음 | 사용자 |
| D9 | 2026-09-01 | D6·D7을 포함한 **제외 항목 전건은 "지금 당장에만 제외"** — 이번 사이클 완료 즉시 다음 사이클로 진행한다 | 사용자 명시 조건부 승인. 조용한 탈락을 막기 위해 계획 §8에 N1~N13으로 예약하고, **§7.4 완료 판정에 "N1~N13 등재 확인"을 항목으로 넣었다** — 등재 없이 사이클을 닫으면 승인 조건 위반 | 없음 (약속) | 사용자 |
| D10 | 2026-09-01 | **Phase 3 사이클 종료** — 6브랜치 전건 머지, D9 의 "N1~N16 등재 확인" 조건 해소. 다음 사이클은 N7 → N8 → N3 순 | §7.4 완료 판정 5항목 전부 충족(slam 113 · sim 224 passed · 게이트 pass · 열린 PR 0건 · 이월 큐 16행 실측). D6·D7 이 보류한 것은 각각 N1·N7/N8 로 살아 있어 조용한 탈락이 없다 | 없음 (기록) | Claude(세션), 사용자 머지 승인 |
| D11 | 2026-09-02 | 검출→위치인식 통합 = **A. 랜드마크 factor** `BearingRangeFactor2D(X(k), L(j))`, 측정값은 **bbox 중심 픽셀**의 (bearing, range) | 사용자 초기 선호는 C(라벨 가중 ICP). 실측: 스테이징 `pcl.so` 에 `GenericDescriptorOutlierFilter` 가 등록돼 yaml 은 로드되지만 `ICP.compute` 가 descriptor 를 안 넘겨 `Field label not found` — C++ 오버로드+재빌드 필수. stock 필터는 한쪽 descriptor 값 가중뿐(매칭 쌍 클래스 일치 비교 아님), 증거가 ICP 내부라 관측 어려움. A 는 Python 만·카운터+마커로 관측. bbox 중심 측정은 "bbox 안 CFAR peak 0 → factor 0"(검토 M8) 을 구성상 제거해 검출 1건 ⇒ factor 1건 | 중 — C-lite 는 배타적이지 않아 후속 PR 로 추가 가능 | 사용자 |
| D12 | 2026-09-02 | 검출 인터페이스 = **1-a** 별도 노드 유지 + `vision_msgs/Detection2DArray`(이미지 header 복사) 발행, JSON `String` 토픽 제거 | 현 JSON 에 stamp 가 없어 어느 프레임의 검출인지 SLAM 이 알 수 없음(구독자 0 이라 제거 무해). 노드 분리 아키텍처 유지, sim PR ↔ slam PR 상호 링크(CONTRIBUTING §5) | 낮음 | 사용자 |
| D13 | 2026-09-02 | 검증 = **(b) 결정적 fake `Detection2DArray` 주입기 e2e 가 첫 acceptance**, (a) sofa 씬 확보·새 bag·YOLO 실검출은 별도 데모 마일스톤(bringup ultralytics 포함) | 시뮬 씬 11개 .scn 어디에도 sofa 자산 없음, 이 컨테이너에 ultralytics 미설치. 검출기 성능은 "검출 결과가 소비되는가"의 전제가 아님(codex 검토 m10). 가짜 검출 결과임은 A/B 표에 명기 | 낮음 | 사용자 |
| D14 | 2026-09-02 | `semantic.enable:false` 는 **오늘과 스키마·토픽·로그 형식까지 동일** — `PointCloudXYZIL`·`/mapping/cloud_3d`·새 `[INSTR]` 줄은 on 전용, off 스키마는 골든 테스트로 고정 | codex 적대 검토 B1: 초안은 off 에서도 cloud 필드·point_step 이 바뀌어 A/B 기준선과 기존 소비자를 깼다. 10건 검토 전부 코드 재확인 후 채택(PLAN §9) | 낮음 | Claude(세션), 검토 채택 |

Append only. Numbers are globally monotonic and never reused. An overturned decision
gets a new row naming the one it supersedes; the original stays so the reasoning
trail survives. Protocol: `decision-record` skill.

## Workers

세션별 워커 기록은 `sessions/<YYYY-MM-DD>-<worker>.md`, 역할 카드는 `agents/<role>.md`.
