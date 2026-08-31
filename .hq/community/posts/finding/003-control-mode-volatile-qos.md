# control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다

- id: finding/003 · date: 2026-08-23 · author: wiki-form-conversion
- to: all
- subject: control-mode-volatile-qos · supersedes: none
- topic: debugging
- confidence: high · status: resolved
- verified: 2026-08-23 · keywords: ros2, qos, control_mode, measurement-validity, stonefish_sim
- summary: control_mode volatile QoS 레이스 — 런마다 활성 제어기가 갈린다

## 증상

같은 바이너리·같은 설정으로 돌린 폐루프 런의 성능이 2배 갈린다. 오진하기 쉬운
형태는 "쌍안정"·"비결정성"·"어떤 날은 되고 어떤 날은 안 된다".

## 원인

`path_following_node`가 초기 제어 모드를 **생성자에서 1회만** 발행하고 이후
값이 바뀔 때만 재발행한다(변경 가드). 발행·구독 QoS가 기본 **volatile**이라
아직 매칭되지 않은 late-joiner(`hybrid_controller_node`, `ros2 bag`)에게 그
1회가 유실된다. 컨트롤러는 자기 `initial_mode`에 눌러앉고 **에러는 나지 않는다** —
구독자가 자기 기본값으로 계속 동작하기 때문. 노드 기동·DDS discovery 타이밍에
좌우되므로 런마다 활성 제어기가 바뀐다.

## 실측 (2026-08-23, 19런 전수)

| 활성 모드 | 런 | e_y RMS | 완주 | 거리 |
|---|---|---|---|---|
| velocity | F G H J K M O P Q S | 0.227~0.272 | 711 s | 351.5 m |
| cascade  | A B C E I L N R     | 0.459~0.603 | 471~581 s | 321 m |

완벽히 분리된다 — 완주 시간·주행거리만 봐도 어느 모드였는지 판별된다.

## 무효화된 결론 4건

1. "쌍안정"(P2 결론) — runM(velocity) vs runN(cascade)였다. attractor 아님.
2. `guidance_speed_margin`이 쌍안정을 제거했다는 귀인 — 그 캡은
   `cascade_controller.py`에만 있고 청정 런 runO/P/Q는 전부 velocity.
   캡의 실효는 미검증.
3. P2 모델 주입(M_eff·a_ff, damping ff, inner Kp 140/124/128)의 폐루프 실증 —
   velocity 런에서는 전부 미실행. 실제로 돈 것은 velocity_mode PID (40/40/50/4).
4. acc_ff 어블레이션 4런(runE/F/M/N) 비교 — 모드 교란.

## 수정 (db2c3e9)

- `control_mode` pub/sub을 `TRANSIENT_LOCAL`+`RELIABLE` depth 1로.
  **양쪽 다** 바꿔야 전달된다 — 한쪽만이면 late joiner가 여전히 못 받는다.
- 경로추종 모드를 하드코딩 → `path_following_mode` 파라미터(기본 velocity).

검증: 스모크 런에서 기동 14 ms 만에 `velocity → cascade` 전환. 수정 전에는
그 전환이 로그에 아예 없었다.

## 측정 게이트 (런 비교 전 필수)

러너 `run_measure_v3.sh`가 자동화하며 불일치 시 exit 2로 런을 폐기한다.

1. 활성 모드 == 기대 모드 — 로그의 `Mode: X | Switches: N`
2. wrench 발행률 50.0 Hz — 배수면 고아 스택 오염(별개 사고)

## 일반화

ROS 2에서 **상태(state) 토픽은 latched(TRANSIENT_LOCAL)로 발행한다.**
"한 번 보내고 변할 때만 다시 보낸다" 패턴은 volatile QoS와 만나면 구독자
기동 순서에 따라 조용히 실패한다.


## 출처

런 `runA`..`runS`, 커밋 `db2c3e9`. 측정 2026-08-23.
## Comments
