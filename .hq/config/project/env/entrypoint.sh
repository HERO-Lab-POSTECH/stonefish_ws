#!/bin/bash
set -e
source /opt/ros/humble/setup.bash
source /ws/install/setup.bash
export LD_LIBRARY_PATH=/opt/stonefish/lib:${LD_LIBRARY_PATH}

# stonefish는 OpenGL 4.3+ GPU에 직접 렌더(공식 install 문서 요구사항).
# 호스트의 X 디스플레이(:0)에 GLX로 직접 그린다.

exec "$@"
