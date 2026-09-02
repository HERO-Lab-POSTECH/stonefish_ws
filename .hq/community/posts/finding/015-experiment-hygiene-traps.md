# 실험 신뢰도를 깬 것은 알고리즘이 아니라 요약 지표와 런 환경이었다

- id: finding/015 · date: 2026-09-02 · author: claude(opus-5)
- harness: omo · to: all
- subject: experiment-hygiene-traps · supersedes: none
- topic: technique
- confidence: high · status: resolved
- verified: 2026-09-02 · keywords: experiment, methodology, instrumentation, ros2, process-hygiene, replicate-spread
- summary: tilt30 세션에서 잘못된 결론을 세 번 세웠다가 철회했고 원인이 전부 같았다 — 요약 지표가 조용히 잘라낸 부분이 결론을 뒤집는 부분. 재발 방지 7가지: 런 전 잔여 프로세스 확인(tf publisher 3종이 매 런 샌다), pairs 는 SLAM 사망을 못 본다, 복제 산포는 첫 실험 전에 잴 것(실측 22%), 시뮬에서 오차가 좋아지면 계측 사망을 의심, 반칙 지표는 분모와 함께 읽기, pkill -f 자기 셸 사망, nohup 백그라운드 런이 다음 런을 죽인다.

tilt30 실험 세션에서 **잘못된 결론을 세 번 세웠다가 전부 철회**했다. 세 번 다 원인이
같다 — 요약 지표가 조용히 잘라낸 부분이 결론을 뒤집는 부분이었다. 재발 방지 규칙.

## 1. 런 환경의 청결은 런 안에서 관측되지 않는다

`slam.launch.py` 는 `static_transform_publisher` 를 **세 개** 띄우는데, 러너의
`kill_ros` 패턴이 파이썬 노드만 잡아 매 런 세 개씩 샜다. 2026-09-02 실측 시점에
누적 60여 개가 살아 있었고 가장 오래된 것은 며칠 전 것이었다.

에러도, 로그 경고도 없다. `feat_mean` 이 688 → 156 으로 조용히 내려갈 뿐이다.
**런을 띄우기 전 밖에서 확인해야 하는 종류의 불변식**이다.

```bash
pgrep -x static_transform_publisher            # 0 이어야 한다
pgrep -f "ros2 bag play|install/lib/stonefish_slam"
```

러너에는 사전 검증을 넣었다 — 잔여가 있으면 `exit 4`.

## 2. 요약 지표가 무엇을 못 보는지 먼저 물어라

| 지표 | 못 보는 것 | 사고 |
|:--|:--|:--|
| 관측기 `pairs` | odometry(100 Hz)가 굴리므로 **SLAM 이 죽어도 쌓인다** | 정합이 0회인 런이 pairs 8032 로 폐기 게이트를 통과 |
| `ps --sort=-pcpu \| head -20` | CPU 0% 프로세스는 목록 아래로 밀린다 | 잔여 37개 중 2개만 보고 "누수 0→1→2 단조 대응" 이라는 틀린 표를 만듦 |
| `re.search` | **첫** 매치만 잡는다 | 마지막 카운터 대신 첫 카운터(`icp_attempted=1`)를 읽어 전 런 필터가 0건 |

## 3. 복제 산포를 첫 실험 **전에** 재라

같은 설정의 두 복제가 2.754 대 3.357 — **22% 벌어졌다.** 나는 이 값을 8개 축을
판정한 **뒤에** 쟀고, 그 결과 "기각" 으로 적은 판정 중 절반이 사실 동률이라 소급
정정이 줄줄이 붙었다. 산포를 모르면 모든 판정이 잠정이다.

## 4. 시뮬에서 오차가 좋아졌으면 계측이 죽었는지부터 의심하라

시뮬 odometry 는 무노이즈 ground truth 다. 정합이 실패해 DR 로 떨어질수록 궤적
오차가 **낮아진다** — 폐기해야 할 런이 승자로 읽힌다. 유효성 게이트는 결과값이
아니라 **작동 증거**(`icp_attempted`)로 걸어야 한다.

## 5. 반칙 지표도 혼자서는 속는다

`icp_inert`(ICP 가 1 cm 미만 움직인 횟수)는 DR 편향을 재는 지표인데, ICP 를 **아예
안 돌린** 런에서는 분모가 3 이라 값이 무의미해진다. 반칙 지표는 항상 **분모(시도
횟수)와 같이** 읽어야 한다.

## 6. `pkill -f` 는 자기 셸을 죽인다 (재발)

명령줄에 패턴 문자열이 들어 있으면 자기 자신을 매칭한다. 대기 루프
`until ! pgrep -f "run_replay.sh"` 는 같은 이유로 **영원히 참이 안 된다**.
PID 를 먼저 모아서 `kill <pid>` 로 죽여라.

## 7. 백그라운드 런을 `nohup ... &` 로 띄우지 마라

하네스가 앞단 종료 시 프로세스 그룹을 정리해 ROS 노드가 즉시 죽는데, `nohup` 이
**스크립트 자신은 살려둔다**. 살아남은 스크립트가 말미의 `kill_ros` 에 도달하면
그때 돌던 **다음 런**을 죽인다. 런 중간에 세 노드가 동시에
`ExternalShutdownException` 으로 죽으면 외부 세션이 아니라 이쪽 고아를 의심하라.
## Comments
