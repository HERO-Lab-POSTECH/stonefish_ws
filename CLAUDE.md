# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

`stonefish_ws` — Stonefish 수중 시뮬레이터 위에서 제어와 SLAM을 개발하는 ROS 2 Humble colcon
워크스페이스이자 팀 공용 meta-repo입니다.

## 먼저 알아야 할 것 — 여기는 meta-repo, 소스가 아니다

이 저장소가 추적하는 것은 `stonefish.repos` · `CONTRIBUTING.md` · `.hq/` 뿐입니다
(2026-08-31 `.omp/`·`.omx/`를 `.hq/` 한 스토어로 통합했고, legacy 16파일은 롤백
경로로 아직 추적됩니다).
**`src/`는 `.gitignore` 대상**이며 그 아래 각 디렉토리가 **독립된 git repo**입니다
(`stonefish_sim` · `stonefish_slam` · `stonefish_bringup`, 모두 `HERO-Lab-POSTECH` remote).

- 루트에서 `git status`를 봐도 코드 변경은 **보이지 않습니다.** 커밋·브랜치·PR은 반드시
  해당 하위 repo 안에서 (`git -C src/stonefish_slam ...`).
- 루트 meta-repo와 하위 3개 repo는 **서로 다른 4개의 remote**입니다. 워크스페이스 자체의
  변경(`stonefish.repos`·`CONTRIBUTING.md`·`.hq/`)은 meta-repo에,
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
bash .hq/config/experiments/profile/evaluator.sh
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

`.hq/` 한 스토어를 oh-my-project(`config/project/` — 구조·명명 규칙 SSOT)와
oh-my-experiments(`config/experiments/` — 실험 분석 프로파일)가 함께 씁니다. `.hq/.anchor`가
있으면 두 하네스 모두 legacy `.omp/`·`.omx/`를 더 이상 읽지 않습니다. `omx` CLI는
`/opt/omx-venv`에 설치되어 있습니다(`omx doctor --root /workspace`). 실험 런 출력은
`experiments/` 트리가 SSOT이며 git 비공유, 훈련 launch는 자동 실행하지 않고 사람 승인
큐로만 보냅니다.

## 아키텍처

### 세 repo의 역할과 데이터 흐름

| repo | 내용 |
|:--|:--|
| `stonefish` (fork, 1.3.0 고정) | Stonefish 코어 C++ 물리·렌더 라이브러리. `stonefish_ros2`가 `find_package(Stonefish REQUIRED 1.3.0)`로 **exact-version** 매치하므로 upstream master(1.6.0-dev)로는 빌드 실패 |
| `stonefish_sim` | 멀티패키지. `stonefish_ros2`(C++ 시뮬 브리지) · `stonefish_description`(차량·월드 `.scn`·3D 에셋) · `stonefish_msgs`(인터페이스) · `stonefish_control/`(하위에 `stonefish_control`·`stonefish_control_msgs`·`stonefish_thruster_manager`·`stonefish_trajectory_manager` **4개 패키지**) · `stonefish_albc_bridge`(RL 정책 브리지) |
| `stonefish_slam` | 단일 패키지, Python + pybind11 C++ 혼합. `core/`(알고리즘) · `nodes/`(ROS 진입점, core의 얇은 래퍼) · `utils/` · `cpp/`(바인딩 + 순수 파이썬 fallback) |
| `stonefish_bringup` | Docker 배포 **정본**. 멀티스테이지로 core+sim+slam을 이미지에 bake. `.hq/config/project/env/`는 byte-identical 미러이므로 **수정은 bringup에서** |

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
규약은 지킴). **slam의 로컬 TF 체인 `odom→base_link`도 프레임 이름만 REP-105에서 빌렸을 뿐
데이터는 NED(z-down)**입니다(`core/dead_reckoning.py` — 2026-08-21 소비자 전수 추적으로
이전의 "로컬 ENU 유지" 기술이 반증됨: `/dead_reck/*` 구독자 0, 변환 부재, 체인 전체 NED
자기정합). 모든 TF는 identity라 좌표 변환 없이 이름 층위만 정합합니다. 근거는 각 repo
`docs/CONVENTIONS.md` §2.0.

### 테스트가 모듈을 파일 경로로 로드하는 이유

두 repo 모두 루트 `conftest.py`의 **`load_module` fixture**로 대상 `.py`를 파일 경로에서 직접
로드합니다(`importlib.util.spec_from_file_location`). 패키지 경로 import를 쓰면 `__init__.py`와
형제 모듈이 import-time에 `rclpy`·`gtsam`·`cv_bridge`를 끌어와 ROS 없는 환경에서 수집이
터지기 때문입니다. **새 테스트도 이 fixture를 써야 합니다** — 평범한 `from stonefish_slam...
import`는 이 설계를 깹니다. slam에는 형제 절대 import까지 stub으로 막는
`load_factor_graph` fixture가 따로 있습니다(gtsam은 실제로 import됨).

### 버전 동기

버전은 **repo 단위로** 동기합니다 — sim의 8개 `package.xml`은 0.5.0, slam은 0.4.0.
릴리스 시 해당 repo 내 **모든** `package.xml`을 함께 올리고 `CHANGELOG.md`(Keep a
Changelog) 정리 후 annotated tag를 답니다.

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

## 명명 규칙 (정본: `.hq/config/project/rules.json`, 사람용 `.hq/community/NAMING.md`)

`src/` 트리에만 적용되며 audit이 강제합니다: 패키지 디렉토리 `stonefish_<name>`, Python 모듈
`snake_case.py`, launch `*.launch.py`, msg/srv `PascalCase`, config `snake_case.yaml`
(전대문자 약어는 예외 — `TAM.yaml` 통과, `Tam.yaml`은 위반), 씬 파일 `snake_case.scn`.
규칙을 바꿀 때는 `rules.json`과 `STRUCTURE.md`/`NAMING.md`를 **같은 작업 안에서** 함께
갱신합니다(둘의 drift 금지).

<!-- code graph: graphify -->
## 코드 그래프 — graphify

**이 프로젝트에는 지식 그래프가 있습니다. 코드베이스를 탐색할 때 Grep/Glob/Read보다
먼저 `graphify query`를 쓰세요.** 파일을 읽지 않고 구조를 답하므로 토큰이 훨씬 싸고,
호출·의존 관계처럼 파일 스캔으로는 안 보이는 맥락을 줍니다.

신뢰 규칙 정본은 [`.claude/rules/code-graph.md`](.claude/rules/code-graph.md) —
그래프가 언제 **조용히** 실패하는지가 거기 있습니다.

> 2026-08-29까지 이 자리는 code-review-graph(CRG)였습니다. 도구를 비교해 진 게 아니라
> **구속하는 층이 없어서** 물러났습니다: 세 통합 층(MCP 서버·CLAUDE.md 블록·PreToolUse
> 훅) 중 실제로 구속력이 있는 건 훅뿐인데, 배포되는 유일한 그래프 가드
> `graphify-guard.sh`는 graphify CLI를 이름으로 호출합니다. CRG를 부르는 훅은 만들어진
> 적이 없습니다. CRG의 MCP 서버·인덱스·`.code-review-graphignore`·pre-commit 훅은 모두
> 제거됐습니다.

### 그래프는 루트가 아니라 하위 repo에 있습니다

**조회는 해당 repo 디렉터리 안에서 하세요.** 워크스페이스 루트에는 그래프가 없습니다 —
meta-repo가 `src/`를 gitignore하므로 루트에서 빌드하면 `.hq/config/` 몇 개만
잡힙니다. 그래서 그래프는 두 코드 repo에 따로 있습니다.

| 대상 | 위치 | 규모 (2026-08-31 실측) |
|:--|:--|:--|
| 시뮬·제어 | `/workspace/src/stonefish_sim/.graphify/` | 2,353노드 · 3,116링크 |
| SLAM | `/workspace/src/stonefish_slam/.graphify/` | 1,284노드 |

`stonefish_bringup`은 Docker 자산뿐이라 그래프를 만들지 않았습니다.

**CRG와 결정적으로 다른 점: graphify는 산문도 인덱싱합니다.** 의미 추출(LLM) 패스를
돌린 덕에 sim은 `.md` 765개, slam은 224개 노드를 갖고 있어 `CHANGELOG.md`·`docs/`의
서술이 코드 심볼과 같은 그래프에 들어 있습니다. CRG는 tree-sitter뿐이라 마크다운에서
노드가 0이었습니다 — "그래프에 문서가 안 보이는 게 정상"이던 이전 서술은 더 이상
맞지 않습니다.

### 쓰는 법

```bash
cd src/stonefish_sim && graphify query "ILOSGuidance"   # 심볼·개념에서 BFS
graphify god-nodes            # 가장 많이 연결된 허브
graphify update .             # 편집 후 갱신 (AST 패스는 무료·오프라인)
```

`.graphify/`는 gitignore 대상인 빌드 산출물이고 Stop 훅이 코드 패스를 자동 갱신합니다.
산문 의미 추출은 유료·수 시간짜리 별도 패스라 자동으로 돌지 않습니다 — 필요하면
`/graphify`로 사람이 직접 시작합니다.

### 조용한 실패 — 결과 0건을 "없다"로 읽지 말 것

- **여러 단어로 질의하면 매칭이 안 됩니다.** 식별자 하나로 좁혀서 물으세요.
- **깊이 기본값 2는 관계없는 형제 모듈까지 끌어옵니다.** 영향 범위를 볼 땐 깊이 1.
- **프로세스 경계를 넘는 결합은 어떤 코드 그래프에도 엣지로 안 잡힙니다** — ROS 2 토픽
  이름과 QoS, 런타임에 풀리는 서비스 이름, launch 파일의 배선. 구독이 안 붙는 형태로만
  드러나므로 `ros2 topic info -v`로 실물을 확인하세요.

인덱싱 범위는 각 repo의 `.graphifyignore`가 정합니다.
