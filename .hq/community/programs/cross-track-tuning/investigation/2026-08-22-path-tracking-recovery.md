# 경로추종 복구·고도화 계획 (2026-08-22)

## 목표 (사용자 요청 원문 기준)

경로 추종이 엄청나게 잘 안되는 원인을 분석해 고치고, 가능한 고도화 방법으로 경로 추종을
더 잘하게 만든다. 기존 경로추종·제어 알고리즘의 전면 교체도 허용. 방법론은
koopman / cascade PID / MPC 무엇이든 좋다. 단, SLAM 실행 세션
(web-terminal-d70ebc2b-…, mjkim_merge 스택 가동 중)과 겹치지 않게 진행한다.

## 진단 요약 (2026-08-22 분석 세션 확정, 코드 앵커 포함)

지배 원인은 상위 알고리즘이 아니라 **액추에이터 인터페이스**:

1. **힘→PWM 제곱 왜곡**: allocator가 힘[N]/100을 PWM으로 발행
   (`thruster_allocator_node.py:162`)하는데 Stonefish는 이를 rpm 분율로 해석,
   추력은 `T = ρ·kT·n|n|·D⁴`. 100 N 명령 → 실제 7.3 N (7.3%).
2. **포화 불일치**: 제어기 한계 800 N/160 N·m vs 물리 실제 58.3 N/13.7 N·m (~14배).
   anti-windup(`cascade_controller.py:147-153`)이 실효 영역에서 미발동 → 코너에서
   적분 폭주 → 이탈·진동.
3. **v_sp_limit 모순**: guidance cruise 1.0 m/s(`path_following.yaml:17`) vs
   cascade surge clamp 0.5(`hybrid_controller.yaml:86`) → 상시 windup 압력.
4. 부차: 동역학 모델 부재(hydro 계수 주석), M·a ff 미배선(P4_FLAGS ④),
   rotor 스핀업 지연, 전진 시 추력 감쇠 항, /clock 부재(T1.6).

물리 한계 (`bluerov2.scn:87` 사양 유도): 추진기당 20.62 N,
surge/sway 58.3 N, heave 82.5 N, yaw 13.74 N·m.

## 충돌 회피 규칙 (ps/git 실측 기반, 전 Phase 상시 적용)

- **R1 파일 불가침**: `src/stonefish_slam/**` (slam.yaml 수정 중 확인),
  `/root/orca/workspaces/workspace/mjkim_merge/**` 전체.
- **R2 git 격리**: sim 코드 작업은 새 브랜치 + 이 세션 전용 worktree에서만.
  `/workspace/src/stonefish_sim` 공유 체크아웃 직접 편집 금지. bare stash 금지
  (필요 시 태그 stash + SHA 캡처 규칙). main 직push 금지 — PR로만.
- **R3 빌드 격리**: `/workspace/build·install` 및 `mjkim_merge/install` 불변.
  빌드가 필요해지면(P1+) 내 worktree 내부의 독립 colcon ws에서만.
  `.omx/profile/evaluator.sh` 실행 금지(slam colcon build를 유발).
- **R4 ROS 그래프 격리**: ROS_DOMAIN_ID=0을 그 세션이 점유 중 — 이 세션에서
  노드 실행·`ros2 topic pub` 금지. 닫힌루프 검증은 (a) 그 세션 종료 후, 또는
  (b) 별도 `ROS_DOMAIN_ID` + 독립 install 트리로만. GPU 경합은 (b)에서도 남음.
- **R5 인터페이스 동결**: `stonefish_msgs` 불변경 (변경 시 slam 파손 —
  CONTRIBUTING §5 상호 PR 링크 의무 발동, 이번 계획 범위 밖).

## Phase 0 — 액추에이터 인터페이스 수정 (즉시 착수 가능, Python-only, 무빌드)

전 방법론(cascade/MPC/Koopman)의 공통 선결. 이것 없이 상위 교체는 무의미.

| # | 작업 | 파일 | 검증 |
|---|---|---|---|
| T0.1 | 역추력맵: `pwm = sign(F)·√(|F|/T_max)`, `T_max` 파라미터화(기본 20.62 N, .scn 유도 주석) | `thruster_allocator_node.py` | 신규 유닛: 0점·경계(F=T_max→1)·클립·단조·부호 |
| T0.2 | 포화 정합: cascade/velocity/position `max_force 800→55`, `max_torque 160→13.7`; allocator 클립 ±20.62 | `hybrid_controller.yaml`, allocator | 적분한계 자동 재계산 확인 (공식 기존) |
| T0.3 | v_sp_limit surge 0.5→1.2 (Open Q1 답변에 따라 조정) | `hybrid_controller.yaml:86` | 기존 cascade 유닛 green |
| T0.4 | 게인 물리 기반 재산정 초기값(Kp_u≈m·ω_c, m=20.13 kg) + 도출 주석 | `hybrid_controller.yaml` | 골든 테스트 게인 의존 확인·필요시 갱신 |

- 절차: sim repo 브랜치 `fix/thrust-map` → 이 세션 전용 worktree → 구현+테스트 →
  `python3 -m pytest` 전체 green(빌드 불필요 — sim 테스트는 path-load 설계) → PR.
- 게이트: 전 테스트 green + 코드 리뷰(작성↔리뷰 분리). 머지는 사용자.

## Phase 1 — 닫힌루프 A/B 측정 — **완료 (2026-08-22, DOMAIN 77 병행)**

결과(각 n=1, 상세 job tmp p1/P1_AB_RESULTS.md): 완주 660.6→367.8 s(1.80×),
e_y RMS 0.407→0.323 m, p95 0.831→0.714, max 1.251→1.178(코너 국소, 직선 ~0.2),
e_z RMS 0.047→0.021, 주행거리 337→283 m. **판정 e_y_max<0.5 미달 → P2 조건 성립.**

### P2 실행 로그 (2026-08-22, compact 후 여기부터)

**구현 완료** — 브랜치 `feat/model-injection` 12커밋(미push), 167 passed:
- T2.0~2.1: open-loop 스텝 프로브 → M_eff [70.2, 62.0, 63.9] kg·I_zz~0.24(order만)·
  d1/d2·부력 7.27 N·v_max(55 N)=0.911 m/s → dynamics_params.yaml 기입(flat diag).
- T2.2: 리뷰(REQUEST_CHANGES, BLOCKER-1)로 형태 변경 — msg 경유 기각(outer surge
  상시 clip → guidance 미분 = unmatched disturbance), **cascade 내부에서 clip 후
  v_sp 미분(LPF 2 Hz, raw ±2 clamp)**으로 구현. damping ff(d1·v_sp+d2·v_sp|v_sp|+부력)
  도 추가(MINOR-2). `cascade.accel_ff_cutoff_hz` ROS 파라미터 노출(0=off).
- T2.3: inner Kp=M_eff·2=[140,124,128,4(yaw 유지)]·Ki=Kp/2, v_sp/cruise 0.7
  (0.8↑는 allocator yaw 권한 붕괴 — 권한 표는 hybrid yaml 주석), node 기본값
  동기+drift 게이트, CHANGELOG 반증 정정.

**재측정 (krit_lawnmower, DOMAIN 77, use_sim_time:=false)**:
- runE(P2 풀 구성, 유효·단일 스택 검증): 완주 451.6 s, e_y RMS **0.456**/max
  **1.331**/p95 1.030, e_z 0.036/0.317 — **P1-B(0.323/1.178/0.714) 대비 악화**.
  구간 분석: 특정 leg에서 지속 사행(RMS 0.6·v_y/r std 3~10배) ↔ 청정 leg(0.11,
  P1-B보다 좋음) 교대. Fy 포화 duty 3.4%·std 19 N. 코너 국소 문제 아님.
- runC·runD·runF(1차) 무효 — 아래 프로세스 함정으로 스택 중복/DOMAIN 0 오염.

**어블레이션 진행 중** (러너 `jobs tmp/p2/rerun/run_measure.sh`, 결과는 디스크):
- runF(재실행 중): acc_ff OFF(install yaml cutoff=0.0 오버라이드, 소스는 2.0).
  판독: `runF_launch.log` grep "Max CTE" + `compute_metrics.py runF_bag`.
- 판정 트리: runF 청정 → acc_ff(v_sp 미분의 자기되먹임/게이트 점프 펄스) 원인 →
  기본 off 또는 clamp/cutoff 강화. runF 사행 지속 → runG: damping ff OFF(install
  dynamics_params.yaml diag·부력 0) → 그래도면 runH: 구 게인(Kp 40) @0.7 —
  속도 정합 베이스라인(P1-B는 cruise 1.0이라 속도 교란 변수).

**⚠ 프로세스 함정 (3회 사고 원인, 러너에 반영됨)**:
- 비대화형 bash의 bg job은 **SIGINT 무시(SIG_IGN 상속)** — `kill -INT` 무효.
  종료는 `kill -TERM`(자식 노드는 KILL 필요할 수 있음), 기동 전
  `ps -eo comm | grep stonefish_simul` 잔존 검증 필수.
- `pgrep -f "a\|b"`는 ERE에서 리터럴 → 거짓 0. `ps | grep -E` 사용.
- 복합 명령 `A && nohup X & B && nohup Y &`는 Y가 **변수·env 미전파 서브셸**에서
  실행됨 → runD가 DOMAIN 0(SLAM 도메인)으로 ~16분 침범(사용자 보고 필요).
  반드시 단일 러너 스크립트 사용.

**[최종 판정] runG~runL 전부 무효 — 고아 스택 누적 오염 (2026-08-22)**:
- 증상 연대기: runG '사행 재현'(acc_ff 판정 반증으로 오독) → 0.6 하향 처방
  → runH 발산(CTE 36 m)·runI/J (-15.1,15.2) 구조물 충돌 고착 → ω_c=1 처방
  → runK 배회·runL(runG 설정 재현판) 고착 — 설정 3군 전부 실패로 환경 의심.
- **진범**: wrench 발행률이 runE/F 50.0 Hz(정상) → runG 76 → runH/I 200+
  → runJ/K/L 250 Hz로 계단식 증가. 러너 v1의 잔존 검사가
  `ps -eo comm | grep stonefish_simul`이라 **comm=python3인 컨트롤러
  노드들은 통과** — `ros2 launch`가 TERM에서 Python 자식(hybrid_controller·
  thruster_allocator·path_following·path_generator)을 고아로 남겼고, 런마다
  4프로세스씩 누적(ps 실측 7스택 28개, etime이 각 런 시각과 일치). 서로
  다른 설정의 컨트롤러 여러 개가 같은 토픽에 wrench를 동시 발행한
  크로스토크가 사행·발산·고착의 실체. 전원 SIGKILL 소탕 완료.
- **러너 v2**: 잔존 검사·종료 소탕을 전 스택 패턴
  (`install/lib/stonefish_|stonefish_simulator|ros2 bag record`, args 기준)
  으로 확대 + 종료 시 무조건 pkill -KILL + 소탕 후 재검증.
- **판정 복원**: 단일 스택(50.0 Hz)이 검증된 runE/runF만 유효 → 원
  어블레이션 성립: acc_ff ON=사행+allocator 포화 1459건(0.456) / OFF=
  청정+0건(0.227). **커밋 2e227cc로 유령 처방(0.6·ω_c=1) 내용 롤백** —
  v_sp/cruise 0.7·Kp[140,124,128] 복원, 서술 전 층위(yaml·docstring·
  CHANGELOG·P4_FLAGS) 단일 스택 증거 기준 재작성. adb10f1(acc_ff 기본
  off)은 유효 근거로 존치. 167 passed.
- **교훈(함정 4호 추가)**: 폐루프 측정의 유효성 게이트로 wrench 발행률
  50 Hz(=컨트롤러 1개) 확인을 표준화할 것. 고아 잔존은 comm이 아니라
  args 패턴으로 검사.

**runM/runN 결과 — 진짜 쌍안정 실재, 최종 원인 판정 (2026-08-22)**:
- 러너 v2·단일 스택(wrench 50.0 Hz 검증) 하에서 runM=runF 재현(0.228/
  0.531, 700 s) vs runN=사행(0.459/1.270, **460 s 완주**) — 오염 없이
  갈림. acc_ff 인과 최종 기각(ON 1/1 사행, OFF 1/3 사행).
- **판별 신호**: 사행 런은 평균 0.70 m/s(청정 0.50) — 코너 감속 로그
  0.30 줄 수 절반, bag 실측으로 **코너 감속 명령 0.30 구간을 u 0.68~
  0.70으로 통과**(청정 런은 0.32 순종). 같은 바이너리·설정.
- **최종 메커니즘**: v_sp = clip(Kp_outer·e + vel_ff)에서 outer 위치항
  (0.4 × carrot ~3 m ≈ 1.2)이 clip을 상시 치면 guidance 감속이 구조적
  무력화 — 감속 실효가 carrot 기하(동역학 상태)에 좌우되어 동일 설정이
  청정/사행 어트랙터로 갈리는 쌍안정. 코너 과속→오버슈트→leg 진동
  여진=사행, 그리고 사행 런이 오히려 빨리 끝나는 이유(감속 안 함).
- **처방 커밋 73c4acc**: `guidance_speed_margin`(기본 0.1, 음수=비활성)
  — vel_ff 공급 시 surge v_sp를 |명령속도|+margin으로 동적 캡, 감속
  권위를 컨트롤러 레벨에서 보장. 테스트 P2-8/9, 169 passed. acc_ff·
  게인·속도 서술 전 층위 3차 정정(이득 미입증 사유로 off 유지).

**[인계 지점 2026-08-23 — 새 세션은 여기부터] P2 후속: sway_ff_gain 검증 대기**:
- PR #22는 OPEN·리뷰 0건. 그 뒤 **후속 커밋 6a72bec(sway_ff_gain 0.1→0.5)이
  로컬에만 있음 — 미push**. 근거: runO 잔여 e_y 피크 5/5가 코너 바깥
  오버슈트, 설계식 M_sway/Kp_inner의 입력이 가정 질량 기준 0.1로 잔존
  (실측 62.0/124≈0.5, 원심 보상 5배 과소). 169 passed·install 반영 완료.
- **검증 런 상태(2026-08-23 종료 시점 확정)**: runR은 ~4분 진행 중 사용자
  중단(완주 없음, **무효**), runS는 미시작. 잔존 스택 0 확인 완료(ps
  검사). 6a72bec은 **push 완료**(PR #22에 포함됨 — 폐루프 검증은 아직).
- 새 세션 절차: ① `ps -eo args | grep -E "install/lib/stonefish_|
  stonefish_simulator"` 잔존 0 확인(있으면 pkill -KILL -f
  "install/lib/stonefish_") ② `bash <jobs tmp>/p2/rerun/run_measure.sh
  runR` → runS 순차 재실행(각 ~12분; job tmp가 사라졌으면 러너 v2를
  계획서 이 절 이력대로 재작성 — 핵심: args 패턴 잔존검사+종료 무조건
  소탕, DOMAIN 77, use_sim_time:=false) ③ 판독: launch log "Max CTE" +
  compute_metrics.py ④ **유효성 게이트: bag wrench 발행률 50.0 Hz** ⑤
  판정: 둘 다 청정+e_y_max<0.5면 PR 본문에 결과 갱신, 개선 없으면
  6a72bec revert 커밋 후 특성화 보고.
- 비교 기준: 처방 전 runO/P/Q = RMS 0.227~0.228 / max 0.530~0.538 /
  700 s·351.5 m (3런 재현). 코너 피크만 줄고 나머지 동일해야 정상.

**P2 종결 (2026-08-22)**: runO/P/Q 3련속 청정 — e_y RMS 0.227~0.228 /
max 0.530~0.538 / 완주 ~700 s·주행 351.5 m가 3런 일치(단일 스택 50.0 Hz
검증). 캡 도입 전 동일 설정 산포(0.228↔0.459 쌍안정) 소멸 = 처방 유효
실증. P1-B 대비 RMS 30% 개선. **push 완료 + PR #22 오픈**(base main,
head feat/model-injection, 18커밋, 169 passed). 미달: e_y_max 0.53 vs
목표 0.5(6% 초과, 3런 일관) — 잔여는 특정 leg 정적 오프셋(v_y_std
0.006), 후속 과제로 PR 본문 명기. 사고 2건(DOMAIN 0 침범 ~16분, 고아
스택 오염 runG~L 무효)도 PR·보고에 고지. 남은 결정: PR 머지(사용자),
Open Q1(실기 요구 속도 — yaml 권한 표)·Q2(P3/Koopman 진입) 미답.

### (원 계획)

- T1.1 측정 프로토콜 고정: krit_lawnmower 코스, 지표 = e_y RMS/max·속도 수렴
  시간·90° 코너 오버슈트. rosbag 기록. (vault §4 반영: 폐루프 상대비교는 유효,
  모델 검증용 open-loop rollout은 P3 전용.)
- T1.2 before(main)/after(fix/thrust-map) 동일 코스 비교.
- **판정 기준: e_y_max < 0.5 m** (기존 실기 프로브 목표 승계).
- 실행 전제: R4 — 그 세션 종료 대기 or 별도 DOMAIN_ID + 독립 colcon ws 빌드.

## Phase 2 — 모델 주입 — **진입 조건 성립 (P1 e_y_max 1.18 > 0.5), 착수 대기**

### P2 착수 노트 (2026-08-22 확정, compact 후 이 절차대로)

- **T2.0 open-loop 스텝 프로브** (컨트롤러 없이 wrench 직접 주입):
  `bringup.launch.py start_control:=false start_path:=false` (sim+allocator만) +
  `ros2 topic pub /bluerov2/thruster_manager/input_stamped geometry_msgs/WrenchStamped ...`
  축별 스텝: surge {10,20,30,40} N · sway 동일 · heave {10,20,30} N · yaw {2,4,8} N·m,
  각 15 s 유지 + 10 s 휴지, odometry+input_stamped bag 기록 (DOMAIN 77).
- **T2.1 피팅**: 정상상태 속도 → 감쇠 `F = d1·v + d2·v|v|` 최소자승; 초기 기울기
  → `(m+Ma) = F/(dv/dt)` — rotor 스핀업 ~0.5 s 구간은 제외하고 피팅(PI kp=8/ki=3 지연).
  산출을 `dynamics_params.yaml:126~` Ma·damping 주석 해제로 기입.
- **T2.2 M·a ff 배선** (P4_FLAGS ④ 명세 승계, msg 변경 불필요 — `TrajectoryPoint`에
  `geometry_msgs/Accel acceleration` 필드 기존재·R5 무저촉):
  ① path_following_node가 `msg.acceleration` 채움(v_ff 수치미분+저역필터)
  ② hybrid cmd_callback이 acceleration 읽음 ③ cascade inner에 `M·v̇_sp` ff 합산
  (CascadeController가 mass/inertia_zz를 이미 생성자 보관 — 호출부 무변경 설계).
- **T2.3** 실측 M·D로 게인 재산정(ω_c 재계산) → pytest 게이트 → 리뷰 분리 →
  브랜치 `feat/model-injection` PR → P1 동일 코스 재측정(코너 피크 비교).
- 보조 후보(별도 커밋): 코너 감속 강화(curvature_gain·min_speed), lookahead 튜닝.

### (원 계획)

- T2.1 스텝 프로브로 damping·added mass 실측 → `dynamics_params.yaml` 주석 해제.
- T2.2 M·a feedforward 배선(P4_FLAGS ④ 명세 승계), `feedforward_gain` 재정당화.
- T2.3 재튜닝 → P1 코스 재측정.

## Phase 3 — 구조 고도화 (조건부/연구 트랙, 착수 자체가 사용자 결정)

- **1순위: 선형 MPC** (Fossen 모델 + 실제 포화·속도 한계를 제약으로, OSQP,
  50 Hz/horizon 20-40). 포화 지배 플랜트에 정면 대응.
- **2순위: Koopman 트랙** — 선결 3종: ① T1.6 /clock 수정(C++ sim rebuild 필요 →
  그 세션과 조율 필수), ② vault §3 게이트: wrench 입력 층 모델링 +
  jointly-lifted/bilinear (guidance 층 모델링 시 unicycle 실패 재현 — 금지),
  ③ vault §4 측정 프로토콜(open-loop rollout, 학습 dt=플랜트 dt).
  데이터 수집은 episodic(Folkestad) 방식.

## Open Questions (사용자 결정 대기)

1. **속도 정책**: cruise 1.0 유지+clamp 상향 vs cruise 0.5 하향 — 실기 요구 속도는?
2. **P3 진입 기준**: P1/P2에서 e_y<0.5 m 달성 시 중단? 아니면 Koopman은
   연구 목적(브랜치명 koopman)으로 무조건 진행?
3. **P1 실행 창**: SLAM 세션 종료 대기 vs 별도 ROS_DOMAIN_ID 병행(GPU 경합 감수)?

## 일정 감각

P0 반나절 · P1 1~2시간(실행 창 확보 후) · P2 1일 · P3 별도 사이클.
