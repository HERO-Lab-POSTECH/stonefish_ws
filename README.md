# stonefish_ws — HERO Lab 수중로봇 시뮬레이션 워크스페이스

Stonefish 수중 물리 시뮬레이터 위에서 **제어(stonefish_sim)** 와 **SLAM(stonefish_slam)** 을
개발하는 ROS 2 Humble colcon 워크스페이스의 팀 공용 meta-repo입니다. 이 repo에는 소스가
아니라 **워크스페이스를 재현하는 데 필요한 것**만 들어 있습니다: repo 목록(`stonefish.repos`),
협업 규칙(`CONTRIBUTING.md`), 그리고 프로젝트 거버넌스와 실험 분석 프로파일을 함께 담은
통합 스토어(`.hq/`).
Docker 배포 환경은 전용 repo
[stonefish_bringup](https://github.com/HERO-Lab-POSTECH/stonefish_bringup)이 정본입니다
(`.hq/config/project/env/`는 그 동기화 미러).

## 구성 repo

| repo | 역할 | 문서 |
|:--|:--|:--|
| [stonefish](https://github.com/HERO-Lab-POSTECH/stonefish) | Stonefish 코어 C++ 라이브러리 (fork, 1.3.0 고정) | upstream docs |
| [stonefish_sim](https://github.com/HERO-Lab-POSTECH/stonefish_sim) | 시뮬레이터 ROS 2 브리지 + 차량·월드 + 제어(DP/경로추종) + RL 브리지 | [사이트](https://hero-lab-postech.github.io/stonefish_sim/) |
| [stonefish_slam](https://github.com/HERO-Lab-POSTECH/stonefish_slam) | FLS 소나 기반 수중 SLAM (Python core + pybind11 C++) | [사이트](https://hero-lab-postech.github.io/stonefish_slam/) |

## Quick Start

**시뮬레이터를 띄우기만 할 때 (Docker — 배포·재현)** — 전용 배포 repo
[stonefish_bringup](https://github.com/HERO-Lab-POSTECH/stonefish_bringup)을 사용합니다.
멀티스테이지 Dockerfile이 core+sim+slam 소스를 이미지에 bake하므로 호스트에는
NVIDIA 드라이버, Docker CE(apt 설치본 — snap 금지),
[nvidia-container-toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)만
있으면 됩니다:

```bash
git clone https://github.com/HERO-Lab-POSTECH/stonefish_bringup.git
cd stonefish_bringup && docker compose build     # 최초 빌드 ~15-30분
```

요구사항·실행 명령은 [bringup README](https://github.com/HERO-Lab-POSTECH/stonefish_bringup#readme) 참조.

**코드를 개발할 때 (native 워크스페이스)** — ROS 2 Humble이 설치된 호스트에서:

```bash
# 1) 워크스페이스 + 소스
git clone https://github.com/HERO-Lab-POSTECH/stonefish_ws.git && cd stonefish_ws
vcs import src < stonefish.repos        # pip install vcstool (없으면)

# 2) 의존성 (상세는 각 repo README Installation 참조)
rosdep install --from-paths src --ignore-src -r -y

# 3) 빌드 & 실행
source /opt/ros/humble/setup.bash
colcon build --merge-install && source install/setup.bash
ros2 launch stonefish_ros2 bluerov2.launch.py
```

Native 경로는 Stonefish C++ 라이브러리(HERO fork 1.3.0, ExactVersion 함정) 선행 설치가
필요합니다 — stonefish_sim README "Option B — Native install" 참조.

## 협업 규칙

**[CONTRIBUTING.md](CONTRIBUTING.md)** — GitHub Flow(main 직접 커밋 금지) ·
Conventional Commits · PR 승인 1인 · SemVer + Keep a Changelog. 세 repo 공통 적용,
각 repo의 사본은 이 정본과 동일하게 유지합니다.

## 팀 공용 도구

- **`.hq/config/project/`** — 프로젝트 구조·명명 규칙 SSOT(`rules.json` + `STRUCTURE.md`,
  사람용 `.hq/community/NAMING.md`). Docker 배포 정본은
  [stonefish_bringup](https://github.com/HERO-Lab-POSTECH/stonefish_bringup) repo이며
  `.hq/config/project/env/`는 그 동기화 미러. 규칙 감사는 oh-my-project 하네스의 `omp-audit`로.
- **`.hq/config/experiments/`** — SLAM 검증·실험 분석 프로파일(oh-my-experiments 하네스).
  런 결과는 `experiments/` 트리에 축적(SSOT), 분석은 `exp-analyze`, 다음 실험 설계는
  `exp-design`. CLI 설치(컨테이너/새 머신 1회):

  ```bash
  python3 -m venv /opt/omx-venv
  /opt/omx-venv/bin/pip install <oh-my-experiments-plugin>/omx-core
  sudo ln -s /opt/omx-venv/bin/omx /usr/local/bin/omx
  omx doctor --root /workspace     # preflight
  ```

- `.hq/config/experiments/profile/`의 evaluator(fast gate = 양 repo pytest)는 `omx eval`로 실행됩니다.
  현재 프로파일은 **pending approval** — 팀 리뷰 후 `omx profile-seal`로 확정하세요.

## 레이아웃

```text
stonefish_ws/
├── stonefish.repos      # vcs import 소스 목록 (main 추적; 릴리스 스냅샷은 태그 핀 사본)
├── CONTRIBUTING.md      # 협업 규칙 정본
├── .hq/                 # 통합 스토어 — config/project/(구조·명명 규칙 + env 미러),
│                     #   config/experiments/(실험 프로파일), community/(팀 공유 지식)
├── src/                 # vcs import 대상 (git 관리 밖 — 각자의 repo clone)
├── build/ install/ log/ # colcon 산출물 (비공유)
└── experiments/         # omx 런 출력 트리 (비공유)
```
