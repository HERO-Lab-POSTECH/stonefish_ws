# stonefish-ws

ROS 2 + colcon 워크스페이스. **수중 로봇 시뮬레이터 Stonefish** 위에서 제어(control)와 SLAM을 개발하는 연구 프로젝트입니다. `vcstool`(`stonefish.repos`)로 HERO-Lab-POSTECH의 여러 git repo를 `src/`로 가져와 함께 빌드합니다.

## 무엇을 하는 프로젝트인가

- **시뮬레이션**: Stonefish 수중 물리 시뮬레이터 + ROS 2 브리지(`stonefish_ros2`). BlueROV2·BlueBoat 등 수중 로봇과 난파선·터빈·해저 지형 같은 3D 환경을 시뮬레이션합니다.
- **제어**: DP(dynamic positioning) 컨트롤러, 스러스터 할당, 궤적 추종. PID 게인은 수동 설정값을 사용합니다(`stonefish_control`의 config). 과거의 GWO·SMAC3 PID 옵티마이저(`stonefish_control_utils`)는 실제 게인 산출에 쓰이지 않아 제거됨.
- **SLAM**: Python(`core/` — factor_graph, localization(+FFT), mapping_2d/3d, cfar, dead_reckoning)과 C++(`cpp/` + pybind11 바인딩)로 구현한 수중 SLAM. (kalman은 P4에서 제거됨)
- **팀 배포**(2026-07-23~): Docker 배포 정본은 전용 repo [stonefish_bringup](https://github.com/HERO-Lab-POSTECH/stonefish_bringup)(멀티스테이지, core+sim+slam 소스 bake — 호스트 실빌드 검증 완료). `.omp/env/`는 그 동기화 미러(구 bind-mount 키트·repo `docker/` 사본은 제거됨). 협업 규칙은 워크스페이스 `CONTRIBUTING.md`, 실험 분석 프로파일은 `.omx/profile/`. 워크스페이스 루트가 meta-repo(git)로 관리됨.

## 핵심 구조 한눈에

| 경로 | 역할 |
|:---|:---|
| `src/` | 손으로 쓴 소스 전부 — vcstool이 git repo를 여기로 클론. **omp가 감사하는 유일한 트리** |
| `src/stonefish_sim/` | 시뮬레이터 측 패키지 (description·control·ros2 브리지) |
| `src/stonefish_slam/` | SLAM 패키지 (Python core/nodes + C++ algos) |
| `install/` | colcon 빌드 산출물 (~671MB, 재생성 가능, 편집 금지) — 감사 제외 |

상세는 [STRUCTURE.md](STRUCTURE.md)·[NAMING.md](NAMING.md) 참조.

## 빌드 / 동기화

- 소스 동기화: `vcs import src < stonefish.repos` (멀티-repo 가져오기)
- 빌드: `colcon build` → `install/` 생성
- ⚠️ `stonefish.repos`는 C++ 라이브러리 `stonefish` 자체도 나열하지만, 스캔 시점에 `src/`에 클론돼 있지 않았습니다(빌드된 `install/` 산출물만 존재). `vcs import` 미실행 상태일 수 있습니다.

## 메모

- **데이터 관리**: DVC·git-lfs 미사용. 3D 에셋(~621MB, `stonefish_description/data`)은 in-tree. dataset 등록은 `omp-dataset`이 담당(현재 후보 식별만).
- **omp preset**: `research-lab`. colcon 구조는 어떤 프리셋과도 안 맞아 거의 모든 규칙을 실측 트리에서 귀납 작성 → specificity 0.80. (초기 스캔의 결정적 신호였던 wandb/GWO/SMAC3 실험 출력 클러스터 `stonefish_control_utils`는 이후 제거됨.)
