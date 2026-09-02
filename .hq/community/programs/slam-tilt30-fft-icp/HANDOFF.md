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
