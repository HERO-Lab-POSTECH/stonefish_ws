# docker 환경 자산 생성 관찰 (2026-07-23, omp-env)

- id: decision/004 · date: 2026-07-23 · author: wiki-form-conversion
- to: all
- subject: docker-env-genesis · supersedes: none
- topic: environment
- confidence: none · status: none
- verified: 2026-07-23 · keywords: docker, env, deployment
- summary: docker 환경 자산 생성 관찰 (2026-07-23, omp-env)

INDEX: stonefish-dev 이미지 정본 생성 — 베이스 선택·버전 함정·토폴로지 근거


- **베이스 `osrf/ros:humble-desktop`**: nvidia/cudagl·nvidia/opengl 이미지는 업데이트 중단(2023~)이라 배제. 현행 표준 = ROS desktop 이미지 + 호스트 nvidia-container-toolkit이 런타임에 드라이버 라이브러리 주입(`NVIDIA_DRIVER_CAPABILITIES=graphics,utility,compute`). desktop 변형이어야 rviz2·GL 라이브러리 포함.
- **Stonefish 버전 함정(핵심)**: 코어 CMake가 `COMPATIBILITY ExactVersion` — stonefish_ros2의 `find_package(Stonefish REQUIRED 1.3.0)`과 정확히 일치해야 함. upstream master=1.6.0-dev이므로 **HERO fork(1.3.0) 고정**. `/usr/local` 설치로 CMAKE_PREFIX_PATH 무설정 탐지.
- **단일 full-stack 이미지**(sim/slam 분리 안 함): 팀 목표가 "동일 환경"이고 slam이 sim(stonefish_msgs)에 빌드 의존 — 이미지 2종은 drift 벡터만 추가.
- **토폴로지**: bind-mount 개발 모델(소스는 호스트, 의존만 이미지에 베이크), `network_mode: host`+`ipc: host`(FastDDS 발견+SHM — 하나만 켜면 SHM이 조용히 실패), X11 3요소(DISPLAY·/tmp/.X11-unix·Xauthority)+`QT_X11_NO_MITSHM=1`, 비루트 dev 사용자 UID/GID 빌드 인자(bind-mount 소유권).
- **OOM 가드**: 코어 빌드 `MAKE_JOBS=4` 기본(커뮤니티 Dockerfile들 관행; 저사양 호스트에서 -j$(nproc) OOM 사례).
- **검증 한계**: 이 컨테이너에 docker CLI 없음 → `docker compose config` 대신 YAML 파스 + 스키마 수동 검증. 실빌드 검증은 호스트에서 필요(사용자 실행 — omp는 not-a-build-runner).
- 규칙 후보(omp-learn 승격 대상): "docker 자산은 .omp/env 정본 + repo docker/ 사본, 해시 동기 검사" — 아직 규칙 아님.

- **2026-07-23 (후속) — bringup 이관**: 사용자가 호스트(ksm-ubuntu)에서 전용 배포 repo `stonefish_bringup`을 생성·실빌드 검증(3.76GB·OpenGL 4.3 기동)함에 따라 Docker SSOT가 bringup repo로 이동. 구 bind-mount 키트(.omp/env 구판 + repo docker/ 사본 + HOST_UID compose)는 제거하고 .omp/env는 bringup byte-identical 미러로 전환. 설계 차이: bind-mount 개발용 → 소스 bake 배포용(builder→runtime 멀티스테이지, :0 직접 GLX).
## Comments
