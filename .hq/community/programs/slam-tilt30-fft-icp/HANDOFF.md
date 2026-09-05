> ⚠️ **이 문서 앞부분은 2026-09-02 상태다.** 현재 상태는 맨 아래
> **「인계 2026-09-05 오전 — 이방성 기각, 판정 절차 결함, 압축의 층별 귀속」**
> 절이다. 제약 조건(브리프 원문)만 아래에서 읽고, 나머지는 최신 절을 따를 것.
>
> ⚠️ **판정 절차가 바뀌었다** — 대조군은 같은 큐 안에 `base, arm, base, arm`
> 으로 인터리브하고, 완전분리는 그 형태로 얻은 것만 근거로 쓴다(`finding/045`).
> 이 문서 곳곳의 "n=3 완전분리" 판정 중 다른 시간창의 기준선과 견준 것은
> 근거가 아니다.

# slam-tilt30-fft-icp — 인계 (2026-09-02, compact 직전)

## 브리프 (사용자 원문, 축약 금지)

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

판정 규칙(사용자 확정): **(a) 오차 우선 + DR 의존 악화 금지.** 검증 게이트는 0.25 m / 10°
고정. 고도 입력 허용. NSSM 의 FFT 시드용 극좌표 영상 보존 허용.

## 현재 승자

`sonar.projection: altitude` + `TrimmedDistOutlierFilter.ratio: 0.4` + `keyframe_translation: 1.0`
→ mean_err **2.878 m** (공통 pairs 5090 기준), 기준선 19.888 m 대비 7배.

## 확정 사실 (되풀이 금지)

1. **D1 기각** — 경사거리 투영이 ICP 를 압축한다는 가설. `altitude` 단독은 23.8 → 22.0 m 로 잡음 수준.
2. **D6 확정** — 몸체 고정 거리 띠. tilt 30°/고도 4.6 m/수직 FOV 20° 에서 바닥 반사는
   수평거리 [5.5, 12.6] m 에만 든다(오프라인 CFAR 실측 경사거리 p25–p75 = 8.5–12.6 m).
   E9 가 직접 확증: 키프레임 이동만 1.0 → 0.5 m 로 줄여 FFT 통과율 38.8% → **58.3%**.
3. **D7 확정** — 두 축은 독립. trim 이 오차축, altitude 투영이 DR 의존축을 각각 고친다.
4. **E7 사산** — DR 없는 품질 게이트 불가. `trans_peak`·`rot_peak`·`cov[0]` 과 pos_err 의
   상관이 전부 |0.23| 이하. 피크 상위 50% 부분집합의 pos_err p90 이 0.48–0.68 m 로
   0.25 m 게이트를 대체 못 한다. **실험 불필요.**
5. **E4 기각** (`remove_radial_mean`) — 길이보정하면 무승부(2.562 vs 2.572)이고 DR 의존만 악화.
   기전: tilt 30° 에선 바닥 반사 자체가 거리 색인된 띠라 행 평균이 지형과 교란돼 있다.
6. **E1c 기각** (`use_roi`) — ROI 는 의도대로 동작(1052×1456 → 235×594, 면적 5.5%)하고
   FFT 통과율도 41.1% 로 개선됐으나 오차 2배(5.183). ICP scale ratio q1 0.9331 → 0.8884,
   `icp_inert` 13 → 17. 가설 기전은 CLAHE `tileGridSize=(8,8)` 이 크롭마다 다른 타일 크기가
   되는 것(**미확증**). 배선·테스트는 남겼고 기본 false.
7. **E9·E10 기각** — 키프레임 0.5 m 는 ICP 이동 분해 하한 아래. trim 을 조이면 항등 편향
   (`icp_inert` 9.6%), 풀면 잡음(ratio q1 0.6659)이라 중간 지점이 없다.

## 측정 규약 — 반드시 지킬 것

- **`mean_err` 를 그대로 비교하지 말 것.** 런마다 처리 프레임이 달라(feat_frames 5805/5000/4855)
  짧은 런일수록 구조적으로 낮게 나온다. `python3 cmp_at_common_pairs.py <run_dir>...` 로
  공통 pairs 지점의 `cum_err(N)/N` 을 쓴다.
- 같은 설정 복제쌍 산포가 **약 10%** — 그보다 작은 차이는 무승부.
- `pairs < 3,400` 런은 러너가 자동으로 `~~폐기~~` 표시한다. 판정에 쓰지 않는다.
- 반칙 감시는 **두 지표를 같이** 본다: `icp_inert`(편향)와 ICP scale ratio 사분위(분산).
  하나만 보면 E10 을 개선으로 오독한다.

## 러너

```bash
cd /workspace/experiments/slam-tilt30
PROJECTION=altitude \
ICP_SET="outlierFilters.1.TrimmedDistOutlierFilter.ratio=0.4" \
YAML_SET="a.b=1;c.d=2" \
bash run_replay.sh <label> [tilt30|tilt10]
```

- `BAG_RATE` 기본 **1.0** (2026-09-02 사용자 지시로 0.5 에서 변경). 머신 경합이 재발하면
  개별 런에서 `BAG_RATE=0.5`.
- 전용 `ROS_DOMAIN_ID=77`.
- ⚠️ **돌고 있는 `run_replay.sh` 를 편집하지 말 것** — bash 가 스크립트를 증분으로 읽어
  뒤쪽 줄에서 구문 오류로 죽는다(이미 한 번 당함).

## 경로

| 무엇 | 어디 |
|:--|:--|
| 런 출력 SSOT | `/workspace/experiments/slam-tilt30/<run_id>/` |
| 비교표·판정 기록 | 같은 폴더 `SUMMARY.md` |
| 코드 | `~/orca/workspaces/workspace/object_detection_to_2d_mapping/src/stonefish_slam`, 브랜치 `exp/tilt30-localization` |
| ⚠️ 함정 | `/workspace/src/stonefish_slam` 은 **다른 체크아웃**(`chore/dead-code-cleanup`). 여기 고치면 실험에 안 들어간다 |
| bag | `/workspace/data/bags/2026-09-02-bluerov2-lawnmower-tilt{10,30}/` |

## 남은 일

1. **`e11` (kf 0.7, trim 0.4)** — 진행 중. ICP 이동 분해 하한의 위치를 잰다.
   끝나면 `run_replay.sh` 의 `BAG_RATE` 기본값이 1.0 으로 바뀌는 대기 작업이 붙어 있다.
2. **E2 CFAR 임계** — 특징점 690개/프레임의 클러터 비중. 오차축 마지막 미탐색 손잡이.
3. **E6 NSSM + FFT 시드** — 루프 클로저 시드를 DR 에서 FFT 로. 제약 2 직접 개선.
4. **최종 승자 rate 1.0 재현** — 정본 수치 확정.
5. **tilt 10° 회귀** — `bash run_replay.sh <label> tilt10`.
6. **마감** — `exp/tilt30-localization` → base `fix/fft-rotation` PR(SUMMARY 표 첨부),
   `omx wiki` 에 확정 사실 7건 등재, decision/009 N3 회신.
7. **사용자에게 물을 것** — 정본 틸트 결정(30° 복원 런이 10° 대비 궤적 발산이 크다는 미결 건).

조건부: e11 이 kf 0.7 에서 오차를 지키면 kf 0.85 로 벽 위치를 좁힌다.

## 코드 변경 (모두 `exp/tilt30-localization`)

`sonar.projection`(legacy/inv_cos_tilt/altitude) · `fft_localization.remove_radial_mean` ·
`fft_localization.use_roi`/`roi_threshold` · 고도 구독 · 계측(`icp_inert`·`nssm_*`·`feat_*`·
scale ratio) · 배선 테스트(변이 검증 완료). 전체 142 passed
(+ `test_sonar_tilt_matches_sim_scenario` 1건은 **기존** 실패).

### 함정 3 — 런처는 `nohup ... &` 로 띄우지 말 것

`run_replay.sh` 는 백그라운드 작업의 **전경 명령**으로 돌린다:

    Bash(run_in_background=true, command="... bash run_replay.sh <label> tilt30")

`nohup bash run_replay.sh ... & sleep 20; tail` 처럼 띄우면 두 단계로 망가진다.
2026-09-02 w0 가 이 경우였다:

1. 앞단이 끝나는 순간 하네스가 프로세스 그룹을 정리해 **ROS 노드들**이 43초에 죽는다.
   exit 0 으로 끝나고 `pairs=558` 짜리 디렉터리만 남아 "rate 1.0 이 프레임을 흘렸다"
   로 오독하기 쉽다.
2. 그런데 `nohup` 이 **스크립트 자신**은 살려둔다. 살아남은 스크립트가 말미의
   `kill_ros` 에 도달하면 그때 돌던 **다음 런**을 죽인다 — `kill_ros` 는
   `pgrep -f "$KILLPAT"` 로 머신 전역에서 이름 매칭해 죽이므로 `ROS_DOMAIN_ID`
   격리가 프로세스 킬에는 안 통한다. w0 두 번째 시도가 29초에 이렇게 죽었다
   (세 노드 전부 `ExternalShutdownException`).

**런을 띄우기 전 `pgrep -af "run_replay\.sh|ros2 bag play|slam_node"` 로 잔여
프로세스가 없는지 확인하라.** 이 서명(런 중간에 세 노드가 동시에
`ExternalShutdownException`)이 보이면 외부 세션이 아니라 이쪽 고아 스크립트를
먼저 의심하라 — 앞서 `e0-base-r05` 가 288초에 죽은 것도 "다른 세션 탓" 으로
적었지만 같은 원인일 수 있다(미확인).

---

## 2026-09-02 세션 종료 상태

**승자**: `sonar.projection: altitude` + `TrimmedDistOutlierFilter.ratio: 0.4` +
`keyframe_translation: 1.0` → **mean_err 2.741 m** (기준선 19.888 m, 7.3배).
대조군 런은 `experiments/slam-tilt30/w1-clean-r10_260902_055131`.

**커뮤니티 등재 완료** — `finding/011`(실험 결과·D6·남은 병목),
`finding/012`(실험 위생 함정 7가지). 세부 수치는 `experiments/slam-tilt30/SUMMARY.md`.

**복제 산포 22%** 가 이 계열의 판정 하한이다. 이보다 작은 차이는 결과가 아니다.

### 미완 항목

| 항목 | 상태 |
|:--|:--|
| tilt 10° 회귀 | **미완** — 승자 설정 런은 있으나(`r10-winner-tilt10_260902_064149`) 비교할 변경 전 기준선 런이 pairs 6474 에서 중단됨. 다시 돌려야 판정 가능 |
| PR (`exp/tilt30-localization` → `fix/fft-rotation`) | 미착수 |
| decision/009 N3 회신 | 미착수 |
| 정본 틸트 결정 질의 | 미착수 |

### 다음에 성능을 더 올리려면

config 층은 소진됐다. 남은 병목은 FFT 병진 오차(중앙 0.342 m, 게이트 0.25 m)이며
품질 선별·척도 보정·전처리 평활 셋 다 막혔다(`finding/011`). 상관 알고리즘 자체를
바꿔야 하고, 후보 중 **다중 가설 시드**가 가장 값이 있다 — 상위 N개 상관 피크를
ICP 에 넣고 고르는 방식으로, ICP 수렴률이 이미 100% 라 비용이 싸다.

---

## 2026-09-02 권한 확장 (사용자 지시)

> "내가 제약 조건이라고 한 부분 있지? 이걸 만족해야하는건 분명하지만
> **실험할때는 이 제약조건을 얼마든지 수정해도 괜찮아**."

**최종 채택 설정은 제약 4개를 모두 만족해야 한다**(FFT·ICP 필수 / DR 최소 /
속임수 금지 / SSM·NSSM 필수). 그러나 **진단 목적의 런은 제약을 깨도 된다** —
`nssm.enable=false`, `max_position_error` 변경, `use_dr_rotation=true`, DR 전용 런
전부 허용. 진단 런은 후보가 아니라 원인 분리용이며, SUMMARY 에 진단임을 명시한다.

## 새 진단 — DR 이 61% 인데 오차가 큰 이유

`w1-clean-r10` 팩터 그래프 구성 실측:

| 팩터 | 개수 |
|:--|--:|
| ICP | **184** |
| odometry (DR) | **1** |
| NSSM 루프 (PCM 통과) | 111 |

**"DR 시드 61%" 는 ICP 의 초기추정만 DR 이라는 뜻이고, 그래프에 들어가는 것은
ICP 결과다.** 완벽한 DR 로 시작해도 ICP 가 그것을 옮기고, 옮겨진 값만 남는다.

가중치가 이를 강화한다 — `slam_icp_noise [0.1,0.1,0.01]` 대
`slam_odom_noise [0.2,0.2,0.02]`. 시그마 절반 = 정보행렬 4배. 팩터 수 184:1 에
개당 신뢰도 4배가 겹쳐 그래프는 사실상 ICP 만 듣는다. 시뮬 DR 이 무노이즈 GT 인데도
그 정보가 최종 자세에 거의 반영되지 않는 구조다.

이것이 "정합이 안 돌면 오차가 0.010 으로 떨어지는" 현상의 이면이다.

## 다음 두 런 (compact 후 즉시 실행)

| # | 설정 | 답하는 질문 |
|--:|:--|:--|
| D1 | `nssm.enable=false` | 오차가 SSM 에서 오나 NSSM 에서 오나 (진단 전용, 제약 위반) |
| D2 | `fft_localization.max_position_error=0.5` | 게이트 완화 시 FFT 시드 38.9% → 약 68%, 오차는? |

D2 근거: 게이트 분포에서 pos_err 0.25~0.5 m 구간이 전체의 29%. 완화하면 그만큼
추가 통과한다. 다만 그 시드는 0.25~0.5 m 틀린 값이라 방향은 미정 — 부정확한 FFT
시드가 완벽한 DR 시드보다 나은지는 재봐야 안다.

판정은 새 대조군 `w1-clean-r10_260902_055131` (mean_err 2.741 @ pairs 5819) 과
공통 pairs 로만 하고, **22% 미만 차이는 결과가 아니다.**

### 이어서 볼 후보 (D1·D2 결과에 따라)

| 후보 | 내용 |
|:--|:--|
| D3 | `slam_icp_noise` 를 `slam_odom_noise` 와 같거나 크게 — 그래프가 DR 을 더 듣게 |
| D4 | 회전 고정 후 병진만 재추정 (FFT 회전으로 영상 정렬 → 병진 상관 재실행) |
| D5 | 다중 가설 시드 — 상위 N개 상관 피크를 ICP 에 넣고 선택 |

D4·D5 는 코드 변경이며, `reject_pos` 117 대 `reject_rot` 4 라는 비대칭(회전은
2.04° 로 정확, 병진만 0.342 m 로 부정확)이 그 근거다.

---

# 인계 2026-09-04 — 사이클 종료

제약 조건은 이 문서 맨 위 **브리프 (사용자 원문)** 그대로 유효하다. 2026-09-04 에
하나 추가됐다: *"tilt 30 은 성능 감소가 있지만 어쩔 수 없이 만족해야 하는 사항이다."*
→ 정본 틸트 30°, tilt10 은 **회귀 가드로만** 쓰고 이득 크기는 더 재지 않는다.

## 지금 어디까지 왔나

**DR 폴백** shallow 4.27 → **0.50%**(8.5배) · tilt30 15.15 → **5.39%**(2.8배) ·
tilt10 3.30 → 1.77%. 오프라인 게이트 tilt30 83.0 → 89.9% · shallow 92.7 → 96.0%.

채택 설정 (`src/stonefish_slam/config/slam.yaml`):

```yaml
trans_lowpass: 0.5 · trans_clahe: false · trans_window: 'hann'
warp_retry: true · dft_refinement_enable: false
rotation_candidates: 9 · max_position_error: 0.25   (둘 다 변경 없음)
keyframe_max_angular_vel: 0.0                        (되살렸으나 끔)
```

Phase D~K 판정표와 실측은 `PLAN-PHASE4.md` 말미와
`/workspace/experiments/slam-tilt30/SUMMARY.md`.

## 승인 대기 (사람 게이트, 손대지 말 것)

1. **push + PR 개설.** `src/stonefish_slam` 브랜치 `exp/tilt30-localization`,
   origin 대비 **ahead 6**. 본문 초안은 이 디렉터리의 `PR-BODY-DRAFT.md`
   (126 줄, 커밋 6건·기각 2건·미결 3건 반영 완료).
2. **sim PR #28 상호 링크.** slam pytest 의 유일한 실패
   `test_sonar_tilt_matches_sim_scenario`(로컬 sim `.scn` 10.0° vs slam.yaml 30.0°)가
   그 PR 이 머지되면 해소된다. CONTRIBUTING §5 가 상호 링크를 요구한다.
3. 메타 repo `.hq` 기록 push (이 인계문 포함).

## 미결 3건 — 다음 세션의 실제 일감

### (1) 병진 압축 ≈ 7~8% — 사용자가 RViz 에서 눈으로 확인한 것

키프레임 사이 병진이 매번 짧게 들어간다. 두 값의 곱이다:

| 단계 | 값 | 출처 |
|:--|--:|:--|
| FFT 시드 / 실제 | 0.929 (tilt30) · 0.936 (shallow) | 오프라인, DR=GT 대비 |
| ICP 결과 / 시드 | 0.994 | 온라인 `[INSTR] scale ratio` |
| 두 단 곱(추정) | ≈ 0.923 | |
| **종단 실측 `len_ratio`** | **0.846** | 2026-09-04 shallow 재생 `s14len-b`, 276.4 / 326.7 m |

⚠️ **실측이 추정의 두 배다**(15.4% vs 7.7%). 차이의 기전은 미확증 — 팩터그래프
최적화가 더 당기는 것인지, 오프라인 고정 쌍 집합과 온라인 키프레임 스트림의
모집단 차이인지. `finding/028`. n=1, 복제 미측정.

가설 5개(틸트 보정·고도 가정·극→직교 보간·대역 포락선·회전 결합)는 전부 반증됐다.
저역통과가 0.912 → 0.929 로 **처음** 움직였을 뿐 나머지는 그대로다.

⚠️ **계측이 이걸 못 본다. 이게 먼저 손댈 지점이다.**
- 온라인 `[INSTR] scale ratio` 는 **시드 대비**다(`core/slam.py:1364-1365`,
  `init_norm`=시드·`est_norm`=ICP 결과). 진실 대비가 아니라 0.99 로 건강해 보인다.
- `dist_total` 은 **GT 를 누적**한다(`core/slam_accuracy_monitor.py:282-288`,
  `_accumulate_total_distance(gt_xy)`). SLAM 궤적 자체의 길이를 재는 계측이
  파이프라인 어디에도 없다.
- → **처방: 2026-09-04 승인·구현 완료.** `slam_accuracy_monitor` 가 매 `[ACC]` 줄에
  `dist_slam=<m>` 과 `len_ratio=<SLAM/GT>` 를 찍는다(`polyline_length_2d`,
  `core/slam_accuracy_monitor.py:51`). `parse_metrics.py` 의 `ACC_FIELD_RE` 가
  key=value 를 통으로 긁으므로 파서 변경 없이 `metrics.json` 에 들어간다.
  ⚠️ `keyframe_stride > 1` 이면 폴리라인이 과소계산되므로 `nan` 을 낸다.
- **왜 drift 지표로는 안 보였나** — `umeyama_se2` 는 강체 정합이라 균일하게 줄어든
  경로도 GT 위로 회전·평행이동해 얹힌다. 실측: 7% 균일 압축이 `drift_window`
  **2.04%** 로만 나온다(3.4배 과소보고). 회귀 가드는
  `test_accuracy_monitor_drift.py::test_uniform_translation_compression_shows_up_as_the_length_ratio`.
- ⚠️ `/stonefish_slam/slam/traj` 는 `Path` 가 아니라 **`PointCloud2`** 다
  (`core/slam.py:636`, `ros_colorline_trajectory`). `Path` 로 구독하면 조용히 0 건이다.

### (2) 루프폐합 PCM 수락률 — 그래프 층의 병목

NSSM 깔때기(채택 설정, 런 평균):

| | 시도 | init | ICP | **PCM 수락** |
|:--|--:|--:|--:|--:|
| shallow | 100% | 98.8% | 96.3% | **83.1%** |
| tilt30 | 100% | 98.3% | 89.4% | **66.2%** |

**초기화는 병목이 아니다(98%)** — 옛 E6("NSSM 시드를 FFT 로")의 전제가 무너진다.
떨어지는 곳은 tilt30 의 ICP(89.4%)와 **PCM 수락(66.2%)** 이다. 그리고
`pcm_accepted` 가 baseline 115.0 대 채택 114.8 로 **똑같다** — 밤새 한 작업은 이
층을 전혀 안 건드렸고, 궤적 오차가 3.6~4.0 m 에서 안 움직인 이유가 여기다.

미확인 2건: PCM 이 **왜** 기각하는지(임계인지 진짜 나쁜 후보인지), 기각된 후보가
실제로 옳은 폐합이었는지. 그걸 가르는 계측이 지금 로그에 없다.

NSSM 탐색 범위 (자주 오해되는 지점, `core/localization.py:461-474`):
- **source(질의) = 최근 5 키프레임만** (`source_frames=5`)
- **target(탐색) = 0 번부터 current−15 까지 전부** (`min_st_sep=15`) — 최근만 보는 게 아니다
- 기하 게이트는 source 공분산 기반 `5σ + range_max` / `5σ + FOV/2` (`:477-491`)
- ⚠️ **가설(미확인)**: 게이트는 *추정* 포즈 중심이라, 궤적이 압축돼 있으면 진짜
  재방문 지점이 반경 밖으로 밀린다 → (1)과 (2)가 서로를 먹인다.

### (3) 2D 궤적 오차 지표의 판별력 — 이월

비교 기준 토픽이 DR 시드 출처와 같다(`core/traj_2d_error_accumulator.py:38-41`).
다만 그 교란이 **작동하지 않는다**는 것도 측정됐다(전후창 85 쌍, 48% = 우연) —
`finding/025`. 가르는 probe: odometry 에 잡음을 얹어 별 토픽으로 재발행 → SLAM
입력만 remap → `ground_truth_topic:=/bluerov2/odometry` 로 기준은 깨끗한 GT 유지.
파라미터가 이미 있어 배선만 하면 된다. **미실행.**

## 이번 사이클이 남긴 방법론 (읽고 시작할 것)

- `finding/025` — 구조적 교란이 **있다**는 것과 **작동한다**는 것은 다르다.
- `finding/026` — 게이트가 **절대** 임계면 판별력은 중앙값이 아니라 **분위수**다.
- `finding/027` — **CPU 를 쓰는 오프라인 이득은 온라인에서 스스로를 상쇄한다.**
  고정 쌍 집합 하네스는 이 되먹임을 구조적으로 못 본다.
- ⚠️ **"옛 기준선에서 기각된 축이 새 기준선에서 되살아나기" 가 이번에만 3회**
  (대역통과·DFT 보정·K=15). **기각 기록에 "무엇과 비교해서"를 반드시 남길 것.**
- `p=0.014` 는 n=4 대 4 의 **최소 달성값**. n=3 짜리 유의성은 복제 하나에 부서진다.

## 도구·경로

| | |
|:--|:--|
| 런너 | `/workspace/experiments/slam-tilt30/run_replay.sh <label> [tilt30\|tilt10\|shallow]`, `YAML_SET="k=v;k=v"` 로 덮어쓰기 |
| 오프라인 | `offline/eval_fft.py <cache>.npz --prod --set "k=v;..."` (캐시 `tilt30_kf` 188 쌍 · `shallow_kf` 354 쌍) |
| 최고설정 데모 | `tools/demo_best.sh` (shallow + TF 보충, RViz 는 따로 띄울 것) |
| TF 보충 | `tools/odom_tf_bridge.py` — shallow bag 에 `/tf` 가 없어 RViz 용으로 필요 |
| 경로길이 측정 | **관측기에 들어갔다** — `[ACC]` 줄의 `dist_slam=` · `len_ratio=`(SLAM 경로길이 / GT). `evaluate:=true` 면 매 런 자동. `metrics.json` 의 `accuracy_last` 에도 그대로 들어간다 |
| ~~`tools/pathlen.py`~~ | **사산·미삭제.** traj 를 `Path` 로 받는데 실제는 `PointCloud2` 이고, GT 로 쓰던 `/bluerov2/actual_trajectory` 는 **발행자가 코드 어디에도 없다** — 돌려도 25 초 대기 후 빈 목록만 낸다. 위 관측기 계측이 대체하므로 지울 것(이 마운트에 `gio trash` 가 안 돼 보류) |
| 결과 SSOT | `/workspace/experiments/slam-tilt30/SUMMARY.md` |

## 환경 함정 (반복 발생)

- `evaluator.sh` 는 `OMX_PROJECT_DIR` 미설정 시 **`/workspace` 를 검사** — 워크트리 결과가 아니다.
- **`localization.py` 는 CRLF.** 파이썬으로 통째 rewrite 하면 628 줄 가짜 diff 가 난다.
- 오프라인 `--set` 은 `eval()` — 문자열 값에 따옴표 필수(`trans_window='hann'`).
- `pgrep -f`/`pkill -f` 는 **자기 셸을 죽인다** → `ps -eo pid,args | awk '/[p]attern/'`.
- **bag 재생과 오프라인 평가 동시 실행 금지**(둘 다 `scipy.fft(workers=-1)`).
- 실험 런은 `ROS_DOMAIN_ID=77` + `OMP/OPENBLAS/MKL/NUMEXPR_NUM_THREADS=4`
  (스레드 상한이 없으면 온라인 런이 통째로 무효가 된다 — `finding/022`).
- 런처가 죽어도 `slam_node` 와 `odom_tf_bridge` 가 살아남는다. 다음 런 전에 확인할 것.

---

# 인계 2026-09-04 밤 — 야간 자율 배치 (진행 중)

사용자가 취침하며 "알아서 실험해서 최고의 성능 알고리즘을 토출하라" 고 지시한 구간이다.
제약 4 조와 판정규칙 (a)·게이트 0.25 m 고정은 그대로 유효하다.

## 이 밤에 확정된 것

| 축 | 결과 | 근거 |
|:--|:--|:--|
| `keyframe_translation` 1.5·2.0 | **미채택** — ATE 완전분리 개선(2.33~2.67 → 1.45~1.87)이나 DR 폴백 완전분리 악화(0.28~0.57% → 8~10%) | finding/036 |
| `remove_radial_mean` (n8band ×3) | **효과 없음** — 어느 축에서도 분리 없음(seed_gt .9295/.9306/.9313, ATE 2.539~2.734) | finding/037 · 039 |
| 전처리 전 축의 척도 편향 | **없음** — 합성 강체이동에서 오차 < 0.0001 m | finding/037 |
| 고정 지지영역 가설 | **기각** — 최대 -0.0056 m, 거리에 따라 감소해 형태도 반대 | finding/037 |
| DFT 정제 | **결함 확정** — `_upsampled_dft` 켤레 누락으로 순변환. -0.042~-0.049 m 주입. `conj` 로 감싸면 정확해짐 | finding/037 |
| 다중 패스 역워프 | **미채택** — kf2.0 구제 62%→76% 로 실재하나 DR 격차 한 자릿수 남고, kf1.0 에서는 변화 0 | finding/038 |

## 지금 돌고 있는 것 (체인, 사람 개입 불필요)

```
queue2.txt  n8band(완) → n4sep8 → n7dft ×3 → n5tgt5 ×3     runlist.sh, PID 462374
  ↓ offline/after_queue.sh   dft_pairs.py · speed_scale.py  (큐가 빈 뒤에만)
  ↓ chain3.sh → queue3.txt   n4sep8-a2 · n13rc1 ×3 · n14rc8 ×3
```

`chain3.sh` 는 `run_replay|runlist|dft_pairs|speed_scale` 중 하나라도 살아 있으면 대기한다 —
병행 금지를 사람 타이밍이 아니라 스크립트로 강제한다.

## queue3 의 논거 — 축을 프런트엔드에서 백엔드로 옮긴다

`s17bearing-a` 가 **seed_gt 0.9953** (기준선 0.931) 을 냈는데 ATE 는 4.122 로 **나빠졌고**
DR 은 5.80% 로 올랐다. 즉 **씨앗 척도를 고쳐도 궤적이 좋아지지 않는다.** 척도 결손 사냥은
목적함수가 아니었다.

반면 백엔드에는 손대지 않은 축이 있다. `s16nssmoff-b`(NSSM off)는 `len_r 0.9292 ≈ igt 0.9313`
으로 **루프가 없으면 경로길이가 ICP 척도와 같다.** 채택 설정은 `len_r 0.9254` vs `igt 0.9541` —
**루프가 궤적을 3% 더 압축한다.** 그런데 루프를 끄면 ATE 가 2.33 → 7.590 으로 파탄난다.
즉 루프는 형상에 필수이면서 길이를 줄인다. 그 균형을 정하는 것이 로버스트 커널이다.

`slam_loop_robust_c`(현재 3.0)는 `.hq` 스토어·과거 런 라벨 어디에도 없는 **미시험 축**이고,
FFT 게이트보다 뒤에 있어 **구조적으로 DR 폴백을 못 올린다** — 규칙 (a) 의 한쪽만 움직인다.
1.0(루프 강하게 억제)과 8.0(거의 가우시안)으로 3.0 을 양쪽에서 감싼다. 부호를 모르므로
한 방향만 보지 않는다.

## 이 밤에 저지른 것 (반복 금지)

1. **오프라인 프로브를 온라인 런과 병행**시켜 `n4sep8-a` 를 굶겼다(feat_frames 8090,
   다른 런의 0.76 배). 스레드 캡을 양쪽에 걸었어도 소용없었다. 자동 게이트(50%)는 이걸
   못 잡으므로 런 디렉터리에 `INVALID` 파일을 두고 `tab.py` 가 `무효` 로 표시하게 고쳤다.
   `n4sep8-a2` 로 재실행 중. → finding/038
2. **`remove_radial_mean` 을 재실행**했다 — HANDOFF 의 "확정 사실 5. E4 기각" 을 읽지 않고
   큐를 짰다. 이번엔 seed_gt 계측이 새로 생겨 질문이 달랐다는 변명이 되지만, **기각 기록을
   먼저 읽었어야** 했다. 같은 실수가 이 프로그램에서 4번째다.
3. **`pkill -f` 로 자기 셸을 죽였다** — 이미 적혀 있는 함정인데 또 밟았다.

## 다음 판단 지점

- `dft_pairs.py` 가 실제 쌍에서 `on-fixed` 의 게이트 통과율이 `off` 보다 높다고 나오면
  → `_upsampled_dft` 에 켤레 패치(`scratchpad/dft_patch.py` 에 준비됨) 적용 후 `n11dftfix ×3`.
  낮거나 같으면 패치는 결함 수정으로만 넣고 채택 설정은 `false` 유지.
- 패치는 **큐 사이 유휴 구간에만** 적용한다. `run_replay.sh` 가 매 런 colcon 재빌드를 하므로
  큐 중간에 소스를 바꾸면 남은 런이 전부 바뀐 코드로 돈다.
- `speed_scale.py` 가 결손의 설명변수를 이동량이 아니라 **속도**로 지목하면, SUMMARY 의
  `0.776*|DR| + 0.150` 적합(이동량 기반)과 오늘 배치 1(간격을 넓히면 좋아짐)의 모순이
  풀린다. 그 경우 기존 "겹침 부족" 서술을 다시 써야 한다.

## 추가 확정 (배치 2 완료분)

| 축 | 결과 | 근거 |
|:--|:--|:--|
| `dft_refinement_enable=true` (현행 구현) | **기각** — 2D mean 2.917/3.170/3.429 로 기준선 2.322/2.819/2.824 와 완전분리 악화 | finding/039 |
| **`seed_gt` 의 지표 타당성** | **무효** — 같은 개입이 seed_gt 를 완전분리로 올리며 2D mean 을 완전분리로 악화시켰다. 오차 축은 **2D mean·ATE 뿐**이고 seed_gt·icp_gt·len_ratio 는 단독 개선 근거가 될 수 없다(소급 적용) | finding/039 |
| `nssm.min_st_sep=8` | n=2 (a 무효) — ATE 2.300/2.725 로 기준선과 겹침. `n4sep8-a2` 로 n=3 채우는 중 | queue3 |

**이 밤의 예측 실패 1건**: 오프라인 합성에서 깨진 DFT 가 -0.044 m 축소를 냈으므로
온라인 seed_gt 가 0.88 로 떨어질 것이라 예측했다. 실측은 0.937~0.943 으로 **올랐다**
— 부호까지 틀렸다. 이상적 스펙트럼에서 결정론적이던 오차가 실 데이터에서 무작위가
되어 중앙값 대신 크기를 팽창시켰기 때문이다. 오프라인 프로브는 결함의 **존재**를
맞혔지만 **어느 지표에 어떤 부호로** 나타날지는 못 맞혔다.

## 추가 확정 (배치 3, 18:32 기준) — 척도 축을 닫았다

**이 밤 가장 큰 결론이다. 척도 부족분을 더 쫓지 말 것.**

1. **DFT 정제는 켤레를 고쳐도 이득이 없다** (finding/040). 실제 250 쌍에서
   off / on-broken / on-fixed = 중앙 0.0993 / 0.1157 / 0.1007 · 통과율
   0.968 / 0.972 / 0.964. `dft_refinement_enable: false` 유지. `n15dftfix` 팔 취소.
2. **고도 보정은 원인이 아니다** (finding/041). h 를 0.8~2.0 배로 쓸었을 때
   정확도 최적점이 두 stride 모두 k=1.00(고도계 실측값)이고, 어떤 고도로도 척도가
   1.0 에 안 닿으며(최대 0.9721 / 0.9853), 척도 최대 k* 가 stride 마다 다르다
   (1.40 대 1.20 → 변위 무관이라는 보정 오차의 요건 위반).
3. **부족분은 비율이 아니라 상수다.** k=1.00 에서 변위 1.052 m 에 0.074 m,
   3.169 m 에 0.102 m — 약 **1 픽셀**(0.08 m/px). "7% 척도 결손" 은 이 상수를 짧은
   변위로 나눈 값이었다. 키프레임 간격이 넓을수록 척도가 1 에 가까워 보이는 것도 같은 이유.
4. **다섯 개입 전부 같은 방향.** 서브픽셀 편향 · 고정 지지영역 · radial mean ·
   DFT 두 판본 · 고도 보정 — 모두 "척도를 올리면 정확도가 나빠지거나 그대로".
   척도를 최적화 대상에서 제외한다.
5. **합성 프로브의 구조적 맹점** (finding/037 정정 3). `synth_bias` 는 직교영상을
   알려진 픽셀 수만큼 옮기고 **같은** `cart_range_resolution` 으로 되돌리므로 계측
   보정 오차가 정확히 상쇄된다 — 언제나 1.0000 이 나온다. 그 문서의 "무편향" 을
   척도의 반증으로 읽지 말 것.

### 코드 산출물

`e58c9e0` — `_upsampled_dft` 켤레 복원(`conj(F(conj(x))) = N·F⁻¹(x)`) + 회귀테스트
3 건. 채택 설정에서 죽은 경로라 **런 결과를 바꾸지 않는다.** 정합성 수정이다.
패치 전 3 실패 → 후 3 통과, 전체 스위트 177 passed.

### 이 배치에서 저지른 것 (반복 금지)

**배선 감사를 러너가 빌드하지 않는 체크아웃에서 돌렸다.** `/workspace/src/stonefish_slam`
(브랜치 `chore/dead-code-cleanup`)을 보고 `dft_refinement_enable`·`remove_radial_mean`
이 무배선이라 결론지어, n7dft·n8band 두 팔을 "실행된 적 없음" 으로 무효화할 뻔했다.
러너가 빌드하는 것은 워크트리(`exp/tilt30-localization`)이고 거기서는 다섯 키 모두
정상 배선이다. **감사 전에 `run_replay.sh` 의 `colcon build` 대상 트리를 먼저 읽을 것**
(`run_replay.sh:9` 의 `W=`).

### 다음 세션의 일감 — 백엔드

FFT 앞단에서 더 가져올 정확도가 없다. 남은 오차원:

- `slam_loop_robust_c` (Cauchy c, 기본 3.0) — queue4 에서 1.0·8.0 ×3 씩 시험 중.
  게이트 뒤에 있어 **구조적으로 DR 을 못 올린다** = 규칙 (a) 의 한쪽만 움직인다.
- NSSM 후보 선정 (`nssm.min_st_sep` — `n4sep8` 은 `-a` 오염 폐기 후 `-a2` 재실행 중).
- 궤적 압축: 채택 설정 `len_ratio` 0.9254 대 `icp_gt` 0.9541 — 루프가 궤적을 3% 더
  줄인다. NSSM 을 끄면 둘이 일치하지만(`s16nssmoff-b`) ATE 가 7.590 으로 터진다.

### 이 밤에 채택된 것 — 없음

기각·무효과로 닫은 축: kf 간격 · remove_radial_mean · DFT(두 판본) ·
`ssm.target_frames=5`(2D 방향성만, ATE 평탄) · 고도 보정. 진행 중: `nssm.min_st_sep=8`,
`slam_loop_robust_c` 1.0/8.0.

---

## 배치 4 종료 (19:50) — 백엔드 축도 닫혔다, 채택 0 건으로 밤 종료

큐 전부 소진, 러너 없음. `finding/042` 참조.

### `slam_loop_robust_c` — 양방향 기각

| c | 2D mean | ATE | len_ratio | DR (%) |
|--:|:--|:--|:--|:--|
| 1.0 | 2.812 · 3.050 · 4.819 | 2.572 · 2.688 · 2.913 | .9367 · .9413 · .9514 | 0.00 · 0.00 · 0.28 |
| **3.0 (채택)** | **2.322 · 2.819 · 2.824** | **2.325 · 2.334 · 2.670** | .8823 · .9254 · .9280 | 0.28 · 0.29 · 0.57 |
| 8.0 | 2.668 · 3.794 · 3.914 | 2.889 · 3.878 · 4.268 | .8378 · .8530 · .8566 | 0.00 · 0.00 · 0.57 |

c=8.0 은 ATE 완전분리로 기각(최소 2.889 > 기준선 최대 2.670, p=0.05). c=1.0 은
완전분리는 아니나 두 축 다 나쁜 쪽이라 이득 방향 없음 → 기각. **c=3.0 이 국소 최적.**

**확정된 기제**: `len_ratio` 는 c 에 단조이고 세 구간이 겹치지 않는다 — 압축은 손잡이
하나로 ±0.07 제어된다. 그런데 오차는 압축에 단조가 아니다. **궤적을 압축하는 그 루프
당김이 동시에 절대 드리프트를 보정한다.** 압축은 결함이 아니라 보정의 부산물이고,
RViz 의 7~8% 압축을 줄이는 것 자체는 성능 개선이 아니다(줄이면 나빠진다).
finding/041 의 척도 부족분과 **같은 형태의 결론**이 두 축에서 독립 재현됐다.

### `nssm.min_st_sep=8` — 효과 없음

2D 2.679 · 2.664 · 2.531 / ATE 2.984 · 2.725 · 2.300 / DR 0.57 · 0.85 · 0.29.
2D 는 기준선과 겹치고 ATE 는 오히려 위쪽. 기각.

### 밤 전체 결산 — 채택 0, 닫힌 축 8

kf 간격 · `remove_radial_mean` · DFT(버그 판본·수정 판본 둘 다) ·
`ssm.target_frames=5` · 고도 보정(척도 축 전체) · `slam_loop_robust_c` 양방향 ·
`nssm.min_st_sep`. **채택 config 는 배치 1 종료 시점과 동일하다** — 밤 결과는
"이미 국소 최적에 있다" 는 것이고, 그게 8 개 축에서 독립적으로 확인됐다.

산출: 커밋 4 건(코드 1 · finding 3), finding/039~042.

### 다음 세션에 남은 것

**미탐색 백엔드 손잡이** — 루프 후보 선정 기준, NSSM top-N, ICP fitness 게이트,
프라이어 공분산. 압축을 다른 기제로 움직여도 목표는 압축 감소가 아니라 오차 감소다.

**사람 결정 대기 2 건** — (1) 백엔드 축을 계속할지, (2) 열린 PR 머지
(slam #22~#27, sim #28/#29/#31, meta #17/#15).

---

## 2026-09-05 아침 — 결과 시각화에서 새 축이 하나 열렸다

밤 큐가 끝난 뒤 사람이 "RViz 로 결과를 보자" 고 해서 채택 config 를 한 번 더
재생했다(`viz-base_260905_065809`, `RVIZ=true bash run_replay.sh viz-base shallow`).
**지표만 보던 때는 안 보이던 것이 그림에서 보였다** — `finding/043`.

### 오차 이방성 (n=1, 재현 필요)

| 축 | GT 폭 | SLAM 폭 | 차이 |
|:--|--:|--:|--:|
| North (다리 간 진행) | 30.12 m | 26.17 m | **−13.1%** |
| East (다리 방향) | 30.16 m | 31.47 m | **+4.3%** |

북단은 GT 15.02 대 SLAM 14.97 로 맞고 남단이 −15.11 대 −11.20 이다. **다리를 달릴
때가 아니라 회전해서 다음 다리로 넘어갈 때 약 1 m 씩 잃는다.** 성김 아티팩트는
기각했다(GT 를 같은 353 점으로 솎아도 길이 −0.1%).

`len_ratio` 0.922 는 North −7.6% 와 East +3.9% 를 섞어 지운 값이다 — "궤적이 균일하게
수축한다" 는 그림이 틀렸다는 뜻이고, finding/042 에 등방 가정 한계를 보강해 두었다.

### 기준선 4번째 반복

2D 3.010 · ATE 2.780 · len_ratio 0.924 · DR 0.00% · ICP 352/352 · pcm 277 ·
featF 10900. 기준선 대역이 위로 넓어지지만 **finding/042 의 `c=8.0` ATE 완전분리는
유지된다**(c8 최소 2.889 > 새 최대 2.780).

### 이 배치에서 추가된 도구·환경

- `experiments/slam-tilt30/plot_traj.py` — 녹화한 `slam/traj`(PointCloud2, 누적) ·
  `actual_trajectory`(Path)에서 겹침 그림. **`rosbag2_py` 대신 sqlite 직접 읽기** —
  녹화가 끝나기 전에도(metadata.yaml 없고 WAL 열린 상태) 읽힌다.
- 화면 캡처 도구가 없어 `pip install --no-deps mss` (10.2.0) 를 넣었다. freeze diff
  한 줄, numpy·pytest 핀 영향 없음. `mss.MSS(display=':0')` 로 캡처한다.
- ⚠️ **런 디렉터리에는 궤적 좌표가 없다.** 누적기가 `err` 만 찍고 위치를 안 남기므로,
  그림이 필요하면 재생을 다시 돌리면서 두 토픽을 같이 녹화해야 한다.

### 다음 세션 첫 일감

이방성 3 반복 재현. 재현되면 회전 구간의 키프레임 선정과 NSSM 후보 선정.
FFT 앞단은 8 개 축으로 소진됐다.

---

# 인계 2026-09-05 오전 — 이방성 기각, 판정 절차 결함, 압축의 층별 귀속

⚠️ **이 절이 최신이다.** 위 「인계 2026-09-04 밤」의 8 축 기각 표는 유효하나,
그 중 2 건의 *근거*가 아래에서 무효화됐다(결론은 불변).

## 확정 3 건 (finding/044·045, 코드 `13efe5f`)

**1. 오차 이방성은 없다** (`finding/044`, `finding/043` 기각). North 폭 차이가
3 반복에서 −13.1% / +7.5% / −10.8% 로 부호가 뒤집힌다. 폭은 양 끝점의 함수라
횡드리프트를 압축과 못 가른다. **"회전마다 1 m 손실" 은 근거가 없다.**

재현되는 것은 **몸체 전진축 압축 0.86~0.88** 이고 다리(0.857~0.892)와
회전(0.839~0.857)이 같다 — 회전 구간 키프레임·NSSM 후보 가설은 표적을 잃었다.

**2. 압축의 층별 귀속** (같은 finding). FFT 시드 **0.943**(34 런 전부
0.940~0.946, 런·설정 무관 상수) → ICP **+0.006**(무효과) → 그래프층 0.92~0.98
(루프 설정에 단조: nssm off 1.000 · c=1.0 0.989 · c=8.0 0.886~0.907).
ICP 순 기여는 0 이고, 압축은 **시드 상수와 루프 인자** 두 곳에서 나온다.

**3. 판정 절차에 결함이 있었다** (`finding/045`). 채택 config 8 반복의
ATE 대역이 **2.325~4.180 (1.80 배)** 로 밤 배치가 쓴 대역(2.325~2.670)의 4 배다.
처리량(featF 10,695~10,990 전부 건강)·커밋 어느 쪽도 원인이 아니고
(`e58c9e0d` 는 `dft_refinement_enable: false` 가드 안 죽은 코드) **날짜로
완전분리**된다(09-04 세 런 2.33/2.67/2.33 대 09-05 다섯 런 2.78~4.18).

→ **두 팔을 다른 시간창에 돌리면 config 없이도 완전분리가 나온다.**

재판정으로 `slam_loop_robust_c=8.0` 과 `dft_refinement_enable` 의 완전분리
악화가 **겹침**이 됐다. 방향이 기각→**판정불가**라 채택 config 는 불변이고,
`keyframe_translation` 1.5/2.0 의 개선 완전분리는 살아남는다.
`finding/042`·`039` 를 배너·frontmatter·summary 세 층에서 정정했다.

## 절차 변경 — 대조군은 같은 큐 안에 인터리브한다

    base, arm, base, arm, base, arm      (runlist 큐 한 개, 런 수 동일)

시간 교란이 공통 모드로 빠진다. **n=3 완전분리는 이 형태로 얻은 것만
p=0.05 로 읽는다.** 다른 시간창의 기준선과 견준 완전분리는 근거가 아니다.

## 새 계측 (코드 `13efe5f`, slam `exp/tilt30-localization`)

| 무엇 | 어디 |
|:--|:--|
| `[INSTR] scale … seed_err icp_err rej ex ey` | 순차 ICP 의 **진실 대비 벡터** 오차와 몸체 성분 |
| `[INSTR] loop src tgt gt init est move seed_err icp_err ex ey sx sy cxx cyy` | 루프폐합 인자를 DR 상대포즈와 대조 (PCM **이전**) |
| `ssm.max_icp_move` | ICP 가 시드에서 이 거리보다 멀면 시드로 되돌림. 기본 0.0 = off |
| `icp_move_rej=` | 그 게이트 발동 횟수 (`[INSTR] counters`) |

도구: `experiments/slam-tilt30/aniso.py`(폭·구간·몸체분해) ·
`stepdiag.py`(층별) · `loopdiag.py`(루프 인자).

## 루프 인자가 압축을 확정한다 (`finding/046`, 6 런 전수)

| 양 | base ×3 | gate ×3 |
|:--|:--|:--|
| 시드 / GT | 0.883 · 0.881 · 0.843 | 0.824 · 0.816 · 0.869 |
| **ICP / 시드** | **1.0004 · 1.0022 · 0.9985** | **0.9973 · 0.9985 · 0.9976** |
| 전진축 편향 `sx` 중앙 (m) | −0.83 · −0.58 · −0.94 | −0.11 · −0.54 · −0.67 |

**루프 ICP 도 척도에 무효과다**(ICP/시드 0.997~1.002, 6 런). 루프 인자의 척도는
시드가 정하고 시드는 추정 포즈에서 오므로, **루프 인자는 궤적 압축을 교정하지
않고 그대로 확정한다.** 그런데 인자 공분산은 등방이다(cxx 0.39 / cyy 0.41) —
전진축 오차만 계통적으로 −0.5~−0.9 m 인데.

## 기각 — `ssm.max_icp_move=0.3` (`finding/046`)

인터리브 3 쌍에서 2D 2.652/3.132/3.424 대 3.320/3.266/2.507, ATE
2.350/2.680/3.509 대 3.463/3.275/2.271 로 **겹치고 쌍 내 부호도 갈린다.**
게이트는 22·22·23 회 확실히 발동했으므로 배선 실패가 아니라 효과 없음이다.
기본값 `0.0`(off) 유지.

⚠️ **인터리브가 실제로 막은 것**: 첫 두 쌍만 보면 게이트가 두 번 다 열세다.
밤 배치 방식이었다면 "악화" 로 읽었을 텐데 세 번째 쌍에서 부호가 뒤집힌다.

## 운영 함정 (이번에 당한 것)

- ⚠️ **녹화 중인 `trajrec/*.db3` 를 sqlite `mode=ro` 로도 열지 말 것.** 리더의
  공유 잠금이 rosbag2 recorder 를 `SQLite error (5): database is locked` 로
  죽인다 — `aniso-a` 가 57 kf 에서 끊겼다. `done` 파일이 생긴 뒤에만 연다.
  `aniso.py`·`stepdiag.py` docstring 에 적어 두었다.
- ⚠️ `localization.py` 는 **CRLF** 다. `pathlib.write_text` 로 패치하면 파일
  전체가 LF 로 바뀌어 diff 가 1,277 줄이 된다. 바이트로 되돌려야 한다.

## 스스로 저지른 것 (반복 금지)

첫 쌍만 보고 "게이트가 전진축 편향을 −0.83 → −0.11 로 지웠다" 고 적었으나
3 반복에서 재현되지 않았다(gate −0.11 · −0.54 · −0.67 대 base −0.83 · −0.58 ·
−0.94). **`finding/043` 과 같은 실수를 같은 세션에서 반복한 것** — 중간 런
하나의 수치를 기전 서술로 승격. 산포가 큰 계열에서 런 하나는 기전이 아니다.

## 이방화 축 — 검정 완료, 기각 (`finding/047`)

`slam_loop_along_sigma_scale=2.5` 를 인터리브 3 쌍으로 걸어 **무승부로 기각**했다
(구현 `f26cc5e`, 기본값 1.0 유지). ATE base 2.746 · 2.844 · 3.539 대 aniso
3.201 · 2.218 · 2.868 — 겹치고 1 쌍째는 base 가 이긴다. 6 런 전부 유효대역이고
DR 의존은 오히려 개선(`seed_dr` base 4·2·2 대 aniso 3·1·0).

카운터가 없는 축의 배선 확인법을 남긴다 — `yaml_set.py` 가 없는 키에 `KeyError`
로 exit 3 하므로 override 누락 런이 override 런으로 기록될 수 없고, 설치본
`install/local/lib/python3.10/dist-packages/…/factor_graph.py:263` 에
`inflate_loop_cov` 가 있으며, `scale=2.5` 와 루프 변위 2~3 m 로는 조기 반환
가드(`scale <= 1.0`·`n < 1e-3`) 가 걸릴 수 없다.

## 다음 축 (실행 중)

`min_pcm` **양방향** — 2(느슨) · 4(빡빡) · base 3팔 인터리브 9 런
(`pcmsweep.txt`, 11:52 착수). 최상위 ros 파라미터라 dot 경로는 `min_pcm` 이지
`nssm.min_pcm` 이 아니다(첫 시도가 `KeyError` 로 걸렸다). yaml 손잡이라 코드
변경·리빌드 오염이 없다.

근거 둘. (a) 오늘자 유효런 13 개에서 `len_ratio`↔ATE 상관이 **−0.730**(기저
8 런만이면 −0.839)로 어떤 카운터보다 강하고 `pcm_accepted` 가 `len_ratio` 와
+0.446 · ATE 와 −0.423 이다. (b) `verify_pcm` 의 Mahalanobis 게이트가
`ret_jk.cov` 한쪽만 쓰고 odometry 경로 공분산을 빼먹어 **명목 0.99 보다 엄격**
하다고 코드 주석이 자인한다(`factor_graph.py:365-372`).

**양방향인 이유** — `finding/043`·`046` 이 각각 "틀려 보이는 양을 옳은 방향으로
밀면 나빠진다" 를 저질렀다. 느슨(2) 만 걸면 그 함정의 세 번째다.

## 러너 함정 추가

- **러너는 매 런 `colcon build --merge-install --packages-select stonefish_slam`
  을 돈다**(`run_replay.sh:82`). 큐가 도는 동안 slam 소스를 건드리면 남은 런이
  오염된다. 코드 편집은 큐 종료 후에만.
- `Monitor` 는 기본 300 s 로 죽고 "timed out" 만 남긴다. 큐 생사는 알림이 아니라
  `ps -eo pid,etime,args | awk '/[r]un_replay.sh/'` 로 본다.
- ⚠️ **`hq post` 는 cwd 의 앵커로 간다.** `/workspace/experiments/…` 에서 부르면
  `/workspace/.hq`(정체된 별도 체크아웃) 에 쓰인다 — findings 039~047 이 사는
  워크트리 스토어가 아니다. 이번에 한 번 당했고 `/workspace/.hq/…/016-ate.md` 가
  미추적으로 남아 있다(권한 거부로 제거 못 함, 사람 처리 필요).

## 사람 결정 (2026-09-05 회신 반영)

1. **PR 머지** — 리뷰어 지정 후 보류(사용자 지시). 열린 11 건 그대로.
2. **push** — 완료. meta `7e6dda8`, slam `13efe5f`.
3. **`data/bags/.stereo_probe_tmp/bag.db3` 18 GB** — 삭제 완료(`.zstd` 원본 무사).
