# 명명 규칙 — stonefish-ws

`rules.json`의 `naming.patterns`를 사람이 읽는 형태로 풀어쓴 것입니다. 둘은 항상 일치해야 합니다.

`severity` 의미: **warn** = 위반 시 audit이 경고(강제 규칙) · **info** = 참고 관찰(강제 안 함, audit이 위반으로 안 띄움).

## 강제 규칙 (warn)

| 적용 대상 | 패턴 | 예시 | 관찰 |
|:---|:---|:---|:---|
| `src/*/` ROS 2 패키지 디렉토리 | `^(stonefish_[a-z][a-z0-9_]+\|nav_interfaces)$` | `stonefish_control`, `stonefish_slam`, `stonefish_albc_bridge` (명시 예외: `nav_interfaces`) | 9/9 |
| `src/**/*.py` Python 모듈 | `^[a-z][a-z0-9_]+\.py$` | `kalman.py`, `dead_reckoning.py` | 53/53, 26/26 (※ `__init__`·`_`접두·`*.launch.py` 제외) |
| `src/**/launch/*.launch.py` | `^[a-z][a-z0-9_]+\.launch\.py$` | `slam.launch.py`, `thruster_manager.launch.py` | 16/16 |
| `src/**/msg/*.msg` ROS 인터페이스 | `^[A-Z][A-Za-z0-9]+\.msg$` | `DVL.msg`, `NEDPose.msg`, `ThrusterState.msg` | (msg+srv 23/23 중) |
| `src/**/srv/*.srv` ROS 인터페이스 | `^[A-Z][A-Za-z0-9]+\.srv$` | `SetMode.srv` | (msg+srv 23/23 중) |
| `src/**/config/*.yaml` | `^([a-z][a-z0-9_]+\|[A-Z][A-Z0-9_]+)\.yaml$` | `slam.yaml`, `hybrid_controller.yaml`, `TAM.yaml`(약어 예외) | 24/24 |
| `src/**/scenarios/*.scn` 씬 파일 | `^[a-z][a-z0-9_]+\.scn$` | `world_caighouse.scn`, `world_seabed.scn` | 31/31 |
| `src/**/data/worlds/*.scn` 월드 씬 | `^[a-z][a-z0-9_]+\.scn$` | 동상 | 31/31 |

> **config yaml 약어 예외**: 파일명은 snake_case가 기본이나, 전부 대문자 약어(+선택적 숫자/언더스코어)는 허용 예외입니다 — 예: `TAM.yaml` = Thruster Allocation Matrix. 일반 PascalCase(예: `Hybrid.yaml`, `Tam.yaml`)는 여전히 위반으로 잡힙니다.

## 참고 관찰 (info — 강제 안 함)

| 적용 대상 | 패턴 | 예외 | 관찰 |
|:---|:---|:---|:---|
| `src/**/stonefish_ros2/{src,include}/**/ROS2*.{cpp\|h}` C++ 브리지 클래스 | `^ROS2[A-Z][A-Za-z]+\.(cpp\|h)$` | (진입점 2개는 글롭 밖이라 애초에 미적용) | 10/10 |

> **왜 info인가**: 패키지 안쪽 `stonefish_ros2/` 서브디렉토리의 클래스 정의 파일 10개는 모두 `ROS2<Name>` PascalCase입니다. 실행 가능한 노드 진입점 2개(`stonefish_simulator.cpp`, `stonefish_simulator_nogpu.cpp`)는 `src/` 바로 밑에 있어 이 글롭의 적용 대상이 아닙니다(패키지명 snake_case로 두는 ROS 2 C++ 정상 관례). 글롭이 진입점을 애초에 포함하지 않으므로 10/10이지만, 클래스 명명은 강제 대상이 아니라 참고 관찰로만 둡니다.

## 규칙에서 제외한 약한 관찰 (learned.md 후보)

- **모델 디렉토리 케이스 혼재**: `data/models/<name>/`가 kebab-case(`vasa-the-hold`, `wheel-wrek-isles-of-scilly`)와 단어 단수(`caighouse`, `terrain`)가 섞임 (9/13). 규칙화하기엔 너무 혼재 — 관찰로만 남김.
- **`world_` 접두 서브패턴**: `.scn` 31개 중 6개만 `world_` 접두 (6/31). 의무 아님.
- **도구 자동생성 디렉토리**: `wandb run-<ts>-<id>`, `gwo <ts>` 패턴은 사용자가 짓는 게 아니라 도구가 자동 생성했었음 → 명명 규칙 대상 아님. (해당 옵티마이저 출력 `stonefish_control_utils`는 이후 제거됨.)

## 변경 이력

- **2026-08-22 (codify)**: 패키지 디렉토리 정규식에 명시 예외 `nav_interfaces` 추가 —
  실해역(KMU/LIG) bag에 기록된 메시지 타입명이 패키지명을 고정하므로(rosbag 타입 매칭)
  `stonefish_` 접두사 개명이 bag 디코드를 깨뜨림. 같은 통합(sim repo
  `feat/mjkim-integration`)의 `sonar_yolo_ros2`는 반대로 `stonefish_sonar_yolo`로
  개명(albc 선례) — 예외는 데이터 호환이 강제하는 경우에만.
- **2026-06-23 (codify)**: cpp_ros2 글롭 0-매칭 수정(실제 패키지 `src/stonefish_sim/stonefish_ros2/` 한 단계 깊음 → 10개 매칭, 진입점 2개 글롭 밖). config yaml 정규식에 전대문자 약어 예외 추가(`TAM.yaml` 통과, PascalCase는 계속 위반). specificity 0.80→0.941(§4 재계산; `stonefish_control_utils` 제거로 optimizer 관련 structure 1 + ignore 3 규칙이 디스크에서 이미 빠져 분모 축소, preset 항목은 `data` 1개만 남음 → 16/17).
