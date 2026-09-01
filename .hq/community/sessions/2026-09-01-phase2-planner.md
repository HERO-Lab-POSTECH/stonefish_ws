# 2026-09-01 · phase2-planner (Claude Opus 5, 세션 워커)

작업: Phase 2 — P4_FLAGS 갱신 패스 + 코드 정리·버그 수정 계획 수립.
산출물: `.sp/plans/2026-09-01-code-cleanup-and-bugfix.md`,
`.hq/work/project/audit-2026-09-01/lit-sonar-localization.md`,
양 repo `P4_FLAGS.md` 갱신.

## 프리플라이트 실측 (D3의 전제 확인)

| 항목 | 결과 |
|:--|:--|
| `codeagent-wrapper` | `/root/.local/bin` → `/root/go/bin` 심링크, `--version`은 `dev`(0.21.6 소스 빌드) |
| `codex` | `/usr/bin/codex`, 인증 OK |
| `agy` | `/root/.local/bin/agy`, 인증 OK |
| omo 스토어 | `.hq/community/` 시드 완료(rules 5 · HUB · agents · sessions) |
| codex 로더 | 이 세션에서 설치 — `.codex/config.toml` + `.codex/skills/{context-loader,decision-record}` |
| agy 로더 | 이 세션에서 설치 — `.agents/skills/{context-loader,decision-record}` |
| 로더 실효성 | **양 백엔드 실측 통과** — rules 5개·HUB Decisions 3행·`finding/008` 파일명을 정확히 회수. codex는 `language.md`대로 한국어로 응답 |

### 프리플라이트가 발견한 조용한 퇴화 2건

1. **`~/.codeagent/models.json` 부재.** 이전 세션이 바이너리만 0.21.6으로 올리고 설정 층을
   설치하지 않아 첫 `--agent explore` 호출이 `models config not found`로 죽었다.
   `templates/models.json.example` 기준으로 생성(7 role + agy 백엔드 추가).
2. **codex의 bubblewrap 샌드박스가 이 컨테이너에서 동작하지 않는다**
   (`No permissions to create a new namespace`). 샌드박스 경로로 돌면 codex는 파일을 하나도
   못 읽으면서 에러 대신 "unavailable"만 답한다 — 전형적 silent failure. wrapper의
   `yolo:true` role(`develop`·`oracle`·`librarian`)은 `--dangerously-bypass-approvals-and-sandbox`가
   붙어 정상 동작하므로 그쪽으로 라우팅해 우회했다.
   ⚠️ **남은 제약**: `models.json`의 `explore`·`security`가 `yolo:false`라 두 role은 양 백엔드
   모두에서 파일을 못 읽는다. 수정하려면 프로젝트 밖(`/root/.codeagent/`) 쓰기가 필요한데
   Claude Code auto-mode classifier가 막는다 — 사람이 직접 고쳐야 한다.

## 이 세션의 벤더 호출 (전부 ground 명시)

| ground | role/backend | 목적 | 결과 |
|:--|:--|:--|:--|
| 2 | `explore`/codex | 스토어·로더 실효성 프로브 | 샌드박스 실패로 read 0 — 위 퇴화 2 발견 |
| 4 | `oracle`/agy | 같은 프로브 | 전건 정확 회수 |
| 2 | `develop`/codex | 같은 프로브 (yolo 경로) | 전건 정확 회수 |
| 4 | `oracle`/codex + `oracle`/agy | **계획 문서 2-family 적대 검증** | 아래 |
| — | OMC `document-specialist`(sonnet) | FLS localization 문헌 조사 | 인용 27건, 전부 arXiv id/DOI/URL 실조회 |

**2-family 게이트를 연 근거**: 이 계획은 양 repo에 5개 PR을 내는 release급 변경 범위이고,
P0-4(C++ 옥트리 log-odds)·P1-8(프로파일링 수집 삭제)은 되돌리기 비싼 축에 든다.
omo SKILL.md의 게이트 조건("release에 실린다 / 데이터 손실 경로 / 되돌리기 어렵다")에 걸린다.

## 세션이 벤더/에이전트 출력을 뒤집은 곳 (기록)

문헌 조사 에이전트는 weakness #1(slant-range 미보정)의 처방으로 "FFT가 쓰는 `cos(tilt)`를
ICP 점군에도 적용"을 **저비용**으로 권고했다. **세션이 이를 기각했다** — 적대 검증(LOC-3)이
평탄 해저에서 무보정 ICP는 병진을 **과소** 추정하고 `cos` 곱은 오차를 악화시킨다고 판정했고
(30°: 0.89→0.77, 80°: 0.18→0.03), 무엇보다 실물 틸트가 80°인데 config가 30°라 어떤 cos
보정도 실 기하와 무관하다. 에이전트는 그 교정을 알지 못한 채 "세 소비자 스케일 정합"이라는
논리만으로 판정했다. 계획 §6.3에 기각 근거를 명시했다.

## P4_FLAGS 갱신 패스에서 실측으로 뒤집힌 것

| 대상 | P4_FLAGS 기록 | 2026-09-01 실측 |
|:--|:--|:--|
| sim `ilos_guidance.compute_guidance` | 319줄 god-method | **66줄** — 분해 완료, 종결 |
| sim `lipb_interpolator.init_interpolator` | 152줄 god-method | **26줄** — 분해 완료, 종결 |
| sim `los_guidance.py::update` | 177줄 god-method | **파일 자체가 없음** — 유령 항목 |
| sim `path_following_node.__init__` | 170줄 | **199줄** — 열림, **악화** |
| sim VelocityProfiler dead 분기 | cs 14 · lipb 15 | **cs 14 · lipb 14 · `common/trajectory_generator` 6** (참조 줄 수 기준). 첫 갱신에서 세션이 "cs 7 · lipb 7"로 적었으나 **어떤 계수 규칙으로도 재현 안 됨** — 독립 검증(2026-09-01)이 잡아내 정정했다. 원 기록의 "14"가 오히려 맞았고 진짜 누락은 `trajectory_generator` 6줄 |
| sim velocity/unified controller node, teleop_manager | 백로그 항목 | **삭제됨** — 3항목 종결 |
| slam `utils/` `__all__` 부재 | 5개 파일 | **7개 전부** |
| slam `localization.yaml` icp_config | `:29` | **`:30`** (줄 drift) |
| sim `blueboat_sea.scn` 깨진 include | `:3` (finding/008) | **`:4`** (주석이 3행) |

## 세션 종료 상태 (2026-09-01)

**사용자 승인 완료.** D-A = PR #16·#24 선머지 후 `main`, D-B = `blueboat_sea.scn`
**삭제**(교체 아님 — include 가 깨져 한 번도 launch 된 적이 없음), 제외 전건 승인
**단 "지금 당장에만"** — 이번 사이클 완료 즉시 다음으로 진행. HUB D8·D9,
`posts/decision/009`(N1~N13 정본 목록)로 못 박았다.

### 커밋 (전부 미push)

| repo | 브랜치 | 커밋 |
|:--|:--|:--|
| meta | `luckkim123/object_detection_to_2d_mapping` | `9fc9f7b` D4~D7 · `aee663c` finding/008 Comments · `14e796b` D8·D9 · (+ decision/009) |
| sim | `docs/p4-flags-refresh` | `986d2fc` |
| slam | `docs/p4-flags-refresh` | `8a2090d` |

### 2-family 게이트 결과 — 겹치지 않았다

codex와 agy에 **같은 프롬프트·같은 트리**로 동시 발주했고 둘 다 `REQUEST CHANGES`.
겹친 지적은 2건(PR 분할 누락, CONFIRMED 조용한 탈락)뿐이고 나머지는 서로 달랐다:

- **agy 단독**: P0-3의 단순 try/except가 factor 큐를 오염시켜 ISAM2를 **영구 무력화**한다
  (`factor_graph.py:189-190`의 큐 비우기가 except 경로에서 건너뛰어짐). 가장 값나가는 지적.
- **codex 단독**: P1-8 누수가 `profiling_data` 하나가 아니라 `performance_stats`까지 **둘**,
  P0-4의 포화 서술 부정확, P1-10은 보수성 선택이 아니라 **동작 보존 정리**.
- **둘 다**: P0-1의 평면 키 파싱은 아무것도 파싱 못 함(yaml 이 중첩 libpointmatcher 구조),
  P1-2는 **결함이 아님**.

세션이 리뷰 위에 추가로 발견한 것: P0-1에서 `TrimmedDistOutlierFilter.ratio: 0.8`을
그대로 옮기면 **P4a 에서 이미 고친 버그가 되살아난다**(`pcl.py` 자체 주석이 순수 Python
경로엔 1.0 이 옳다고 명시). 두 리뷰어 모두 "중첩 키를 매핑하라"고 했지만 그 중 하나는
매핑하면 안 되는 키였다 — 벤더 출력을 결과가 아닌 초안으로 다룬 것이 값을 한 지점.

### 다음 세션이 이어받을 것

Phase 3 구현. **착수 전 확인 3건 중 2건은 2026-09-01 세션 후반에 해소됐다.**

| # | 항목 | 상태 |
|:--|:--|:--|
| 1 | PR sim#24 · slam#16 머지 (D8 전제) | **미해소 — 유일한 차단 요인.** 둘 다 OPEN·MERGEABLE, base `main`. 사람이 GitHub 버튼으로 눌러야 한다(본인 PR 자기승인 금지) |
| 2 | `docs/p4-flags-refresh` 두 브랜치 push·PR | **완료** — sim#25 · slam#17 |
| 3 | `models.json` 의 `explore`·`security` yolo 플래그 | **완료** — 사용자가 직접 7개 role 전부 `yolo:true` 로 수정. ⚠️ codex 샌드박스 자체는 여전히 이 컨테이너에서 안 뜬다. `yolo:false` 인 role 을 새로 추가하면 같은 조용한 실패가 재발한다 |

### 머지·검증 기록 (2026-09-01 오후)

**sim#24 · slam#16 머지 완료** (사용자 명시 승인). 저자와 별개 패스로 검증한 뒤 머지했다 —
클린 빌드(`--cmake-clean-first`) 비교로 `main` 8건 → `fix/build-warnings` **0건**,
양쪽 exit=0. 머지 커밋 sim `3b237ae` · slam `ef8529d`. **D8 전제 해소 — Phase 3 착수 가능.**

⚠️ **경고 계수 함정**: `grep -ciE "warning:"`(콜론 포함)은 CMake/PCL이 내는
`** WARNING ** io features related to pcap will be disabled`를 **놓친다**. 콜론 없는 형식이라
sim#24가 표방한 바로 그 경고가 집계에서 빠졌고, 하마터면 "PR이 표방한 걸 안 한다"고
오판할 뻔했다. 경고 비교는 콜론 없는 형식까지 포함해 세야 한다.

⚠️ **`add_link_options`(slam CMakeLists)는 CMake 3.13+ 명령인데 `cmake_minimum_required`는
3.8을 선언한다.** 설치본이 3.22라 지금은 동작하지만 선언과 실요구가 어긋나 있다 — 별건 이월.

**세션 자신의 P4_FLAGS 정정에서 오류 1건 발견.** 문서 PR 2건은 이 세션이 작성했으므로
자기승인을 피해 수치 주장 11건을 독립 검증(OMC verifier, sonnet)에 걸었다. 10건 CONFIRMED,
**1건 반증** — `cs 7곳 · lipb 7곳`이 어떤 계수 규칙으로도 재현되지 않았다(if 문 5·5·3,
중첩 포함 6·6·3). 실측은 참조 줄 수 기준 **14 · 14 · 6**이며, 이 PR이 "부정확하다"고
지적한 원 기록의 "14"가 오히려 맞았다. 정정 커밋 sim `d44f2f0`에 **계수 규칙을 명시**했다.
교훈: 규칙 없는 숫자는 앞 기록을 정정한다면서 더 나쁜 기록을 만든다.

**codex 백엔드 사용량 한도 소진**(2026-09-01, 재개 예정 20:10). 이 세션의 잔여 작업은
codex를 쓰지 않으므로 영향 없으나, **ground 4 의 2-family 게이트를 다시 열려면 agy 단독이거나
한도 해제 후여야 한다.** 한 family 만으로 여는 것은 게이트가 아니다.

### push·PR 처리 기록 (2026-09-01)

`docs/p4-flags-refresh` 두 브랜치는 `fix/build-warnings` 위에 쌓여 있었으나
`git rebase --onto main fix/build-warnings` 로 **스택을 풀어 `main` 에 직접 올렸다.**
근거: 파일 집합이 완전히 분리돼 있다 — 문서 브랜치는 `P4_FLAGS.md` 단독, 빌드 경고
브랜치는 sim `stonefish_ros2/CMakeLists.txt` · slam `CMakeLists.txt`+`cpp/cfar.cpp`.
따라서 문서 PR 은 #24·#16 머지를 기다릴 이유가 없고, D8 의 "선머지 후 main" 은
**코드 브랜치에만** 걸린다.

| repo | PR | 브랜치 |
|:--|:--|:--|
| meta `stonefish_ws` | [#11](https://github.com/HERO-Lab-POSTECH/stonefish_ws/pull/11) | `luckkim123/object_detection_to_2d_mapping` (Phase 1·2 거버넌스 기록 7커밋) |
| `stonefish_sim` | [#25](https://github.com/HERO-Lab-POSTECH/stonefish_sim/pull/25) | `docs/p4-flags-refresh` → main |
| `stonefish_slam` | [#17](https://github.com/HERO-Lab-POSTECH/stonefish_slam/pull/17) | `docs/p4-flags-refresh` → main |

게이트 재측정(PR 증빙): sim **179 passed** · slam **71 passed** · `{"pass": true}`.
⚠️ `evaluator.sh` 는 `OMX_PROJECT_DIR` 미설정 시 **`/workspace`(다른 체크아웃)** 를
검사한다 — 워크트리를 재려면 반드시 지정해야 한다. 이번에 처음 드러난 함정이다.
