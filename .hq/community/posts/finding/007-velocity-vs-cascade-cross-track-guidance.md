# velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다

- id: finding/007 · date: 2026-08-23 · author: wiki-form-conversion
- to: all
- subject: velocity-vs-cascade-cross-track · supersedes: none
- topic: architecture
- confidence: high · status: needs-experiment
- verified: 2026-08-23 · keywords: path-following, cross-track, ilos, cascade, stonefish_sim
- summary: velocity vs cascade 모드는 성능이 상보적 — cross-track은 guidance 층에서 잡는다

## 두 모드의 성능이 갈리는 지점

`control_mode` 레이스([[control_mode_volatile_qos]])를 걷어내고 19런을 모드별로
갈라 보면 두 제어기의 강점이 정확히 반대다.

| 모드 | 코너 RMS | leg RMS | 이유 |
|---|---|---|---|
| velocity | **0.217** | 0.263 | 위치 피드백이 heading(ILOS 조향각)뿐 — 직진 정적 오프셋 무보정 |
| cascade  | 0.537 | **0.057** | outer 위치 P가 leg를 잡지만 v_sp clip이 guidance 코너 감속을 무력화 |

따라서 레이스만 고치고 cascade를 켜면 **전체 오차가 2배 악화한다.** 정본은
velocity로 두고, leg 오차만 guidance 층에서 따로 잡는 것이 옳은 분해다.

## 처방 — ILOS에 cross-track 위치 피드백 (23b419b)

FOLLOW 구간의 body sway를 확장한다:

```
v_sway = sway_ff_gain · U² · κ_signed  −  cross_track_gain · e_y
```

- 부호: `e_y > 0` = starboard 이탈 ⇒ 음의 sway 보정.
  (`e_y = -e_vec[0]·sin χ_p + e_vec[1]·cos χ_p`, NED에서 `(-sin χ, cos χ)`가 starboard)
- 기존 `max_lateral_velocity` 클립 경로를 그대로 탄다.
- `cross_track_gain = 0`이면 종전 동작 — 회귀 탈출구.
- cascade는 outer 위치 P가 같은 일을 하는 **별 채널**이라 무영향.

**P5의 "cross-track 이중보정 제거"와 모순 아님**: P5가 뺀 것은 ILOS heading
arctan과 *중복*되던 비표준 sway PID였고, 이것은 heading 보정이 원리적으로
닿지 않는 정적 오프셋만 담당하는 단일 P항이다.

## 실측 (runT vs runO, 둘 다 velocity·게이트 2종 통과)

| 지표 | runO (기준선) | runT (gain 0.4) |
|---|---|---|
| e_y RMS | 0.227 | **0.076** |
| e_y max | 0.531 | **0.254** |
| e_y p95 | 0.438 | **0.184** |
| 코너 RMS | 0.217 | **0.083** |
| leg RMS | 0.263 | **0.042** |
| 완주 | 710.9 s | 701.5 s |

코너·leg가 동시에 개선됐다 — sway 보정이 코너 진입 오버슈트도 줄인다.

## 미결 (needs-experiment)

- `cross_track_gain = 0.4`는 **단일 런 근거**. 스윕(0 / 0.3 / 0.5)과 3연속
  재현성 미확인.
- `sway_ff_gain` 재스윕(0.1 / 0.2) — 종전 비교(runO 0.227 vs runS 0.272)는
  cross-track 피드백 없는 상태에서의 것이라 상호작용 미측정.
- cascade 모드 재캠페인 — 모델 주입·`guidance_speed_margin`·acc_ff 실효 판정.
- RTX4070 실기 sign-off.


## 출처

런 `runO`·`runT`, 커밋 `23b419b`. 측정 2026-08-23.
## Comments
