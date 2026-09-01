# 폴더 구조 — stonefish-ws

convention: **colcon-workspace** (`src/` 소스 + `install/` 빌드 산출물)

`rules.json`의 `structure`를 사람이 읽는 형태로 풀어쓴 것입니다. 둘은 항상 일치해야 합니다(machine truth는 `rules.json`, 사람은 이 문서를 읽음).

## 디렉토리별 역할

| 경로 | 역할 | 감사(enforced) | 근거 |
|:---|:---|:---:|:---|
| `src` | 소스 루트 — 손으로 쓴 코드 전부. vcstool이 git repo를 여기로 클론. **omp가 감사하는 유일한 트리** | ✅ | inductive (strong) |
| `install` | colcon 빌드 산출물 트리 (~671MB, 재생성 가능, 소스 없음). 편집 금지·감사 제외 | ❌ | inductive (strong) |
| `src/stonefish` | git repo `HERO-Lab-POSTECH/stonefish` (fork, 1.3.0 고정) — 코어 C++ 물리·렌더 라이브러리. `stonefish_ros2`가 exact-version 1.3.0 요구 | ❌ | inductive (2026-09-01, vcs import로 실재 확인) |
| `src/stonefish_sim` | git repo `HERO-Lab-POSTECH/stonefish_sim` — 시뮬레이터 측 ROS 2 패키지 (description·control·ros2 브리지) | ❌ | inductive (strong) |
| `src/stonefish_slam` | git repo `HERO-Lab-POSTECH/stonefish_slam` — SLAM 패키지 (Python core/nodes + C++ algos) | ❌ | inductive (strong) |
| `src/stonefish_sim/stonefish_description/data` | 3D 에셋 전용 (mesh/texture/scene, ~621MB, 코드 0). dataset 후보 영역 | ❌ | preset |
| `src/stonefish_sim/stonefish_description/data/worlds` | 월드 씬 파일 (.scn) + 메시 — 시뮬레이터 월드 정의 | ❌ | inductive (strong) |
| `src/stonefish_slam/stonefish_slam/core` | SLAM 핵심 알고리즘 모듈 (Python, snake_case) | ✅ | inductive (strong) |
| `src/stonefish_slam/stonefish_slam/nodes` | ROS 2 노드 진입점 (`*_node.py`) — core/의 얇은 래퍼 | ✅ | inductive (strong) |
| `.hq/config/project/env` | Docker 환경 자산 미러 — 정본(SSOT)은 [stonefish_bringup](https://github.com/HERO-Lab-POSTECH/stonefish_bringup) repo. byte-identical 유지, 수정은 bringup에서 | ❌ | omp-env (2026-07-23, bringup 이관) |
| `.hq/config/experiments` | omx 실험 분석 프로파일 — `profile/`이 팀 공유(커밋) | ❌ | omx init (2026-07-23, 2026-08-31 .hq 통합) |
| `experiments` | omx 런 출력 트리(SSOT, 데이터) — git 비공유, tree.yaml이 스키마 | ❌ | omx init (2026-07-23) |

## 감사 제외 영역 (ignore)

`rules.json`의 `ignore` 글롭 — audit이 이 경로들을 검사하지 않습니다:

- `**/.git/**`, `**/__pycache__/**` — 버전관리·바이트코드 캐시
- `install/**` — colcon 빌드 산출물 전체
- `.../thruster_manager/launch/{build,install,log}/**` — src 내부 중첩 colcon 아티팩트 (COLCON_IGNORE 마커 확인됨)
- `.../stonefish_slam/cpp/pybind11/**` — 벤더드 서드파티 (자체 CMakeLists + tests)
- `.omc/**` — omc 내부 상태
- `.hq/**` — 통합 하네스 스토어 (2026-08-31 .omp/·.omx/ 대체)
- `experiments/**` — omx 런 출력 트리 (2026-07-23 추가)
- `.sp/**` — superpowers 스크래치 (2026-07-23 추가)

## 관찰됐으나 규칙은 아닌 것

- **`stonefish` C++ 라이브러리 소스 부재**: `stonefish.repos`는 이 repo도 나열하지만 스캔 시점에 `src/`에 클론 없음. `install/`에 빌드 산출물만 존재 — `vcs import` 미실행 추정(미확인).
- **중첩 colcon 아티팩트**: `stonefish_thruster_manager/launch/` 하위에 독립 빌드 흔적(build/install/log) — 소스 아님, ignore 처리.
