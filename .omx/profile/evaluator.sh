#!/usr/bin/env bash
# OMX evaluator — stonefish-ws SLAM 검증 엔진 (pending approval).
#
# CONTRACT: 마지막 non-empty stdout 줄은 반드시 JSON {"pass": <bool>} (+선택 "score").
# keep_policy=pass_only 이므로 score는 생략 가능.
#
# 2단 구조:
#  [1] fast gate (지금 이 컨테이너에서 실행 가능): 양 repo pytest 스위트.
#      결정론적이며 GPU/X 불필요 — CI·컨테이너 공용 verdict.
#  [2] live eval (팀 GPU 머신 전용, 주석 슬롯): sim+slam 폐루프를 띄워 rosbag 기록
#      후 궤적 오차(ate_rmse/rpe_*)를 계산. 절차는 stonefish_slam/docs/RUN_TEST.md.
#      ATE 계산 도구가 repo에 아직 없으므로(2026-07-23 기준) 도입 시 이 슬롯을 채운다.
set -euo pipefail

WS="${OMX_PROJECT_DIR:-/workspace}"

# --- [1] fast gate: 양 repo pytest -----------------------------------------
# slam의 pybind11 확장(.so)은 colcon build 산출물을 소스 트리에 스테이징해야
# repo-root pytest가 import 가능 (관례: *.so는 gitignore됨). 빌드 전이면 skip —
# 이 경우 slam pytest가 collection에서 실패해 fail로 드러난다(silent pass 없음).
if ls "$WS"/build/stonefish_slam/*.so >/dev/null 2>&1; then
  cp -u "$WS"/build/stonefish_slam/*.so "$WS/src/stonefish_slam/stonefish_slam/" 2>/dev/null || true
fi

sim_rc=0; slam_rc=0
(cd "$WS/src/stonefish_sim"  && python3 -m pytest -q >/dev/null 2>&1) || sim_rc=$?
(cd "$WS/src/stonefish_slam" && python3 -m pytest -q >/dev/null 2>&1) || slam_rc=$?

# --- [2] live eval 슬롯 (팀 GPU 머신에서 활성화) ----------------------------
#   source /opt/ros/humble/setup.bash && source "$WS/install/setup.bash"
#   ros2 launch stonefish_ros2 <sim_launch>   # 터미널 A 상당
#   ros2 launch stonefish_slam slam.launch.py # 터미널 B 상당
#   ros2 bag record /bluerov2/odometry /bluerov2/slam/pose ...
#   → bag에서 ate_rmse/rpe_trans/rpe_rot 계산 후 아래 verdict에 score 반영

if [[ "$sim_rc" -eq 0 && "$slam_rc" -eq 0 ]]; then
  echo '{"pass": true}'
else
  echo "{\"pass\": false}"
fi
