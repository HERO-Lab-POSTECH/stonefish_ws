# Domain Rules — stonefish_ws

<!-- Tailored per project. The other four slots are constant; this one is not. -->

수중 로봇 시뮬레이션(Stonefish)·제어·SLAM ROS 2 Humble colcon 워크스페이스.
워커가 듣지 않으면 반드시 틀리는 것만 적는다.

- **좌표계는 NED다 — 고치려 들지 마라.** 전역 프레임 `world_ned`(z-down), slam의
  로컬 TF 체인(`odom→base_link`)도 이름만 REP-105이고 데이터는 NED 자기정합.
  ENU 전환 제안은 결함이다. 정본: 각 repo `docs/CONVENTIONS.md` §2.0.
- **meta-repo와 하위 repo는 다른 remote다.** 루트는 `stonefish.repos`·`.hq/`만
  추적하고 `src/`는 gitignore — 코드 커밋·PR은 해당 하위 repo 안에서
  (`git -C src/stonefish_slam ...`). main 직접 커밋 금지, Conventional Commits,
  PR 테스트 증빙 필수 (정본: `CONTRIBUTING.md`).
- **테스트는 repo 루트에서** `python3 -m pytest`. slam은 pybind11 `.so` 5개를
  빌드 후 소스 트리로 스테이징해야 수집이 된다(안 하면 collection 실패가 정상).
  게이트: `bash .hq/config/experiments/profile/evaluator.sh` (마지막 줄 JSON pass).
- **테스트는 `load_module` fixture로 파일 경로 로드한다** — 패키지 import로
  바꾸면 ROS 없는 환경에서 수집이 터진다. 새 테스트도 같은 fixture를 쓴다.
- **빌드는 `colcon build --merge-install` 고정.** stonefish 코어는 1.3.0
  exact-version 매치 — upstream master로 올리면 빌드가 깨진다.
- 시뮬 physics 파라미터(`.scn`)와 알고리즘 변경을 한 PR에 섞지 않는다.
  `.scn` 수치는 튜닝값이지 버그가 아니다.
- 시뮬레이터 실행은 OpenGL 4.3+ GPU 필수 — 이 컨테이너에서는 pytest fast gate까지만
  가능하고, 닫힌루프 검증은 팀 GPU 머신 절차(`src/stonefish_slam/docs/RUN_TEST.md`)로.
- 훈련·시뮬 launch는 자동 실행 금지 — `omx queue-launch` 사람 승인 큐로만.
