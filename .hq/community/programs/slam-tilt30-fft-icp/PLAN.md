# Program: slam-tilt30-fft-icp

**Status: APPROVED 2026-09-02 (결정 4건 확정, 아래 Decision log). bag 재생 런은 세션이 실행한다.**

작성 2026-09-02 (Fable 세션, compact 직전). 실행 세션은 HANDOFF.md 를 먼저 읽는다.

## Objective

> 이렇게 하자. 일단 이 세션에서는 FFT+ICP 위치 인식 성능을 sonar tilt가 30도 인 상황에서
> 최대한 높힐 수 있게 여러가지 실험을 진행하는거야. FFT, ICP의 코드를 수정해도 좋고,
> 파라미터를 변경해도 좋아. 뭐든 좋으니 최대한 성능을 높히는거야. 단 다음 주의사항만
> 지키는 채로 말이지.
>
> # 제약 조건.
> 1. 반드시 FFT 및 ICP 사용.
> 2. 최대한 DR을 사용하지 않는 방향으로.
>   - 검증에서 실패한 프레임의 경우 DR을 사용할 수 있지만 이 실패한 횟수 자체가 성능 저하를 의미함.
> 3. 어떻게 내부에서 교묘하게 속여서 DR만 사용하는 식의 방식은 절대 불가.
> 4. ssm, nssm 반드시 사용해야함.
>   - 그 외에 keyframe 선정 조건이나 ssm, nssm 코드 변경은 가능하지만 앞서 말한 것과 같이 교묘하게 속이는 것은 안됨.
>
> (추가) 뭔가 예를들어 fft나 icp를 할때 roi를 설정하고 거기에서 수행한다던지? 필요하면
> 인터넷 조사도 해주고. 참고로 내가 말한건 그냥 예시이고 너가 인터넷 조사를 통해 다양한
> 방법을 시도하던지 해봐.
>
> (직전 결정) 회전도 일단 FFT로 해야지. → `fft_localization.use_dr_rotation: false`
> (slam `fix/fft-rotation` 2311c0c, tilt10 bag 재생으로 확인).

"성능" 의 조작적 정의는 아래 §Metrics — 재정의가 아니라 측정 가능하게 옮긴 것이다.
성능 = (a) GT 대비 궤적 오차가 낮고, (b) DR 로 떨어진 키프레임 수가 적고, (c) SSM·NSSM
팩터가 실제로 그래프에 들어가는 것. 세 축을 항상 같이 보고한다.

## Diagnosis

### D1. tilt 30° 에서 SLAM 이 발산한다 — 원인은 ICP 점군의 기하 왜곡이 유력

- tilt10 bag(FLS 하향 10°) 재생: 2D mean err 1.06–1.48 m, ICP 216/216 수렴.
  tilt30 bag 90 s 재생: mean err 6.2 m(49 키프레임), 전체 424 s 런은 mean 21.5 m / 끝 39 m.
  `[EVIDENCE: scratchpad logs 6-slam-replay.log, 8-fftrot-replay.log, 4x-slam.log; memory stonefish-sonar-tilt-frames]`
- **ICP 점군은 틸트 보정을 전혀 하지 않는다.** CFAR 점의 직교 변환이 `x = range·cos(bearing)`,
  `y = range·sin(bearing)` 로 경사거리(slant range)를 그대로 평면거리로 쓴다.
  `[EVIDENCE: stonefish_slam/core/feature_extraction.py:175-176; sonar_tilt_rad 는 :98 에서 읽기만 하고 미사용]`
- **FFT 는 다른 투영을 쓴다**: 수평거리 = range·cos(tilt) (`localization_fft.py:262-318`),
  mapping_2d 도 같은 cos(tilt) (`mapping_2d.py:558`). 즉 FFT 시드는 cos30°=0.866 로 압축된
  좌표계, ICP 점군은 압축 안 된 좌표계 — **시드와 점군의 척도가 13% 어긋난다.**
  tilt 10° 에서는 cos10°=0.985 라 1.5% 차이로 숨어 있었다.
- 기하: 바닥 위 높이 h 에서 수평거리 ρ 의 바닥점은 경사거리 r=√(ρ²+h²), 하향각 θ (cosθ=ρ/r).
  차량이 d 만큼 전진하면 Δr = d·cosθ. 따라서 **경사거리 점군으로 ICP 를 돌리면 병진 추정이
  cosθ 만큼 압축**된다. 수직 FOV 20° 라 θ ∈ [tilt−10°, tilt+10°]:
  tilt 10° → cosθ ∈ [0.94, 1.00] (최대 6% 압축), tilt 30° → cosθ ∈ [0.77, 0.94] (6–23% 압축,
  거리별로 다름 → 강체 변환으로 맞출 수 없는 비균일 왜곡). 고정 cos(tilt) 곱은 더 압축
  (cosθ·cosτ ≈ 0.75). 정확한 투영은 ρ = √(r² − h²) (h = 고도, 바닥 평탄 가정).
  `[EVIDENCE: 유도. 검증은 E1 의 I11 척도비가 한다]`
- I11 척도비(ICP 추정 병진 / 시드 병진) 실측: tilt10 bag 의 FFT 시드 중앙값 1.10 (예측
  cosθ/(cosτ_cfg·cosθ) = 1/0.866 = 1.155 와 같은 방향), tilt30 bag 은 중앙값 0.97 에 사분위
  0.77–1.13, DR 시드 중앙값 1.64 — 척도가 어긋난 정도가 아니라 ICP 가 불안정.
  `[EVIDENCE: scratchpad logs, ratio 분포 계산 2026-09-02 01:33]`
- 문헌: 이 코드의 원형(Englot 그룹 Bruce SLAM 계열, 같은 Oculus M750d 130°×20°)은
  "state 를 평면에 한정하고 elevation 이 기록되지 않으므로 φ=0 으로 둔다" 고 명시하며,
  부두·방파제의 **수직 구조물**을 수평 장착 소나로 본다. 30° 하향으로 바닥을 보는 우리 설정은
  그 가정 밖이다. `[EVIDENCE: McConnell, Chen, Englot, "Overhead Image Factors for Underwater
  Sonar-based SLAM", RA-L 2022, §IV-A, https://par.nsf.gov/servlets/purl/10357601]`
  FLS 밀집 매핑 쪽은 "국소 평탄 바닥 + 고도계 + 장착각·수직 개구로 실제 elevation 구간을
  구해 elevation 을 해소" 한다. `[EVIDENCE: WebSearch 2026-09-02, 'Underwater Terrain
  Reconstruction from Forward-Looking Sonar Imagery', https://par.nsf.gov/servlets/purl/10113017]`

#### D1 확정 (E0 실측, 2026-09-02 02:0x)

E0 베이스라인 2런이 D1 을 가정에서 측정으로 바꿨다. 압축의 방향과 크기가 둘 다 맞다.

| 양 | 실측 | 기하 예측 |
|:--|--:|:--|
| ‖ICP 병진‖ / ‖DR 병진‖ (dr 시드, n=131·143) | **0.771 · 0.760** | cosθ, θ∈[20°,40°] → 0.77–0.94 |
| ‖FFT 병진‖ / ‖DR 병진‖ (게이트 기각 프레임, n=135) | **0.705** | cosθ·cosτ → 0.66–0.81 |
| 키프레임 DR 병진 중앙값 | 1.11 m | — |
| 게이트 기각 | reject_pos 135/182 · 145/185 | 1.11 m × 0.30 = 0.33 m > 0.25 m 게이트 |
| 궤적 | mean_err 23.8 · 25.3 m, ATE 12.32 · 12.01 m | — |

읽는 법: **FFT 가 DR 보다 30% 짧게 재기 때문에 0.25 m 게이트를 74% 확률로 못 넘고**, 그래서
seed_dr 이 131/182 이 된다. 그 다음 ICP 는 DR 시드에서 출발해도 점군이 압축돼 있어 23% 짧은
병진을 낸다. 두 압축은 같은 원인의 두 얼굴이다 — 경사거리를 수평거리로 쓰는 것.

투영 세 방식을 한 파라미터(`sonar.projection`)로 묶었고, 최근접 대응 ICP 를 쓴 합성 실험으로
각 방식의 병진 배율을 미리 쟀다(`scratchpad/proj_icp.py`, 바닥 평탄·h·τ·vFOV 20° 스윕):

| 방식 | tilt 10° | tilt 30° | 성격 |
|:--|--:|--:|:--|
| `legacy` (점군 r 그대로) | 0.99 | 0.85–0.97 | 원본. 어디를 보느냐에 따라 배율이 달라진다 |
| FFT 의 `r·cosτ` | 0.97–0.98 | 0.82–0.84 | 네 방식 중 가장 압축이 크다 |
| `inv_cos_tilt` (`r/cosτ`) | 1.01 | 0.98–1.12 | 상수 근사. 원거리에서 과보정 |
| `altitude` (`√(r²−h²)`) | **1.0000** | **1.0000** | h·τ·거리와 무관하게 정확 |

따라서 E1a(고도)가 이론상 유일하게 정확한 해이고 E1b(`inv_cos_tilt`)는 고도계가 없을 때의
대안이다. 실행 순서를 E1a → E1b 로 바꾼다(계획의 E1b 우선은 "결정 불필요"가 이유였는데
altitude-input 이 승인돼 그 이유가 사라졌다). tilt30 bag 의 고도계는 중앙값 4.61 m
(IQR 3.91–5.16, n=1680).
`[EVIDENCE: experiments/slam-tilt30/e0-base_260902_020249·020910/metrics.json;
scratchpad/proj_icp.py; bag /bluerov2/altitude 직접 읽음]`

#### 실행 중 확인한 사실 (계획 보정)

- tilt30 bag 은 **336 s**, tilt10 은 424 s 로 길이가 다르다. 절대 mean_err 의 bag 간 비교는
  참고값일 뿐이고, 판정은 tilt30 안에서만 한다. "pairs < 4,000 이면 재생이 잘렸다" 는
  중단 규칙은 tilt30 에서 **< 3,400** 으로 읽는다(정상 런이 5,441–5,498).
- 베이스라인 산포 s: ATE 0.16 m, mean_err 0.72 m → 판정 경계 2s = ATE 0.31 m / mean 1.44 m.
- `[INSTR] counters` 에 NSSM·피처·투영 계측을 붙였다(커밋 5cc1c13, 46c400e).

#### D1 기각, D6 로 교체 (E1a·E3 실측, 2026-09-02 02:2x)

투영을 정확히 고쳐도(`projection: altitude`, ρ=√(r²−h²)) **ICP 병진 압축이 안 없어진다**:
ICP/DR 0.771 → 0.785, mean_err 23.8 → 22.0, ATE 12.32 → 11.90 — 전부 판정 경계(2s = mean
1.44 m / ATE 0.31 m) 안이거나 겨우 걸친다. 투영은 원인이 아니다.

이유는 척도 불변성이다. ICP 가 참값의 α배를 낸다고 할 때 α가 *겹침 비율* 이라는 기하
성질에서 나오면 점군의 반경 척도를 바꿔도 α는 안 변한다. 관측이 정확히 그 모양이다.
`[EVIDENCE: experiments/slam-tilt30/e1a-altproj_260902_021606/metrics.json]`

### D6. 원인은 몸체 고정 거리 띠의 겹침 부족 (확정)

bag 의 소나 프레임에 CFAR 를 직접 돌려 피처의 경사거리 분포를 쟀다: p5=7.8 · p25=8.5 ·
p50=10.1 · p75=12.6 · p95=20.7 m. 고도 4.6 m·틸트 30°·수직 FOV 20° 의 기하 예측
[h/sin40°, h/sin20°] = [7.2, 13.5] 와 맞는다. 바닥 반사는 **차량과 함께 움직이는 폭 4 m
링** 안에서만 나오고 지형은 그 링을 통과해 흘러간다. 키프레임 이동 1.1 m 이면 매 프레임
링 내용의 약 27% 가 짝을 잃는다. tilt 10° 에서는 같은 고도의 띠가 12.6–40 m 로 깊어
같은 1.1 m 가 4% 라, 그래서 tilt10 의 ICP/DR 이 0.993 이었다.
`[EVIDENCE: scratchpad/feat_geom.py — bag FLS 5,846 프레임 중 30 표본에 CFAR 직접 실행]`

합성 실험이 재현한다(`scratchpad/band_icp.py`, 최근접 대응 ICP + trim·maxDist 체인):
tilt30·target_frames 3·trim 0.8 → 0.810 (실측 0.771), tilt10 → 0.995 (실측 0.993).
같은 합성 실험이 trim 0.6 → 0.968, maxDist 1.0 → 0.963, target_frames 1 → 0.959 를 예측.

실측 (한 변수씩, E0 대비):

| probe | 변수 | mean_err | ATE | ICP/DR | 판정 |
|:--|:--|--:|--:|--:|:--|
| E0 (2런) | — | 23.85 · 25.28 | 12.32 · 12.01 | 0.771 · 0.760 | 기준 |
| e1a-altproj | `projection: altitude` (점군만, FFT 배선 누락) | 22.02 | 11.90 | 0.738 | 동등 |
| **e3-trim06** | `TrimmedDistOutlierFilter.ratio` 0.8→0.6 | **10.80** | **7.11** | **0.905** | **개선** |
| e5-tf1 | `ssm.target_frames` 3→1 | 21.17 | 10.73 | 0.705 | 미미 (ssm_fail 4→8) |
| e3-maxd1 | `MaxDistOutlierFilter.maxDist` 3.0→1.0 | 21.94 | 12.06 | 0.771 | 동등 |

DR 의존은 어느 런에서도 안 나빠졌다(seed_dr 134–140 vs 기준 131·143). 규칙 (a) 충족.

#### 주의 — trim 은 ICP 를 무력화하는 방향으로도 좋아진다

trim 을 조이면 ICP 가 시드를 거의 그대로 돌려주는 상태로 수렴할 수 있다. 이 파이프라인은
시드의 76% 가 DR fallback 이고 시뮬 DR 은 무노이즈 GT 이므로, **"ICP 가 아무것도 안 하는
상태" 의 궤적은 사실상 GT 궤적** 이고 I11 ratio 로는 1.0 수렴 = 개선으로 보인다. 제약 3 이
금지한 바로 그 모양이다. 그래서 I12(`move = ‖seed⁻¹·est‖`, `icp_inert`)를 넣었다
(커밋 6367585). trim 0.6 의 move 는 초기 표본에서 0.03–0.07 m — 기준선의 ~0.25 m 보다
훨씬 작다. **trim 은 성능 수치를 올리지만 ICP 기여도를 낮춘다는 사실을 함께 보고한다.**

따라서 남은 축의 우선순위가 바뀐다: 진짜 목표는 **seed_dr 을 낮추는 것**(FFT 가 게이트를
넘게)이고, 그 다음이 ICP 가 무력해지지 않으면서 정확해지는 것(잔차 기반 trim 이 아니라
기하 기반 crop = E1c).

### D7. 두 축은 서로 다른 결함이다 — trim 은 오차를, 투영은 DR 의존을 고친다

FFT 배선 버그(커밋 1f52baa)를 고친 뒤 `projection: altitude` 를 다시 재면, 게이트 기각
프레임의 ‖FFT‖/‖DR‖ 중앙값이 **0.705 → 0.984** 로 간다. FFT 의 legacy 투영 C=r·cos τ 는
dC/dρ = cosθ·cosτ ≈ 0.75 라 병진을 25–30% 짧게 내놓았고, 키프레임 DR 병진 1.11 m 에
대해 0.33 m 의 오차를 만들어 0.25 m 게이트를 74% 확률로 못 넘겼다. 편향이 사라지자
통과율이 24% → 41% 로 올랐다(seed 76/111). 남은 기각은 편향이 아니라 분산이다
(사분위 0.65–1.14) — 다음 축은 E4(FFT 전처리)다.
`[EVIDENCE: e1a2-alt-trim04_260902_030253; USE DR 로그의 FFT·DR 벡터 직접 비교]`

두 축을 합친 결과(투영 altitude + trim 0.4): **mean_err 3.23 m · ATE 3.33 m**
(기준 24.6 / 12.16). 두 축이 곱해지는 것이 아니라 각각 다른 병목을 없앤다:
trim 은 ICP 의 겹침 결함을, 투영은 FFT 의 척도 편향을.

#### 런 유효성 — CPU 경합으로 두 런을 폐기했다

같은 머신의 다른 Claude 세션이 자기 워크트리(`.wt/slam-semantic`)에서 tilt10 bag 을
`--rate 2.0` 으로 재생 중이었다(685% CPU). **토픽 오염은 없다** — 그쪽은
`ROS_DOMAIN_ID=71`, 이쪽은 도메인 0 으로 확인됐다. 영향은 CPU 경합뿐이고, 그것이
관측기 pairs 를 5,600대에서 2,698(e1b-invcos)·980(e3-trim03)으로 떨어뜨렸다.
계획의 중단 규칙(pairs 미달)이 정확히 이걸 잡았다. 두 런은 폐기하고 재실행한다.

대응: 러너가 전용 `ROS_DOMAIN_ID`(기본 77)를 쓰고, 종료를 확인식으로 바꿨으며
(INT·INT·TERM·KILL 단계적, 남으면 경고), kill 패턴에서 `ros2 bag` 을 뺐다 — 그게 있으면
다른 세션의 재생까지 죽인다. 내 끝난 런이 남긴 `ros2 launch` 부모 13개도 정리했다.

### D2. tilt 30° 에서 CFAR 피처가 두 배다 (173 vs 86 /frame)

바닥 텍스처가 더 많이 보이면서 클러터가 늘었다. ICP 대응이 나빠지는 두 번째 원인 후보.
`[EVIDENCE: memory stonefish-sonar-tilt-frames; 4x-slam.log]`

### D3. FFT 회전 추정은 살아 있고 DR 회전보다 나쁘지 않다

tilt10 bag 424 s, `use_dr_rotation:false`: ICP 219/219, seed_fft 197 / seed_dr 22,
reject_rot 6, 2D mean 1.48 m, ATE_RMSE 1.30 m. DR 회전: mean 2.17 m, ATE 1.13 m, seed_dr 28.
`[EVIDENCE: 8-fftrot-replay.log vs 6-slam-replay.log]`

### D4. NSSM(루프 클로저)은 FFT 와 무관하고 계측이 없다

NSSM 은 최근 k 프레임 점군을 합쳐 과거 전체 점군과 FOV 필터 → 겹침 최대 프레임 선택 →
`shgo` 전역 샘플링 초기화 → ICP → 겹침 검사 → PCM. FFT 는 인접 프레임 극좌표 이미지
(`prev_polar_sonar`) 로만 돌아 NSSM 에 시드를 주지 않는다. 루프가 몇 번 시도·수락됐는지
카운터가 없다(`[INSTR] counters` 에 nssm 항목 없음).
`[EVIDENCE: core/localization.py:443-560, core/slam.py:1327-1400, factor_graph.py:253,288]`

### D5. 실험 인프라

- bag 정본 `/workspace/data/bags/2026-09-02-bluerov2-lawnmower-tilt30/` (sim PR #28 상태,
  FLS 하향 30°, 424 s, `/bluerov2/altitude` sensor_msgs/Range 1,680 msg 포함) 과 `…-tilt10/`.
- 재생 = `slam.launch.py use_sim_time:=true rviz:=false evaluate:=true` + `ros2 bag play --clock`.
  관측기 `traj_2d_error_accumulator`(2D err, mean_err, pairs) · `slam_accuracy_monitor`
  (err_gt, Acc@1m, ATE_RMSE) 가 GT(`/bluerov2/odometry`, 무노이즈) 대비 오차를 낸다.
- 시뮬 DR = GT 이므로 "DR 검증 통과율" 은 곧 "FFT 가 GT 와 0.5 m/5° 이내" 의 비율이다.
  DR 을 시드로 쓰면 오차가 0 에 가까워지는 것이 **정상**이고, 그래서 제약 2·3 이 있다.
- 한 런 ≈ 8 분(실시간 재생). GPU 불필요. 결정론적이지 않다(BEST_EFFORT 드롭·근사 시간동기)
  → 베이스라인 2회로 산포를 먼저 잰다.

## Metrics (한 런의 결과 = metrics.json 한 장)

| 축 | 지표 | 출처 | 방향 |
|:--|:--|:--|:--|
| (a) 오차 | `mean_err_2d`, `final_err_2d`, `ate_rmse`, `acc_at_1m` | 관측기 로그 마지막 줄 | 낮게 / acc 높게 |
| (b) DR 의존 | `seed_dr`, `reject_pos`, `reject_rot`, `ssm_init_failed`, `factor_odom` | `[INSTR] counters` | 낮게 (제약 2) |
| (c) 정합 건강 | `icp_attempted`, `icp_converged`, `seed_fft`, I11 `ratio` median/IQR | counters, `[INSTR] scale` | ratio → 1.0, IQR 좁게 |
| (c) 루프 | `nssm_attempted`, `nssm_icp_ok`, `pcm_accepted`, `loop_factors` | **E0 에서 추가할 카운터** | > 0, 수락률 |
| 위생 | `died`, `traceback`(종료 시 ExternalShutdown 제외), `keyframes` | launch 로그 | 0 |

**판정 규칙**: (a) 가 베이스라인 산포(2회 차)의 2배 이상 좋아져야 "개선". (b) 가 늘면서
(a) 가 좋아지면 개선이 아니다(제약 2). (c) 루프 0 인 낮은 ATE 는 "단순 경로" 일 수 있어
루프 수를 항상 병기한다(profile rules.md).

**부정행위 감사(모든 probe 의 diff 에 적용)**: ICP 결과 자리에 DR 변환을 쓰는 경로 신설 금지 ·
검증 임계값을 사실상 무한대로 두어 "FFT 항상 유효" 로 만들면서 FFT 가 DR 을 베끼는 구조 금지 ·
`use_dr_rotation` 은 false 고정(true 는 매 프레임 DR 사용) · SSM/NSSM `enable` true 고정 ·
키프레임 조건을 극단화해 ICP 를 거의 안 돌리는 것 금지(icp_attempted ≥ keyframes − ssm_init_failed).

## Hypotheses and experiment menu

단일 변수 원칙(profile rules.md). 각 E 는 tilt30 bag 전체 재생 1회(산포 의심 시 2회).

| ID | 가설 / 변경 | 근거 | 예측 |
|:--|:--|:--|:--|
| **E0** | 베이스라인 ×2 (현 `fix/fft-rotation`) + NSSM 카운터 계측 추가(동작 불변) | D5 | 산포 측정. mean_err ≫ 5 m |
| **E1b** | Bruce 의 φ=0 투영을 최소 수정: r → r/cos(τ) 상수 척도 (ICP 점군·FFT 거리축 동일). 새 입력·결정 불필요 | D1 | 빔 중심에서 변위 정확, FOV 끝 ±10%. I11 median → ~1.0 방향, mean_err 감소 (첫 probe) |
| **E1a** | 고도 기반 투영 ρ=√(r²−h²) (h=`/bluerov2/altitude`), ICP·FFT 동일 | D1 | 바닥점 정확. E1b 보다 IQR 더 좁게, mean_err 대폭 감소 (승인 시 최우선) |
| E1c | 기하 ROI: 바닥이 보이는 거리띠 [h/sin(τ+10°), h/sin(τ−10°)] 만 ICP·FFT 에 사용 (사용자 ROI 제안의 기하 버전) | D1·D2 | 클러터·비바닥점 제거로 IQR 축소 |
| **E2** | CFAR 클러터 억제: `Pfa` 0.01→0.001, `threshold` 80→120, `Ntc`, 프레임당 상위 N 점만 | D2 | 피처 173→~90, ratio IQR 축소 |
| E3 | ICP 체인(`icp.yaml`): outlier `maxDist` 3→1.5, trimmed `ratio` 0.8→0.7, 반복 40→80, `knn`; `cov_samples` 30→10/60 | libpointmatcher | 수렴 안정성 |
| E4 | FFT 전처리(Hurtós 2015 계열): 가우시안 창(σ=w/4), CLAHE/대비 스트레치, 대역 필터, 상위-k 피크 → ICP 가 가장 잘 수렴하는 시드 채택, 피크 품질(PSR) 게이트 | 문헌 | reject_pos 감소 |
| E5 | 키프레임 정책: `keyframe_translation` 1.0→0.5 / 1.5, `keyframe_rotation` 10°→5°, `ssm.target_frames` 3→5 | Bruce 는 2 m/30° | 겹침↑ 로 ICP 정확도↑ vs 드리프트 누적 |
| E6 | NSSM: `min_st_sep`, `source_frames`, `min_pcm`, shgo 파라미터; 키프레임에 극좌표 이미지를 보관해 **FFT 로 NSSM 시드** | D4, Hurtós(시공간적으로 먼 프레임 등록 가능) | 루프 수락 > 0 |
| E7 | DR 비의존 검증 게이트: FFT↔ICP 상호 일치(|ICP−FFT| 작음) + ICP 겹침/잔차로 수락하고, 불일치 때만 DR 검증으로 떨어짐 | 제약 2 | seed_dr 감소, 오차 유지 |
| E8 | 승자 조합 후 tilt10 bag 회귀 확인 (10° 에서 나빠지면 안 됨) | — | tilt10 mean_err ≤ 1.5 m 유지 |

순서: E0 → E1b → E1a(승인 시) → E1c(IQR 이 넓게 남으면) → E2 → E5 → E3 → E6 → E7 → E4 → E8.
증거가 순서를 바꾸면 바꾸되 이유를 run 의 manifest 에 적는다.

## Parameter coupling

### Tier 1 — follows mechanically; nothing to set

- `sonar.sonar_tilt_deg` = 30.0 (bag 의 FLS 장착각과 일치, 가드 테스트
  `test_sonar_tilt_matches_sim_scenario.py` 가 강제). `use_sim_time` = true (bag 이 /clock 발행).
  `mode` = slam, `rviz` = false, `evaluate` = true. `fft_localization.use_dr_rotation` = false.
- `enable_2d_mapping` = false, `enable_3d_mapping` = false — 모든 런 동일. 위치추정에 영향
  없고 CPU 만 줄인다 `[DERIVED]`. (매핑 켠 tilt10 재생에서도 ICP 216/216 이었음)
- E1a 의 h 는 `/bluerov2/altitude` 최신값을 프레임마다 읽는다. 값이 없으면 그 프레임은
  raw 투영으로 떨어지고 카운터 `altitude_missing` 를 올린다 `[DERIVED]`.

### Tier 2 — real coupling; a decision is required

| knob | current | options | coupling | marker |
|:--|:--|:--|:--|:--|
| 고도 입력 | 미사용 | (a) `/bluerov2/altitude` 구독 허용 / (b) 고도 없이 r/cos τ 만 | 실기 배포 시 DVL 고도가 있어야 함; 시뮬 고도는 GT | `[DECISION-REQUIRED: altitude-input]` |
| FFT 검증 게이트 | DR 대비 0.5 m / 5° → **0.25 m / 10° (확정)** | (a) 전 probe 에서 고정, E7 만 예외 / (b) 튜닝 허용 | 느슨하게 하면 seed_dr 이 정의상 줄어 (b) 축이 무의미해짐 | `[DECISION-REQUIRED: validation-gate]` |
| 주 지표 가중 | 없음 | (a) mean_err_2d 우선, seed_dr 은 악화 금지 조건 / (b) 두 축 동등 | 승자 선택 규칙 | `[DECISION-REQUIRED: metric-priority]` |
| NSSM FFT 시드 | 없음 | (a) 키프레임마다 극좌표 이미지 보관(500×512 uint8 ≈ 256 KB × 키프레임 수) / (b) 안 함 | 메모리 · E6 범위 | `[DECISION-REQUIRED: nssm-fft-seed]` |

### Tier 3 — no coupling to the variables under test; leave byte-identical

`slam_icp_noise` [0.1,0.1,0.01], `slam_loop_robust_c` 3.0, `pcm_queue_size` 5, `min_pcm` 3
(E6 제외), `keyframe_*` (E5 제외), `CFAR.*`·`filter.*` (E2 제외), `icp_config` = icp.yaml
(E3 제외), `fft_localization.range_min` 0.5 · `trans_erosion_iterations` 2 · `trans_gaussian_*`
(E4 제외), `sonar.range_max` 40, `sonar.range_min` 0.5, `point_downsample_resolution` 0.5,
`ssm.max_translation` 3.0 · `ssm.max_rotation` 30°.

## Decisions for the user

- `[DECISION-REQUIRED: altitude-input]` **ICP·FFT 투영에 DVL 고도(`/bluerov2/altitude`)를
  써도 되는가?** — 권장 (a) 허용. DR(오도메트리 적분)이 아니라 센서 관측이며 제약 2·3 에
  저촉되지 않는다. 안 쓰면 E1b(r/cos τ) 가 상한이고 거리별 6–11% 오차가 남는다.
- `[DECISION-REQUIRED: validation-gate]` **DR 검증 임계값(0.5 m/5°)을 고정하는가?** —
  권장 (a) 고정, E7 에서만 DR 비의존 게이트를 별도 실험. 느슨하게 풀어 seed_dr 을 줄이는
  것은 제약 2 의 지표를 망가뜨린다.
- `[DECISION-REQUIRED: metric-priority]` **승자 선택 규칙** — 권장 (a): mean_err_2d 가
  개선되고 seed_dr+ssm_init_failed 가 베이스라인보다 늘지 않을 것. 두 축이 반대로 가면
  사용자에게 보고하고 결정 받는다.
- `[DECISION-REQUIRED: nssm-fft-seed]` **키프레임 극좌표 이미지 보관을 허용하는가?** —
  권장 (a) 허용(424 s 런 ≈ 220 키프레임 × 256 KB ≈ 56 MB). E6 의 FFT 시드 실험 전제.

결정 없이 진행하는 것(세션 판단): bag 재생은 GPU 시뮬 launch 가 아니므로 사람 승인 게이트
없이 세션이 실행한다(profile launch.sh 의 D4/B8 는 시뮬 launch 에 대한 것). 작업 브랜치는
slam `exp/tilt30-localization` (base `fix/fft-rotation`, 체인 #22→#23→#24→fft-rotation).
한 probe = 한 커밋, 결과는 `/workspace/experiments/slam-tilt30/<run_id>/` 에만 기록.

## Decision log (2026-09-02, 요청자 확정)

| marker | 결정 | 비고 |
|:--|:--|:--|
| `altitude-input` | **허용** — `/bluerov2/altitude` 를 ICP·FFT 투영 입력으로 쓴다 (E1a) | 실기에도 DVL 고도 필요 |
| `validation-gate` | **0.25 m / 10° 로 고정** (요청자 제안, 세션 동의) — 모든 probe 공통, E7 만 `gate=mutual` 로 별도 표시 | 이전 0.5 m/5°. 0.25 m 는 거리 분해능 0.08 m/bin 의 ~3 bin; r·cosτ 투영의 25% 체계적 압축(1 m 간격에서 0.25 m)이 E1 에서 사라져야 통과율이 오른다. E0 베이스라인의 seed_dr 은 이전 런보다 높게 나오는 것이 정상 |
| `metric-priority` | **(a) 오차 우선 + DR 악화 금지** | mean_err_2d·ATE 개선 && seed_dr+ssm_init_failed 비증가 |
| `nssm-fft-seed` | **허용** — 키프레임마다 극좌표 이미지 보관(≈56 MB/런) | E6 |

## Predicted outcome

E1(투영 수정)이 지배적일 것으로 예측: E1b 만으로 I11 median 이 ~1.0 근처로 가고 mean_err 가 수 m 대로, E1a 가 IQR 을 더 좁힌다.
E2 까지 합쳐야 tilt10 수준(≤1.5 m)에 접근한다. NSSM 은 lawnmower 경로에서 인접 leg 가
소나 FOV 안에 들어와야 루프가 생기므로 0 회일 가능성이 있다 — 그 경우 "루프 없음" 이
결과이지 실패가 아니다. 정직한 null 가능성: E1a 후에도 mean_err 가 5 m 이상이면 D1 이
주원인이 아니며 D2(클러터) 또는 ICP 자체 문제로 축을 옮긴다.

## Eval schedule

- 한 런 = tilt30 bag 424 s 전체 재생(≈ 8 분 + 파싱 1 분). 90 s 절단 런은 스크리닝용으로만.
- E0 2회 → 산포 확정. 이후 E 마다 1회, 판정 경계에 걸리면 2회.
- 각 런 직후 metrics.json 을 표 한 줄로 누적(`experiments/slam-tilt30/SUMMARY.md`).

## Wall-clock and budget

E0(2)+E1(1–3)+E2(2)+E5(2)+E3(2)+E6(2)+E7(1)+E4(2)+E8(2) ≈ 16–18 런 ≈ 2.5–3 h 머신 시간
+ 코드 변경. 토큰: 런 로그는 파싱 스크립트가 요약하므로 세션은 로그를 직접 읽지 않는다.

## Deferred

- `omx wiki list --status needs-experiment`: `finding/007` (velocity vs cascade 모드,
  cross-track 은 guidance 층) — 제어 쪽이며 이 프로그램과 무관. 명시적 defer.
- `--status needs-apply-before-retrain`: 0 건.
- 이월 큐 N7 god-method · N8 SSM/NSSM 중복 · N3 FFT 품질 게이트(decision/009): N3 는 E4
  의 피크 품질 게이트와 겹치므로 E4 결과를 N3 에 회신한다. N7·N8 은 이 프로그램에서 손대지
  않는다(리팩터 섞지 않음).
- 틸트 정본(30° 유지 vs 10° 복귀) 결정: 이 프로그램의 결과가 근거가 된다. sim PR #28 은
  열어 둔다.
