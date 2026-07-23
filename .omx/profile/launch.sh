#!/usr/bin/env bash
# OMX 프로파일 - 실험 런 launch 레시피 (stonefish-ws). exp-loop은 이것을
# 'pending approval' 아티팩트로 큐에 넣을 뿐, 절대 자동 실행하지 않는다 (D4/B8).
# 사람이 검토 후 GPU 머신에서 직접 실행한다.
set -euo pipefail

WS="${OMX_PROJECT_DIR:-/workspace}"

# GPU 게이트 (시뮬레이터는 OpenGL 4.3+ GPU 렌더링 필요):
#   nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits

# Provenance: 런 시점 커밋 기록 → 결과 채점 시
#   omx run-record --candidate-commit "$(git -C $WS/src/stonefish_slam rev-parse HEAD)"

# --- 환경 (매 셸 필수 — stonefish_slam/docs/RUN_TEST.md §0) -----------------
# source /opt/ros/humble/setup.bash
# source "$WS/install/setup.bash"   # merge-install 레이아웃

# --- sim + slam 폐루프 런 (RUN_TEST.md §3 요약; sim 먼저 → slam 나중) --------
# 터미널 A: ros2 launch stonefish_ros2 <sim_launch>.launch.py
# 터미널 B: ros2 launch stonefish_slam slam.launch.py
# 기록:     ros2 bag record -o "$WS/experiments/<run_id>/bag" \
#             /bluerov2/odometry /bluerov2/fls/image <slam 출력 토픽>

echo "launch.sh is a template; 실제 런 커맨드는 사람이 채우고 직접 실행한다."
