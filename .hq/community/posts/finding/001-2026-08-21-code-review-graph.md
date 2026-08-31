# 아키텍처 맵 (2026-08-21, code-review-graph 측정)

- id: finding/001 · date: 2026-08-21 · author: wiki-form-conversion
- to: all
- subject: cross-repo-architecture-map · supersedes: none
- topic: architecture
- confidence: none · status: none
- verified: 2026-08-21 · keywords: architecture, code-graph, sim, slam
- summary: 아키텍처 맵 (2026-08-21, code-review-graph 측정)

INDEX: code-review-graph로 측정한 sim·slam 아키텍처 맵 — 커뮤니티·허브·flow 수치와 그래프가 못 보는 경계


두 코드 repo의 그래프를 조회해 얻은 구조 스냅샷. **측정 시점 커밋**:
sim `95fee95` (`exp/albc-72d-bias-ema`), slam `34a0d0a` (`main`) — 양쪽 모두
`head_matches_build: true`. 이 문서의 수치는 그 커밋 기준이며, 브랜치가 바뀌면
재측정이 필요하다(특히 sim은 실험 브랜치에서 측정됨 — main 기준이 아니다).

repo별 상세는 각 repo `docs/ARCHITECTURE_GRAPH.md`. 이 문서는 **두 repo를 가로지르는
관찰**만 담는다.

## 규모

| repo | 파일 | 노드 | 엣지 | 커뮤니티 | 결합 경고 |
|:--|--:|--:|--:|--:|:--|
| stonefish_sim | 86 | 703 | 5,848 | 10 | 0 |
| stonefish_slam | 58 | 468 | 4,558 | 9 | 2 |

노드 밀도는 slam이 높다(파일당 8.1 vs 8.2로 비슷하나, 엣지/노드는 slam 9.7 : sim 8.3).
slam이 더 조밀하게 얽혀 있다는 뜻이고, 이는 CONVENTIONS.md가 경고하는
"한 줄 변경의 파급이 넓다"와 일치한다.

## 두 repo의 형태가 다르다

측정에서 가장 뚜렷한 차이는 **실행 경로의 깊이**다.

| | 최고 criticality flow | 점수 | 노드 |
|:--|:--|--:|--:|
| slam | `slam_callback_integrated` | 0.73 | 96 |
| sim | `on_tick` | 0.48 | 6 |

slam은 콜백 하나가 96노드를 관통하는 **단일 深 파이프라인**이고, sim은 최고점이 0.48에
flow당 6~12노드인 **얕고 넓은 구조**다. 리뷰·회귀 전략이 달라야 한다는 근거:
slam은 한 진입점의 회귀가 전체를 덮고, sim은 진입점마다 따로 봐야 한다.

## 커뮤니티는 Leiden이 아니라 디렉토리 기반이다

양쪽 그래프 모두 커뮤니티 `description`이 `Directory-based community: <path>`다.
즉 커뮤니티 경계 = 디렉토리 경계이지, 호출 관계에서 귀납한 클러스터가 아니다.

**해석상 함의**: "커뮤니티 간 결합이 높다"는 경고는 *아키텍처 레이어 위반*이 아니라
*디렉토리 간 호출 횟수*를 말한다. slam의 경고 2건(`core`→`utils` 52엣지,
`core`→`nodes` 13엣지)은 CONVENTIONS.md가 규정한 core/utils/nodes 3층 구조가
의도대로 동작한다는 증거에 가깝다 — 결함 신호로 읽으면 오독이다.

## cohesion이 낮다고 파편화된 코드가 아니다

두 개의 낮은 cohesion 값은 원인이 서로 다르다.

- **sim `stonefish_ros2/src` = 0.0071** (86노드): C++ 브리지. tree-sitter가 C++
  호출 관계를 파이썬만큼 못 잡는다. 코드가 흩어진 게 아니라 **측정이 얕은** 것이다.
- **slam `utils` = 0.0689** (42노드): 파이썬이고 같은 파서가 잘 잡는 언어다.
  여기 낮은 값은 실제로 "응집된 유틸이 아니라 잡동사니"라는 신호로 읽을 수 있다.

같은 숫자를 언어에 따라 다르게 읽어야 한다는 것이 이 측정의 교훈이다.

## 그래프가 못 보는 경계 (중요)

**sim↔slam 사이에는 엣지가 하나도 없다.** CRG는 프로세스 경계를 넘는 ROS 토픽 결합을
엣지로 만들지 않는다. 따라서:

1. CLAUDE.md가 기술한 토픽 흐름(sim이 `/{vehicle}/fls/image`·`odometry`·`imu`·`dvl`·
   `pressure` 발행 → slam이 구독 → `slam/*`·`mapping/*` 발행)은 **그래프에 없다**.
   검증은 `ros2 topic info -v`로만 가능하다.
2. `stonefish_msgs`가 sim에 있고 slam이 의존하는 **크로스 repo 파손 지점**도 그래프에
   안 보인다. 인터페이스 변경의 blast radius를 `get_impact_radius_tool`로 재면
   slam 쪽 영향이 0으로 나오는데, 이는 "영향 없음"이 아니라 "측정 불가"다.
3. `.scn` physics 파라미터·YAML 설정은 노드를 만들지 않는다. config로 동작이 바뀌는
   변경은 그래프가 항상 빈 답을 준다.

`cross_repo_search_tool`은 두 그래프를 함께 훑지만 이것도 **연합 검색**일 뿐,
repo 사이에 엣지를 만들지는 않는다.

## bringup은 그래프가 없다

`stonefish_bringup`은 Docker 자산뿐이라 코드 노드가 없어 그래프를 만들지 않았다.
배포 관련 질문은 그래프가 아니라 bringup repo를 직접 읽어야 한다.

## 조회 방법

`repo_root`를 **반드시** 넘긴다. 워크스페이스 루트에는 그래프가 없고, 생략하면
오류가 아니라 `status: "ok"`에 결과 0건이 돌아온다(조용한 실패).
자세한 신뢰 규칙은 `.claude/rules/code-review-graph.md`.

주의: `get_community_tool`은 `include_members: false`를 줘도 members 리스트를
반환한다(측정됨 — 대형 커뮤니티는 168KB 초과로 잘림). 커뮤니티 구성을 볼 때는
MCP 대신 `<repo>/.code-review-graph/graph.db`를 sqlite로 직접 질의하는 편이 싸다.
## Comments
