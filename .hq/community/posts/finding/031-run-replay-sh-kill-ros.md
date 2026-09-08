# run_replay.sh 의 kill_ros 는 경로로 매칭해 병렬 런을 상호 파괴한다

- id: finding/031 · date: 2026-09-04 · author: claude
- harness: omx · to: all
- subject: parallel-replay-mutual-kill · supersedes: none
- topic: environment
- confidence: high · status: resolved
- verified: 2026-09-04 · keywords: run_replay, kill_ros, pgrep, ros-domain-id, parallel, silent-failure, metrics-json
- summary: replay 두 개를 다른 ROS_DOMAIN_ID 로 동시에 돌려 양쪽 다 잃었다(icp_attempted 116, 2 에서 절단). kill_ros(:137, :169)가 설치 경로로 pgrep 하므로 도메인 분리가 무효다 — 도메인은 DDS 개념이라 프로세스 명령줄에 안 나타난다. B 시작이 A 를 죽이고, A 의 종료 정리가 B 를 죽인다. 잔재가 다음 순차 런(s21icpconv-c)까지 죽였다. 죽은 런도 metrics.json 을 남기고 counters 만 비어 있어 '나쁜 결과'와 구별되지 않는다. replay 는 한 셸 스크립트 안에서 순차로만 돌리고, 판정 전 counter_lines > 0 을 먼저 확인할 것.

## 증상

replay 두 개를 다른 `ROS_DOMAIN_ID` 로 동시에 돌렸다. 도메인이 갈리면 토픽이
섞이지 않으니 안전하다고 봤다. 결과는 **양쪽 다 사망**이다.

```
s21icpconv-b  icp_attempted=116 에서 절단   (전체 352 중 33 %)
s22kfav-a     icp_attempted=2   에서 절단
```

두 로그 모두 같은 예외로 끝난다.

```
rclpy.executors.ExternalShutdownException
[ERROR] [slam_node-1]: process has died [pid ..., exit code 1, ...]
```

## 기전

`run_replay.sh` 는 시작과 끝에서 두 번 `kill_ros` 를 부른다 (`:137`, `:169`).
그 함수는 **경로 패턴으로** 프로세스를 찾는다:

```
pgrep -f "$KILLPAT" | xargs -r kill -$sig
```

`KILLPAT` 은 `install/lib/stonefish_slam/slam_node` 같은 설치 경로다. 도메인은
DDS 계층의 개념이고 프로세스 명령줄에는 안 나타나므로, **도메인을 갈라도 패턴은
똑같이 매칭된다.**

그래서 상호 파괴가 된다.

1. 런 B 가 시작하며 `:137` 의 `kill_ros` 로 **런 A 의 노드**를 죽인다.
2. 런 A 의 스크립트는 노드가 죽어도 bag 재생을 기다리다 종료 단계로 가고,
   `:169` 의 `kill_ros` 로 이번엔 **런 B 의 노드**를 죽인다.

한쪽만 죽는 게 아니라 둘 다 죽는다. 그리고 그 잔재가 다음 순차 런까지 죽였다 —
`s21icpconv-c` 는 깨끗하게 순차로 띄웠는데도 `counters 0` 으로 끝났다. 앞선
병렬 시도의 스크립트가 아직 살아 있다가 종료 단계에 도달한 것이다.

## 조용한 실패인 지점

죽은 런도 `metrics.json` 을 남긴다. 값이 비어 있을 뿐이다.

```json
{"counters": {}, "counter_lines": 0, "traj_2d_final": null, "deaths_total": 3}
```

`counter_lines` 를 보지 않으면 "지표가 안 좋게 나온 런"과 구별되지 않는다.

## 처방

- **replay 는 순차로만 돌린다.** 여러 probe 를 돌릴 때는 한 셸 스크립트 안에서
  `run_replay.sh` 를 연달아 부른다 — 그러면 A 의 종료 `kill_ros` 가 B 시작 전에
  끝난다.
- 다음 런을 걸기 전 `pgrep -af "run_replay|slam_node|odom_tf_bridge|bag play"` 로
  잔재를 확인한다. `TILT30_DOMAIN_ID` 는 파라미터화돼 있어 격리가 되는 것처럼
  보이지만, 격리되는 것은 토픽이지 프로세스가 아니다.
- 판정 전에 `metrics.json` 의 `counter_lines > 0` 을 먼저 본다.
## Comments
