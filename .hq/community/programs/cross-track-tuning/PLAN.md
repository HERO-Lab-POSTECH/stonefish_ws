# Program: cross-track-tuning

**Status: APPROVED 2026-08-23 — 결정 3건 확정, 아래 Decision log 참조.**

## Objective

요청자 원문 (2026-08-23, 두 발언):

> 지금 보면 로봇이 4dof인데 cross track error를 좀 못잡는데 이건 왜 이러는 걸까?

> 지금 run은 내가 말한 문제를 제외하고는 전부 만족스러워. 근데 이 문제는 고칠
> 필요가 있을 것 같아. 문제를 조사하고 분석 및 검토 후 계획 세워줄래?

아래 모든 결정은 이 두 줄에 대해 논증한다. "전부 만족스러워"가 제약이다 —
cross-track 외의 거동(완주 시간·코너 형상·속도)을 바꾸는 처방은 목표에 반한다.

## Diagnosis

- velocity 모드는 위치 피드백이 heading(ILOS 조향각)뿐이라 직진 구간 정적
  cross-track 오프셋을 원리적으로 못 닫는다. 차량은 4-DOF라 sway를 낼 수
  있는데 guidance의 lateral 명령이 곡률 feedforward뿐이었다.
  `[EVIDENCE: wiki velocity_vs_cascade_cross_track_guidance, runO leg RMS 0.263]`
- cascade는 outer 위치 P로 leg를 잡지만(0.057) 코너가 무너진다(0.537).
  모드 전환만으로는 전체가 2배 악화한다. `[EVIDENCE: 동 wiki, 19런 모드별 분리]`
- 19런 전수 비교는 `control_mode` volatile QoS 레이스로 교란돼 있었다.
  `db2c3e9`로 차단, 러너 게이트 2종 상설화.
  `[EVIDENCE: wiki control_mode_volatile_qos]`
- 처방(`23b419b`)은 이미 적용·1런 검증됐다: `cross_track_gain` 0.4에서
  e_y max 0.531→0.254, leg RMS 0.263→0.042, 완주 710.9→701.5 s.
  `[EVIDENCE: runT vs runO, 게이트 2종 통과]`

즉 **이 프로그램은 미해결 문제를 푸는 라인이 아니라, 이미 통과한 처방의
재현성·게인 민감도를 확정하는 라인이다.** 그 전제로 설계한다.

## Parameter coupling

### Tier 1 — follows mechanically; nothing to set

| key | 값 | 비고 |
|:--|:--|:--|
| `max_lateral_velocity` | 0.5 (held) | `[DERIVED]` sway 명령 `cross_track_gain·e_y`의 포화점 = 0.5/gain. gain 0.4 → e_y 1.25 m, gain 0.5 → 1.0 m. runT 실측 max e_y 0.254이므로 스윕 전 구간에서 미포화 — 게인 차이가 클립에 가려지지 않는다. |
| `sway_ff_gain` | 0.1 (held in C1/C2) | C3에서만 변수. FF와 FB는 같은 sway 채널에 합산되므로 동시 변경 금지. |

### Tier 2 — real coupling; a decision is required

| knob | current | options | coupling | marker |
|:--|:--|:--|:--|:--|
| cascade 재캠페인 범위 | 미실행 | (a) 이번 프로그램에서 제외 (b) C5로 편입 | P2 모델 주입·`guidance_speed_margin`·acc_ff의 실효는 cascade에서만 판정 가능. 편입 시 최소 4런(+50분)이고, velocity 정본과 무관하므로 목표 두 줄에 직접 기여하지 않는다. | `[DECISION-REQUIRED: cascade-recampaign]` |
| `cross_track_gain` 스윕 폭 | 0.4 단일 | (a) 0 / 0.3 / 0.4 / 0.5 (b) 0.3 / 0.4 / 0.5 | (a)의 gain 0은 runO 재현이라 기준선을 이 캠페인 안에서 다시 찍는다 — 레이스 수정 후 기준선이라 값이 다를 수 있다. (b)는 1런(12분) 절약하되 수정 전 runO를 기준선으로 계속 인용해야 한다. | `[DECISION-REQUIRED: sweep-includes-zero]` |

### Tier 3 — no coupling to the variables under test; leave byte-identical

`cruise_speed` 0.7 · `lookahead_distance` 3.0 · `adaptive_lookahead` false ·
`path_following_mode` velocity · `dynamics_params.yaml` 전체 ·
cascade 게인 일체 · allocator·`max_thrust`·`.scn` physics.

## Decisions for the user

- `[DECISION-REQUIRED: cascade-recampaign]` **cascade 모드 재캠페인을 이
  프로그램에 넣을까?** 권고 = **(a) 제외.** 목표 두 줄은 velocity 정본의
  cross-track에 대한 것이고, cascade는 켜는 순간 전체 오차가 2배가 되는
  현재로선 정본 후보가 아니다. 비용 4런·50분. 다른 선택의 대가: P2가 만든
  모델 주입 코드(M_eff·damping ff·inner Kp)가 **한 번도 폐루프 검증을 못 받은
  채** 남는다 — 죽은 코드는 아니지만 근거 없는 코드로 남는다.
- `[DECISION-REQUIRED: sweep-includes-zero]` **스윕에 gain 0(무피드백)을
  포함할까?** 권고 = **(a) 포함.** 레이스 수정 후 velocity 기준선을 이 캠페인
  안에서 직접 찍어야 runO(수정 전 측정)를 인용하지 않아도 된다. 비용 1런·12분.
  다른 선택의 대가: 개선폭 주장이 캠페인 밖 런에 의존한다.

## Decision log (2026-08-23, 요청자 확정)

| marker | 결정 | 근거 |
|:--|:--|:--|
| `[DECISION-REQUIRED: cascade-recampaign]` | **제외** | velocity 정본에 집중. 모델 주입 코드(M_eff·damping ff·inner Kp 140/124/128)는 근거 없는 코드로 남는 것을 감수 — 별도 프로그램 대상 |
| `[DECISION-REQUIRED: sweep-includes-zero]` | **포함** | 레이스 수정 후 기준선을 캠페인 안에서 직접 측정, runO(수정 전) 인용 제거 |
| 실행 시점 | **즉시** | 계획 확정과 동시에 순차 실행 |

결정 반영 후 런 수가 8~9 → **7런**으로 줄었다: C1의 3런이 C2의 0.4 지점을
겸하고, C3는 `sway_ff_gain` 0.2 1런만 추가하면 되기 때문(0.1은 C1/C2가 이미 커버).

`omx queue-launch`는 **의도적으로 건너뛴다** — 그 verb의 목적인 사람 승인
게이트를 요청자가 위 표에서 직접 통과시켰고, 대상이 GPU 훈련이 아니라 12분짜리
시뮬 측정 런이라 proposal-id 7개를 형식으로 만드는 것은 원장에 값을 더하지
않는다. 런 provenance는 `campaign-log`로 남긴다.

## Predicted outcome

정직한 예측: **목표는 이미 달성돼 있다**(e_y max 0.254 < 0.5). 이 라인이
새로 만들어낼 것은 성능이 아니라 *신뢰*다 —

- C1(3연속 재현)에서 RMS 산포가 0.01 이내면 runT가 우연이 아님이 확정된다.
  0.05 이상 벌어지면 남은 비결정성이 하나 더 있다는 신호다.
- C2 스윕에서 0.3~0.5가 모두 목표를 통과하면 게인은 **민감하지 않다**가
  결론이고, 튜닝 항목에서 내려도 된다. 특정 값만 통과하면 그 반대다.
- C3(`sway_ff_gain`)은 FF·FB 상호작용 확인용이며 개선 기대는 낮다.

성능 향상을 기대하고 예산을 쓰는 라인이 아니라는 점을 요청자가 알고
승인하는 것이 맞다.

## Eval schedule

런 1회 = krit_lawnmower 완주 ~700 s + 기동·정리 ≈ 12분. 전 런 게이트 2종
(활성 모드 == velocity / wrench 50.0 Hz) 통과 필수, 불일치 시 폐기·재측정.

| 캠페인 | 런 | 변수 | 판정 |
|:--|:--|:--|:--|
| C1 재현성 | 3 (U1·U2·U3) | 없음 — `cross_track_gain` 0.4 고정 | RMS 산포 < 0.01 |
| C2 게인 스윕 | 3 (U4·U5·U6) | `cross_track_gain` 0 / 0.3 / 0.5 (0.4는 C1 겸용) | e_y max < 0.5 통과 구간의 폭 |
| C3 FF 재스윕 | 1 (U7) | `sway_ff_gain` 0.2 (gain은 C2 최적값) | 코너 RMS 개선 여부 |
| C4 판정 | 0 | — | `e_y max < 0.5` **및** leg RMS < 0.1, 3연속 |

지표는 런당 4종 고정 수집: e_y RMS/max/p95, 코너·leg 분할 RMS, e_z RMS/max,
완주 시간·주행거리. 곡선이 아니라 런별 스칼라라 조밀도 문제는 없다.

## Wall-clock and budget

7런 × 12분 ≈ **84분** (cascade 재캠페인 제외 확정). 자동 실행하지 않는다 —
`omx queue-launch`로 큐에만 넣고 사람 승인 후 발사.

## Deferred

`omx wiki list --status needs-experiment` 전수 (2026-08-23 시점 1건):

- `velocity_vs_cascade_cross_track_guidance` — 이 프로그램이 **담당한다**:
  `cross_track_gain` 스윕(C2)·3연속 재현성(C1)·`sway_ff_gain` 재스윕(C3).
  같은 페이지의 남은 두 리드는 아래로 이월:
  - cascade 재캠페인 → `[DECISION-REQUIRED: cascade-recampaign]` 대기, 기본 defer
  - RTX4070 실기 sign-off → **defer**: 시뮬 판정이 확정된 뒤에 하는 것이 순서고,
    실기는 팀 GPU 머신 일정에 묶인다

`--status needs-apply-before-retrain` 전수: **0건** (열린 blocking 없음).
