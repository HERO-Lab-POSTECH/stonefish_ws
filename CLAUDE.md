# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`stonefish_ws` — Stonefish 수중 시뮬레이터 위에서 제어와 SLAM을 개발하는 ROS 2 Humble colcon
워크스페이스이자 팀 공용 meta-repo입니다.

## 먼저 알아야 할 것 — 여기는 meta-repo, 소스가 아니다

이 저장소가 추적하는 것은 `stonefish.repos` · `CONTRIBUTING.md` · `.omp/` · `.omx/` 뿐입니다.
**`src/`는 `.gitignore` 대상**이며 그 아래 각 디렉토리가 **독립된 git repo**입니다
(`stonefish_sim` · `stonefish_slam` · `stonefish_bringup`, 모두 `HERO-Lab-POSTECH` remote).

- 루트에서 `git status`를 봐도 코드 변경은 **보이지 않습니다.** 커밋·브랜치·PR은 반드시
  해당 하위 repo 안에서 (`git -C src/stonefish_slam ...`).
- 루트 meta-repo와 하위 3개 repo는 **서로 다른 4개의 remote**입니다. 워크스페이스 자체의
  변경(`stonefish.repos`·`CONTRIBUTING.md`·`.omp/`·`.omx/profile/`)은 meta-repo에,
  코드 변경은 해당 하위 repo에 각각 push·PR합니다.
- 하위 repo에서 코드를 만지기 전 그 repo의 `CLAUDE.md`와 **`docs/CONVENTIONS.md`(그 repo의
  SSOT)**를 먼저 읽습니다. 미해결 이슈는 각 repo `P4_FLAGS.md`에 모여 있으니 거기 적힌
  안티패턴을 새 코드에서 답습하지 않습니다.

## 명령

```bash
# 소스 가져오기 (src/가 비었을 때)
vcs import src < stonefish.repos

# 빌드 — --merge-install 고정 (문서·테스트·기존 install 트리가 merge 레이아웃 전제)
source /opt/ros/humble/setup.bash
colcon build --merge-install && source install/setup.bash
colcon build --merge-install --packages-select stonefish_slam   # 단일 패키지
```

### 테스트

각 repo **루트에서** 돌립니다(워크스페이스 루트가 아님). 두 repo 모두 `pytest.ini`의
`testpaths`가 수집 범위를 정의합니다.

```bash
cd src/stonefish_sim  && python3 -m pytest          # 또는 -q
cd src/stonefish_slam && python3 -m pytest

python3 -m pytest test/test_characterization_ilos.py -v   # 단일 파일
python3 -m pytest -k "ilos and not angle_wrap" -v         # 이름 필터
```

**slam은 `.so` 스테이징이 선행 조건입니다.** pybind11 확장 5개(`cfar`, `dda_traversal`,
`octree_mapping`, `ray_processor`, `pcl`)는 gitignore되므로 빌드 산출물을 소스 트리로 복사해야
수집이 됩니다. 안 하면 collection 단계에서 실패하는데 이는 정상 동작이지 깨진 체크아웃이
아닙니다.

```bash
colcon build --merge-install --packages-select stonefish_slam
cp build/stonefish_slam/*.so src/stonefish_slam/stonefish_slam/
```

양 repo를 한 번에 판정하는 게이트(`.so` 스테이징 포함, 마지막 줄에 `{"pass": bool}` JSON):

```bash
bash .omx/profile/evaluator.sh
```

### 시뮬레이터 실행

```bash
ros2 launch stonefish_ros2 bluerov2.launch.py                  # 터미널 A: 시뮬
ros2 launch stonefish_trajectory_manager path.launch.py        # 터미널 B: 경로추종+제어
ros2 launch stonefish_slam slam.launch.py vehicle_name:=bluerov2   # 터미널 C: SLAM
```

시뮬레이터는 **OpenGL 4.3+ GPU 렌더링이 필수**입니다 — headless/GPU 없는 컨테이너에서는
띄울 수 없고, 그런 환경에서 가능한 검증은 pytest fast gate까지입니다. 닫힌루프 궤적 오차
측정은 팀 GPU 머신에서 `src/stonefish_slam/docs/RUN_TEST.md` 절차로 수행합니다.

### 거버넌스 도구

`.omp/`(구조·명명 규칙 SSOT)는 oh-my-project 하네스가, `.omx/`(실험 분석 프로파일)는
oh-my-experiments 하네스가 사용합니다. `omx` CLI는 `/opt/omx-venv`에 설치되어 있습니다
(`omx doctor --root /workspace`). 실험 런 출력은 `experiments/` 트리가 SSOT이며 git 비공유,
훈련 launch는 자동 실행하지 않고 사람 승인 큐로만 보냅니다.

## 아키텍처

### 세 repo의 역할과 데이터 흐름

| repo | 내용 |
|:--|:--|
| `stonefish` (fork, 1.3.0 고정) | Stonefish 코어 C++ 물리·렌더 라이브러리. `stonefish_ros2`가 `find_package(Stonefish REQUIRED 1.3.0)`로 **exact-version** 매치하므로 upstream master(1.6.0-dev)로는 빌드 실패 |
| `stonefish_sim` | 멀티패키지. `stonefish_ros2`(C++ 시뮬 브리지) · `stonefish_description`(차량·월드 `.scn`·3D 에셋) · `stonefish_msgs`(인터페이스) · `stonefish_control/`(하위에 `stonefish_control`·`stonefish_control_msgs`·`stonefish_thruster_manager`·`stonefish_trajectory_manager` **4개 패키지**) · `stonefish_albc_bridge`(RL 정책 브리지) |
| `stonefish_slam` | 단일 패키지, Python + pybind11 C++ 혼합. `core/`(알고리즘) · `nodes/`(ROS 진입점, core의 얇은 래퍼) · `utils/` · `cpp/`(바인딩 + 순수 파이썬 fallback) |
| `stonefish_bringup` | Docker 배포 **정본**. 멀티스테이지로 core+sim+slam을 이미지에 bake. `.omp/env/`는 byte-identical 미러이므로 **수정은 bringup에서** |

런타임 결합은 토픽으로만 이루어집니다: sim이 `/{vehicle}/fls/image` · `odometry` · `imu` ·
`dvl` · `pressure`를 발행하고 slam이 구독해 `/stonefish_slam/slam/*`(pose·odom·traj·cloud·
constraint)와 `mapping/*`(2D 이미지·3D OctoMap)를 발행합니다. 제어 쪽은 반대로
`thruster_manager/input`(Wrench) · `cmd_pose` · `cmd_vel`로 명령을 넣습니다.

### 인터페이스 경계 — 크로스 repo 파손 지점

`stonefish_msgs`는 **sim repo에 있고 slam이 의존**합니다. msg/srv를 바꾸면 slam이 조용히
깨집니다. 인터페이스 변경 PR에는 상대 repo의 대응 PR을 본문에 상호 링크하는 것이 규칙입니다
(`CONTRIBUTING.md` §5).

### 좌표계 — 의도적 표준 이탈

**전역 프레임은 양 repo 모두 `world_ned`(NED)**입니다. Stonefish가 월드를 NED로 발행하기 때문에
정합을 위해 REP-103/105(ENU 규정)에서 의도적으로 벗어난 결정입니다(REP-103의 `_ned` 접미사
규약은 지킴). 반면 **slam의 로컬 TF 체인 `odom→base_link`는 REP-105 ENU를 유지**합니다
(`core/dead_reckoning.py`). 두 계열을 잇는 TF publisher는 identity라 실제 회전 변환은 없고
프레임 **이름**만 다릅니다 — 통합 작업 시 이 경계만 주의하면 됩니다. 근거는 각 repo
`docs/CONVENTIONS.md` §2.0.

### 테스트가 모듈을 파일 경로로 로드하는 이유

두 repo 모두 루트 `conftest.py`의 **`load_module` fixture**로 대상 `.py`를 파일 경로에서 직접
로드합니다(`importlib.util.spec_from_file_location`). 패키지 경로 import를 쓰면 `__init__.py`와
형제 모듈이 import-time에 `rclpy`·`gtsam`·`cv_bridge`를 끌어와 ROS 없는 환경에서 수집이
터지기 때문입니다. **새 테스트도 이 fixture를 써야 합니다** — 평범한 `from stonefish_slam...
import`는 이 설계를 깹니다. slam에는 형제 절대 import까지 stub으로 막는
`load_factor_graph` fixture가 따로 있습니다(gtsam은 실제로 import됨).

### 버전 동기

9개 `package.xml`이 하나의 버전(현재 0.4.0)으로 통일돼 있습니다. 릴리스 시 repo 내 **모든**
`package.xml`을 함께 올리고 `CHANGELOG.md`(Keep a Changelog) 정리 후 annotated tag를 답니다.

## 협업 규칙 (정본: `CONTRIBUTING.md`)

세 repo 공통이며 각 repo의 사본은 이 정본과 동일하게 유지합니다(사본만 고치지 말 것).
2026-07-23 발효, 그 이전 이력에는 소급 적용하지 않습니다.

- **`main` 직접 커밋 금지** — 브랜치 → PR → 리뷰(승인 1인, 본인 PR 자기승인 금지) → merge.
  브랜치는 `<type>/<짧은-설명>`(`feat/` `fix/` `docs/` `refactor/` `test/` `chore/` `exp/`).
- **Conventional Commits** — `<type>(<scope>): <제목>`, scope는 패키지·모듈명
  (`fix(slam.core):`). 커밋은 원자적으로.
- PR 제목도 같은 형식이며 `.github/PULL_REQUEST_TEMPLATE.md`의 **테스트 증빙 생략 불가**.
  올리기 전 해당 repo `python3 -m pytest` 통과 확인.
- 내용을 main에 직접 merge/push 해놓고 PR을 열어두는 것(stale PR) 금지 — merge는 GitHub PR
  버튼으로만.
- 시뮬 physics 파라미터(`.scn`)와 알고리즘 변경을 한 PR에 섞지 않습니다.

## 명명 규칙 (정본: `.omp/rules.json`, 사람용 `.omp/NAMING.md`)

`src/` 트리에만 적용되며 audit이 강제합니다: 패키지 디렉토리 `stonefish_<name>`, Python 모듈
`snake_case.py`, launch `*.launch.py`, msg/srv `PascalCase`, config `snake_case.yaml`
(전대문자 약어는 예외 — `TAM.yaml` 통과, `Tam.yaml`은 위반), 씬 파일 `snake_case.scn`.
규칙을 바꿀 때는 `rules.json`과 `STRUCTURE.md`/`NAMING.md`를 **같은 작업 안에서** 함께
갱신합니다(둘의 drift 금지).

<!-- code-review-graph MCP tools -->
## MCP Tools: code-review-graph

**IMPORTANT: This project has a knowledge graph. ALWAYS use the
code-review-graph MCP tools BEFORE using Grep/Glob/Read to explore
the codebase.** The graph is faster, cheaper (fewer tokens), and gives
you structural context (callers, dependents, test coverage) that file
scanning cannot.

신뢰 규칙 정본은 [`.claude/rules/code-review-graph.md`](.claude/rules/code-review-graph.md) —
그래프가 언제 조용히 실패하는지가 거기 있습니다.

### 그래프는 루트가 아니라 하위 repo에 있습니다 — `repo_root` 필수

**모든 조회에 `repo_root`를 넘기세요.** 워크스페이스 루트에는 그래프가 없습니다:
meta-repo는 `src/`를 gitignore하고 code-review-graph는 `git ls-files`로 파일을 모으므로,
루트에서 빌드하면 `.omp/env`·`.omx/profile` 6개만 잡힙니다. 그래서 그래프는 두 코드 repo에
따로 있습니다.

| 대상 | `repo_root` |
|:--|:--|
| 시뮬·제어 (98파일 · 728노드) | `/workspace/src/stonefish_sim` |
| SLAM (71파일 · 479노드) | `/workspace/src/stonefish_slam` |

`repo_root`를 생략하면 도구는 **오류가 아니라 `status: "ok"`에 결과 0건**을 돌려줍니다 —
"그런 심볼은 없다"로 오독하기 딱 좋은 조용한 실패입니다. 어느 repo인지 모를 때는
`cross_repo_search_tool`을 쓰세요. 두 그래프를 함께 훑고 결과마다 `repo` 태그를 붙입니다
(레지스트리 `/root/.code-review-graph/registry.json`에 `sim`·`slam`으로 등록됨).

`stonefish_bringup`은 Docker 자산뿐이라 코드 노드가 없어 그래프를 만들지 않았습니다.

인덱싱 범위는 각 repo의 `.code-review-graphignore`가 정합니다 — 코드(`.py`·`.cpp`·`.h`)와
동작에 영향을 주는 설정(`.yaml`)만 남기고 `docs/`·`*.md`·`.rviz`·3D 메시(`.obj`/`.mtl`)·
`.scn`·이미지는 제외합니다. 그래프에 문서가 안 보이는 것은 정상입니다.

### When to use graph tools FIRST

- **Exploring code**: `semantic_search_nodes_tool` or `query_graph_tool` instead of Grep
- **Understanding impact**: `get_impact_radius_tool` instead of manually tracing imports
- **Code review**: `detect_changes_tool` + `get_review_context_tool` instead of reading entire files
- **Finding relationships**: `query_graph_tool` with callers_of/callees_of/imports_of/tests_for
- **Architecture questions**: `get_architecture_overview_tool` + `list_communities_tool`

Fall back to Grep/Glob/Read **only** when the graph doesn't cover what you need.

### Key Tools

| Tool | Use when |
| ------ | ---------- |
| `detect_changes_tool` | Reviewing code changes — gives risk-scored analysis |
| `get_review_context_tool` | Need source snippets for review — token-efficient |
| `get_impact_radius_tool` | Understanding blast radius of a change |
| `get_affected_flows_tool` | Finding which execution paths are impacted |
| `query_graph_tool` | Tracing callers, callees, imports, tests, dependencies |
| `semantic_search_nodes_tool` | Finding functions/classes by name or keyword |
| `get_architecture_overview_tool` | Understanding high-level codebase structure |
| `refactor_tool` | Planning renames, finding dead code |

### Workflow

1. The graph auto-updates on file changes (via hooks).
2. Use `detect_changes_tool` for code review.
3. Use `get_affected_flows_tool` to understand impact.
4. Use `query_graph_tool` pattern="tests_for" to check coverage.
