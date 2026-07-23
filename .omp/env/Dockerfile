# syntax=docker/dockerfile:1.6
# ── stage: builder ──────────────────────────────────────────
FROM ros:humble-ros-base AS builder

# stonefish 빌드 의존성 (실측: README Dependencies + CMakeLists find_package)
#   OpenGL·SDL2·Freetype·OpenMP(REQUIRED) + glm(>=0.9.9). glew는 불필요.
RUN --mount=type=cache,target=/var/cache/apt \
    apt-get update && apt-get install -y --no-install-recommends \
      build-essential cmake git \
      libgl1-mesa-dev libsdl2-dev libfreetype-dev libglm-dev libomp-dev \
      python3-vcstool python3-colcon-common-extensions

# SDL2 함정 (실측: stonefish README) — sdl2-config.cmake의 "-lSDL2 " 뒤 공백 제거.
RUN sed -i 's/-lSDL2 /-lSDL2/' /usr/lib/x86_64-linux-gnu/cmake/SDL2/sdl2-config.cmake

# 소스 가져오기 (vcstool)
WORKDIR /ws
COPY stonefish.repos .
RUN mkdir -p src && vcs import src < stonefish.repos

# underlay: stonefish C++ 라이브러리를 /opt/stonefish에 빌드
WORKDIR /ws/src/stonefish/build
RUN cmake .. -DCMAKE_INSTALL_PREFIX=/opt/stonefish -DCMAKE_BUILD_TYPE=Release \
 && make -j"$(nproc)" \
 && make install

# rosdep가 못 잡는 slam 빌드 의존성 명시 설치 (slam CMakeLists find_package, package.xml 미선언)
RUN apt-get update && apt-get install -y --no-install-recommends \
      liboctomap-dev pybind11-dev \
 && rm -rf /var/lib/apt/lists/*

# rosdep: sim/slam의 package.xml 의존성 설치
# --skip-keys: stonefish(underlay), ament_python(rosdep DB 미등록), pcl(rosdep DB 미등록)
WORKDIR /ws
RUN apt-get update \
 && rosdep update \
 && rosdep install --from-paths src --ignore-src -y \
      --skip-keys "stonefish ament_python pcl" \
 && rm -rf /var/lib/apt/lists/*

# overlay: sim/slam colcon 빌드 (stonefish underlay를 CMAKE_PREFIX_PATH로)
# stonefish_description/launch 디렉토리가 소스에 없어 cmake install 실패 → 빈 dir 생성
RUN mkdir -p src/stonefish_sim/stonefish_description/launch \
 && . /opt/ros/humble/setup.sh \
 && export CMAKE_PREFIX_PATH=/opt/stonefish:$CMAKE_PREFIX_PATH \
 && colcon build --merge-install \
      --cmake-args -DCMAKE_BUILD_TYPE=Release \
 && rm -rf build log

# ── stage: runtime ──────────────────────────────────────────
FROM ros:humble-ros-base AS runtime

# 런타임 의존성 (빌드 도구 없음 = 슬림). slam이 octomap 링크 → liboctomap 런타임 필요.
RUN apt-get update && apt-get install -y --no-install-recommends \
      libsdl2-2.0-0 libfreetype6 libglm-dev libgomp1 liboctomap1.9 \
      ros-humble-image-transport ros-humble-cv-bridge \
      ros-humble-octomap-msgs ros-humble-pcl-conversions ros-humble-pcl-msgs \
      mesa-utils \
 && rm -rf /var/lib/apt/lists/*

# underlay + overlay 산출물만 COPY
COPY --from=builder /opt/stonefish /opt/stonefish
COPY --from=builder /ws/install /ws/install

ENV LD_LIBRARY_PATH=/opt/stonefish/lib:${LD_LIBRARY_PATH}

# entrypoint는 Task 5에서 활성화:
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
