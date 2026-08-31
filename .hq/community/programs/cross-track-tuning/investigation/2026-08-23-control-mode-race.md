# control_mode 레이스 — 조사·분석·계획 (2026-08-23)

## 사용자 요청 원문

> 지금 run은 내가 말한 문제를 제외하고는 전부 만족스러워. 근데 이 문제는 고칠 필요가
> 있을 것 같아. 문제를 조사하고 분석 및 검토 후 계획 세워줄래?

여기서 "내가 말한 문제" = **직진 leg에서 cross-track error가 정적 오프셋으로 남고
아무도 줄이지 않는 현상** (rviz 육안 관찰 → bag 실측으로 확증).

## 1. 조사 — 무엇이 사실인가

### 1.1 증상의 직접 원인: 활성 모드에 cross-track 피드백이 없다

`velocity` 모드의 sway 오차는 **순수 속도 오차**다 — `e_v = v_des − v`
(`position_controller.py:180`). 위치 항이 없다. 위치 피드백은 heading 하나뿐.

`v_des`(sway)는 guidance가 주는데 곡률 feedforward 하나뿐이다:
`v_lateral = sway_ff_gain · v² · κ` (`ilos_guidance.py:835`). **직진 구간 κ=0 → v_des=0.**

P5에서 ILOS의 cross-track heading 항 `arctan(−e_y/Δ)`를 제거했고 주석이 이유를 밝힌다:
"e_y 보정은 cascade outer가 전담"(`ilos_guidance.py:764`). 그 cascade가 안 켜지면
**루프 어디에도 cross-track 피드백이 없다.**

bag 실측 (runO, 직진 leg):

| 구간 | e_y | e_yaw | u | v_body(sway) | Fx | Fy |
|--:|--:|--:|--:|--:|--:|--:|
| 100–111 s | −0.282 | −0.5° | 0.656 | −0.002 | 29.3 | **−0.1 N** |
| 112–123 s | −0.274 | −0.6° | 0.651 | −0.000 | 28.4 | **−0.0 N** |
| 378–394 s | +0.195 | −0.5° | 0.603 | +0.000 | 29.9 | **+0.0 N** |

추력 포화 아님(allocator 스케일 경고 0건). **명령 자체를 안 한다.**

### 1.2 근본 원인: 모드 전달이 레이스다

`path_following_node.py:183`이 `current_control_mode = 'cascade'`로 초기화하고
생성자에서 **1회 발행**(L208-211). 이후 L385가 `if new_mode != self.current_control_mode:`
변경-가드라 값이 안 바뀌면 재발행하지 않는다.

QoS는 양쪽 다 기본값 = **volatile**:
- 발행: `create_publisher(String, 'control_mode', 10)` (`path_following_node.py:162-166`)
- 구독: `create_subscription(String, 'control_mode', ..., 10)` (`hybrid_controller_node.py:57`)

volatile은 late joiner에게 과거 메시지를 주지 않는다. 노드 기동 순서와 DDS discovery
타이밍에 따라 hybrid_controller의 구독이 그 1회 발행 **전**에 매칭되면 cascade,
**후**면 velocity로 남는다 → 런마다 무작위.

### 1.3 이것은 간헐적이다 — 전 런 모드 실측

| 모드 | 런 |
|:--|:--|
| cascade | A, B, C, E, I, L, N, **R** |
| velocity | F, G, H, J, K, M, **O, P, Q, S** |

`ros2 bag`도 같은 late-joiner라 runO bag의 `/bluerov2/control_mode` 메시지는
**총 1건(종료 시 `position`)** — 초기 `cascade` 발행은 기록조차 안 됐다.

## 2. 분석 — 영향 범위

### 2.1 두 모드의 성능은 정확히 상보적이다

| 모드 | 전체 RMS | 전체 max | 코너 RMS | leg RMS | 완주 | 거리 |
|:--|--:|--:|--:|--:|--:|--:|
| velocity (runO) | 0.227 | 0.531 | **0.217** | 0.263 | 711 s | 351.5 m |
| cascade (runN) | 0.459 | 1.270 | 0.537 | **0.057** | 471 s | 321.2 m |

- **cascade**: outer 위치 P가 있어 leg가 거의 완벽(0.057)하지만 코너에서 무너진다.
- **velocity**: 코너는 좋지만(0.217) leg가 정적 오프셋으로 샌다(0.263).

각 모드가 상대의 약점을 정확히 메운다. **새 제어기가 필요한 게 아니라, cascade의
leg 성능과 velocity의 코너 성능을 합치면 된다.**

cascade 코너 붕괴의 메커니즘은 어제 세션이 이미 규명했다(계획서 P2 로그):
`v_sp = clip(Kp_outer·e + vel_ff)`에서 outer 위치항(0.4 × carrot ~3 m ≈ 1.2)이
clip을 상시 치면 guidance 코너 감속(0.3)이 구조적으로 무력화된다. 그 진단은
cascade 모드에 대해 **유효하다** — 다만 그때는 그게 모드 차이인 줄 몰랐다.

### 2.2 무효화되는 기존 결론 4건

1. **"쌍안정"(2026-08-22 P2)** — 같은 설정에서 0.228↔0.459로 갈린 것은
   attractor가 아니라 runM(velocity) vs runN(cascade)이었다. 어트랙터 가설 폐기.
2. **"`guidance_speed_margin` 캡으로 쌍안정 소멸"** — runO/P/Q 3연속 청정은 캡의
   효과가 아니라 3런 모두 velocity였기 때문이다. 캡은 cascade 전용 코드
   (`cascade_controller.py:184`)라 velocity 런에서는 실행조차 안 됐다.
   캡의 실효는 **미검증**(runR에서 471→581 s로 부분 작용 시사하나 gain 0.5와 교란).
3. **"sway_ff_gain 0.5 반증"(2026-08-23 본 세션 초반)** — runR은 cascade였다.
   1.671 m를 게인 탓으로 돌린 것은 오귀인. 깨끗한 비교는 velocity 내
   runO(0.1, RMS 0.227) vs runS(0.2, RMS 0.272)뿐 — **0.1이 낫다는 결론은 유지**,
   근거만 교체.
4. **P1 A/B (runA·runB, 둘 다 cascade)** — 상호 비교는 유효하나 P2 이후 velocity
   런과의 비교는 무효.

### 2.3 P2 모델 주입의 실효 범위

`cascade_controller.py`에만 있는 것은 velocity 런에서 전부 미실행이다.

| 기능 | 위치 | velocity 런에서 |
|:--|:--|:--|
| P5 position-cascade (outer P → inner PI) | cascade_controller | 미실행 |
| P2 모델 ff (M_eff·a_ff, damping, 부력) | cascade_controller | 미실행 |
| P2 실측 게인 Kp_inner 140/124/128 | `cascade.inner_loop` yaml | 미실행 |
| `guidance_speed_margin` 캡 | cascade_controller:184 | 미실행 |
| `sway_ff_gain` | ilos_guidance (guidance 층) | **실행됨** |

velocity 런에서 실제로 도는 것은 `velocity_mode` PID
(Kp 40/40/50/4, Ki 20/20/25/2, `hybrid_controller.yaml:55-68`)다.

## 3. 검토 — 설계 판단

### 3.1 왜 "그냥 cascade 켜기"가 답이 아닌가

레이스만 고쳐 cascade를 상시화하면 RMS 0.227 → 0.459로 **2배 악화**한다.
cascade의 코너 결함이 먼저 해결돼야 한다.

### 3.2 왜 "velocity 유지 + 무시"가 답이 아닌가

정적 오프셋이 무보정이면 leg 오차가 코너 튜닝의 잔여로 무작위 결정된다.
실측 증거: runS(g0.2)는 코너를 개선했는데 leg RMS가 0.263→0.336으로 올라
전체가 악화(0.227→0.272)됐다. **cross-track 피드백 없이 하는 코너 튜닝은
잡음을 쫓는 것이다.** 오늘 프로브가 그 사실을 증명했다.

### 3.3 남은 선택지 3안

| 안 | 내용 | 장점 | 위험 |
|:--|:--|:--|:--|
| **B1** | velocity 유지 + ILOS cross-track 항 `arctan(−e_y/Δ)` 복원 | 최소 변경, 현 코너 성능 보존, 교과서 ILOS(Lekkas & Fossen), 이중보정 걱정 없음(sway PID는 이미 제거됨) | heading으로 미는 방식이라 4DOF sway 능력 미활용, 코너에서 heading 명령 간섭 가능 |
| **B2** | cascade 활성화 + 코너 과속 수정 | P5·P2 투자 회수, leg 0.057 실증, 4DOF 정공법 | 코너 결함 미해결(캡 실효 미검증), 재튜닝 필요, 변경 폭 큼 |
| **B3** | velocity 유지 + sway 채널에만 위치항 추가 (guidance가 `v_des_sway = −Kp·e_y` 공급) | 4DOF sway 직접 활용, 코너 경로 무간섭, cascade 미개봉 | 신규 게인 1개 튜닝, ILOS 관례 이탈 |

**권고: B3.** 증상이 "sway 명령이 0"인데 4DOF 차량이 sway를 쓸 수 있으므로
sway로 고치는 것이 직접적이다. B1은 옆으로 갈 수 있는 차량을 굳이 heading으로
돌려서 미는 우회이고, B2는 코너 결함이라는 미해결 문제를 선결로 안는다.
B3는 guidance 층(이미 활성)에 한 줄 추가라 변경 폭도 가장 작다.

단, **B2를 영구 폐기하자는 뜻은 아니다** — cascade의 leg 0.057은 B3가 도달할
목표치를 제시한다. 코너 결함이 별도로 해결되면 재검토 대상.

## 4. 계획

### Phase A — 결정성 확보 (블로커, 다른 모든 측정의 선결)

| # | 작업 | 파일 | 검증 |
|---|---|---|---|
| A1 | `control_mode` pub/sub QoS를 `TRANSIENT_LOCAL`+`RELIABLE` depth 1로 (latched state topic 관례) | `path_following_node.py:162`, `hybrid_controller_node.py:57` | 신규 유닛: QoS 프로파일 단언 |
| A2 | 기동 시 활성 모드를 1회 INFO 로그 + 주기 로그에 유지 (이미 2 s 주기 있음 — 확인만) | `hybrid_controller_node.py` | 로그 grep |
| A3 | 러너 v3: 런 시작 10 s 후 `ros2 param`/로그로 활성 모드를 캡처, 기대 모드와 불일치면 **런 abort** | job tmp 러너 | 의도적 불일치 주입 시 abort |
| A4 | 유효성 게이트 확장: 기존 `wrench 50.0 Hz` + **`활성 모드 == 기대 모드`** | 계획서·메모리 표준 | — |

A1 주의: 한쪽만 transient_local이면 late joiner 전달이 안 된다 — **양쪽 다** 바꿔야
한다. 두 파일 모두 이 repo 안이므로 크로스 repo 이슈 없음.

A3는 A1이 실패하는 경우까지 막는 이중 방어다. A1만으로 충분해 보여도 오늘 잃은
캠페인의 비용을 생각하면 게이트는 남긴다.

### Phase B — cross-track 피드백 복원 (사용자 결정 후 착수)

B3 채택 시:

| # | 작업 | 파일 | 검증 |
|---|---|---|---|
| B3.1 | `ILOSGuidance._compute_body_velocities`에 cross-track 위치항 추가: `v_sway_fb = clip(−cross_track_gain · e_y, ±max_lateral_velocity)`, 기존 곡률 ff와 합산 | `ilos_guidance.py:830~` | 유닛: e_y 부호→sway 부호, 0에서 0, clip 경계 |
| B3.2 | `cross_track_gain` yaml 파라미터 + 노드 기본값 동기(drift 게이트 관례) | `path_following.yaml`, `path_following_node.py` | 기존 drift 게이트 |
| B3.3 | 초기값 산정: leg 시정수 목표 ~3 s → `Kp ≈ 1/3 ≈ 0.33`. cascade outer sway Kp=0.5가 leg 0.057을 냈으므로 0.3~0.5 구간 | 주석에 도출 기록 | — |
| B3.4 | FOLLOW 모드에서만 작용(ALIGN·종료 제외) — 기존 `_mode` 가드 관례 답습 | | 유닛 |

**부호 함정**: `e_y = -e_vec[0]·sin(χ_p) + e_vec[1]·cos(χ_p)`
(`ilos_guidance.py:724`)는 경로 좌측이 +. body sway(FRD)는 우현이 +. heading이
χ_p에 정렬돼 있으면 `v_sway = −Kp·e_y`가 맞다. **구현 전 단위 테스트로 부호를
먼저 고정할 것** — P7 때 곡률 부호를 재유도한 전례가 있다.

### Phase C — 재기준선 (omx 레인 권고)

Phase A·B 후, 모드를 고정하고 처음부터 다시 잰다. 기존 수치는 전부
모드 혼재라 비교 기준으로 쓸 수 없다.

- C1: 모드 고정 baseline 3연속 (재현성 확인, 산포 < 0.01)
- C2: `cross_track_gain` 스윕 (0 / 0.3 / 0.5) — 1변수
- C3: `sway_ff_gain` 재스윕 (0.1 / 0.2) — C2 확정 후. **오늘 결론은 leg 오차가
  교란된 상태의 것이라 무효**
- C4: 판정 = e_y_max < 0.5 (기존 목표 승계) + leg RMS < 0.1

omx 권고 이유: 오늘 잃은 것이 정확히 "통제 안 된 변수가 캠페인을 오염"이고,
ledger·proposal lint·probe novelty가 그 가드다. 런 산출물이 job tmp(휘발성)에
있는 문제도 experiments 트리로 해결된다.

### Phase D — 무효 결론 정리 (Phase A와 같은 PR)

§2.2의 4건을 기록에 반영한다. 본문만 고치고 요약을 남기지 않는다 —
요약 층(CHANGELOG 헤더·P4_FLAGS 항목명·PR 본문·메모리 인덱스)까지 같은 커밋에서.

| 대상 | 조치 |
|:--|:--|
| `CHANGELOG.md` [0.5.x] | "쌍안정 근본 수정" 서술을 모드 레이스 판명으로 정정 |
| `P4_FLAGS.md` | 신규 항목: control_mode 레이스(해결됨/미해결 상태 명기), `guidance_speed_margin` 실효 미검증 |
| PR #22 본문 | P2 성능 주장에 "velocity 모드 한정" 단서 + 레이스 고지 |
| `.sp/plans/2026-08-22-path-tracking-recovery.md` | P2 로그의 쌍안정·캡 귀인 절에 반증 병기 |
| 메모리 `stonefish-path-tracking-koopman.md` + `MEMORY.md` 인덱스 | 동시 갱신 |

## 5. 사용자 결정 (2026-08-23 확정)

| 항목 | 결정 | 계획 반영 |
|:--|:--|:--|
| 복원 방식 | **B3** — guidance에 sway 위치항 | Phase B = B3.1~B3.4 확정, B1·B2 폐기 아님(보류) |
| Phase C 레인 | **omx 이관 + 초기화** | `omx program-init` → `.omx/programs/`, bag을 experiments 트리로 이동, wiki 첫 페이지 기록 |
| PR #22 | **#22에 얹기** | 브랜치 `feat/model-injection` 유지, Phase A·B·D를 추가 커밋으로. 별도 브랜치 안 만듦 |

PR #22에 얹기로 했으므로 §4 Phase D의 "PR #22 본문" 항목은 단서 추가가 아니라
**본문 전면 갱신**이 된다 — P2 성능 주장(velocity 한정)과 레이스 수정·B3까지
한 PR에 담기므로 요약이 범위 전체를 덮어야 한다.

### 여전히 미해결

- Open Q1 (실기 요구 속도), Open Q2 (P3/Koopman 진입 기준) — 미답
- `guidance_speed_margin` 실효 (cascade+캡+gain 0.1 런 부재) — B2 보류에 딸려 감

## 5.5 실행 현황 (2026-08-23 세션)

| 단계 | 상태 | 근거 |
|:--|:--|:--|
| A1 QoS latch (pub+sub TRANSIENT_LOCAL) | **완료** `db2c3e9` | 스모크에서 기동 14 ms 만에 velocity→cascade 전환. 수정 전에는 전환 자체가 없었음 |
| A2 활성 모드 로그 | **완료(기존 충족)** | `hybrid_controller_node` init 로그 + 2 s 주기 `Mode: X \| Switches: N` |
| A1b `path_following_mode` 파라미터 | **완료** `db2c3e9` | 하드코딩 'cascade' 제거, 기본 velocity, 허용값 밖이면 기동 ValueError |
| A3 러너 v3 모드 게이트 | **완료** | `run_measure_v3.sh` — 기대 모드 불일치 시 exit 2로 런 폐기. v2 보존 |
| A4 유효성 게이트 확장 | **완료** | v3가 런 끝에 `mode(follow-phase)` + `wrench_rate.py` 두 줄을 함께 출력 |
| B3.1 cross-track sway 피드백 | **완료(미커밋)** | `v_sway_fb = -cross_track_gain·e_y`, ff와 합산 후 1회 clip |
| B3.2 파라미터 배선 | **완료(미커밋)** | ILOS·ALOS 생성자 + 노드 + yaml, drift 게이트 |
| B3.3 초기값 | **0.4** | leg 시정수 ~2.5 s. cascade outer sway Kp=0.5가 leg 0.057을 낸 것이 근거 |
| B3.4 FOLLOW 가드 | **완료(미커밋)** | 기존 곡률 ff와 동일 `_mode` 가드, 유닛으로 고정 |
| 테스트 | 179 passed | 신규 9건(QoS 2·모드 2·cross-track 5), 특성화 1건 의도적 반전 |
| runT 검증 런 | 진행 중 | v3 러너, 기대 모드 velocity |
| omx 이관 | 미착수 | |
| Phase C 재기준선 | 미착수 | |
| Phase D 문서 정정 | 미착수 | |

특성화 테스트 반전 1건: `test_right_offset_cte_computed_but_sway_zero`가 P5 결정
("sway 0")을 고정하고 있었다. B3가 그 결정을 되돌리므로
`test_right_offset_cte_computed_and_sway_corrects`로 이름·단언을 뒤집고
docstring에 이력을 남겼다. heading의 arctan 항은 여전히 제거 상태이므로
이중보정이 아니다.

## 6. 실행 순서 (결정 반영 후 확정)

1. **A1~A4** 결정성 확보 → 이것 없이는 B 검증이 또 오염된다
2. **omx 초기화 + bag 이관** (4.7 GB가 휘발성 job tmp에 있음 — A와 병행 가능)
3. **B3.1~B3.4** 구현 + 유닛 (부호 먼저 고정)
4. **Phase C** omx 프로그램으로 재기준선
5. **D** 문서·PR #22 갱신 (C 결과 확정 후, 수치 포함)

## 7. 이 계획이 스스로 인정하는 한계

- 본 문서는 **작성·검토가 같은 세션**에서 이뤄졌다. 프로젝트 규칙은 작성↔리뷰
  분리를 요구하나 이번 세션은 에이전트 위임이 금지돼 있어 자체 검토에 그쳤다.
  착수 전 `code-reviewer`/`critic` 별도 패스를 권고한다.
- `guidance_speed_margin`의 실효는 여전히 미검증이다(cascade+캡+gain 0.1 런 부재).
  B2를 택하면 이것이 선결 과제가 된다.
