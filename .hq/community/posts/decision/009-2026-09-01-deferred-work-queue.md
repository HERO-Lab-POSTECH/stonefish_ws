# Phase 2 이월 작업 큐 N1~N13 — "지금 당장에만 제외"의 실물 목록

- id: decision/009 · date: 2026-09-01 · author: claude(opus5, phase2-planner)
- to: all
- subject: phase2-deferred-queue · supersedes: none
- topic: decision
- confidence: high · status: needs-experiment
- verified: 2026-09-01 · keywords: backlog, deferred, tilt, god-method, instrumentation, slam, sim
- summary: Phase 2 계획이 이번 사이클에서 뺀 13개 작업의 정본 목록. 사용자가 "제외는 지금 당장만, 끝나면 곧바로 다음"이라는 조건으로 승인했으므로 이 목록은 백로그가 아니라 예약된 다음 사이클이다.

## 왜 이 파일이 있나

Phase 2 계획 문서는 `.sp/plans/2026-09-01-code-cleanup-and-bugfix.md`에 있고,
`.sp/`는 **gitignore 대상 스크래치**다(user-scope CLAUDE.md 정책). 제외 항목의 사유는
계획 §3에, 예약 목록은 §8에 있는데 그 파일이 사라지면 함께 사라진다.

HUB의 D9가 "제외는 즉시 후속 사이클로 예약"이라는 **약속**을 기록하지만 **무엇을**
예약했는지는 담지 못한다. 이 포스트가 그 목록의 추적되는 사본이다.

## 여는 조건별 3묶음

### A. 계측 결과가 여는 것 (GPU 머신 실측 직후)

| # | 작업 | 여는 조건 |
|:--|:--|:--|
| N1 | **틸트 처방 확정** — I11의 병진 비율 중앙값으로 실계수 확정 후, slam config 30°를 시뮬 실물 80°에 정합할지 시뮬 `.scn`을 내릴지 결정 | I11·I13 |
| N2 | **`ssm.enable` 결정** — "icp 0%"가 설정 원인임을 확정한 뒤 켤지 판단. 켜면 shgo·ICP 비용과 `publish_point_cloud` 블로킹 재발 여부 동시 관측 | I1~I3 |
| N3 | **PSR 게이트 도입**(문헌 U1) — `rot_peak`/`trans_peak` 분포로 임계값 캘리브레이션, `localization_fft.py:1052`의 `success: True` 하드코딩 제거 | I8 분포 |
| N4 | **SSM 공분산 복원**(문헌 U2 + LOC-4 + LOC-6) — `ssm.cov_samples`를 ROS 파라미터로 노출하고 FFT peak-curvature 공분산을 ICP factor noise model로 전달. 세 항목이 한 처방의 세 조각 | I9 상관 |
| N5 | **SLAM-H4 `odom_tf_bridge` QoS** — 실기 bag의 실제 QoS를 `ros2 topic info -v`로 확인 후 판단. 영향 범위는 SLAM이 아니라 RViz 시각화 | 실기 bag |

### B. 설계 결정이 여는 것 (계측 불필요)

| # | 작업 | 먼저 정할 것 |
|:--|:--|:--|
| N6 | **SLAM-H5·H6·H7 통합** — Python fallback의 `update_method` 미분기, `h_step` 팬아웃 부재, shadow semantics 3종 분기 | "C++ 동작이 정본"인지 확정. Phase 3이 남길 C++ 동결 테스트가 출발점 |
| N7 | **god-method 분해** — `slam.py::slam_callback_integrated` 257줄 · `mapping_3d.py::__init__` 268줄 · sim `path_following_node.py::__init__` 199줄 · `mapping_2d.py::_accumulate_keyframe_into_map` 153줄 · `localization_fft.py`의 3개(101~138줄) | 특성화(수치 골든) 테스트 선작성 — **이것이 작업의 대부분** |
| N8 | **SSM/NSSM ICP 파이프라인 중복 통합** — `slam.py`의 근사 중복 ~100줄 × 2 | N7의 특성화 테스트 |
| N9 | **`polar_to_cartesian` 남은 2벌 통합** — `localization_fft`(radial cos 투영) vs `mapping_2d`(x축만 스케일). 수학이 다르므로 통합은 어느 쪽이 옳은지 정해야 가능 | **N1** |
| N10 | **SIM-M2 `INS.msg` `pose_variance`** 상시 0 — 채울지 없앨지 | 크로스 repo PR 상호 링크(`CONTRIBUTING.md` §5) |
| N11 | **SIM-M7 position 모드 `vel_ff` dead path** | owner 채택 결정 (sim `P4_FLAGS.md` 기존 항목) |
| N14 | **standalone 노드의 non-sonar 기본값 drift** — `mapping_2d.intensity_threshold` 50 vs `mapping.yaml:11`의 10, `mapping_3d.map_3d_voxel_size` 0.2 vs `mapping.yaml:16`의 0.3 | 없음(P1-13과 동일한 성격의 기계적 정합). **Phase 3 `fix/map-and-metrics` 적대 검증(2026-09-01, agy)에서 새로 발견** — P1-13의 범위가 `sonar.*`라 그 PR에서 제외했다. `test_standalone_node_defaults.py`를 `mapping_2d.*`·`mapping_3d.*`까지 확장하면 같은 게이트로 잡힌다 |
| N15 | **`_legacy` 로봇 정의의 mesh 자산 누락** — `data/robots/_legacy/girona500/girona500.scn` 16건, `_legacy/sonobot/sonobot.scn` 14건의 `<mesh filename=...>` 이 실재하지 않는다. 자산을 복원할지 `_legacy/` 를 통째로 은퇴시킬지 결정 | 없음(자산 보유 여부 확인이 선행). **Phase 3 `fix/scenario-and-guards` 적대 검증(2026-09-01, agy)에서 새로 발견** — 어떤 시나리오도 `_legacy` 를 include 하지 않아 현재 영향은 0이고(README 2곳의 서술이 유일한 참조), 그래서 그 PR의 `test_scenario_includes_resolve.py` 는 `<include file=...>` 만 보고 `<mesh filename=...>` 은 보지 않는다. 결정이 나면 같은 게이트를 mesh 까지 확장할 수 있다 |


### C. DR 재배선과 함께

| # | 작업 | 비고 |
|:--|:--|:--|
| N12 | **SLAM-H2** `dead_reckoning.py:232` — `rotation_flat`(roll/pitch 보정)을 계산해 놓고 안 쓰는 yaw-only 적분 | 현재 `/dead_reck/*` 구독자 0, `slam.launch.py`가 이 노드를 안 띄운다. 재배선 작업의 일부로 처리 |
| N13 | **SLAM-H3** `dead_reckoning.py:281` — Path/keyframes 무제한 성장 + 매 콜백 전체 재발행 | 누수라 재배선 **전에** 반드시. slam `P4_FLAGS.md`에 sign-off 항목 등재 |

## 승인 조건 (위반 금지)

사용자는 제외를 **조건부로** 승인했다 — "제외 항목들은 전부 승인하는 대신 모든 작업이
끝나면 그 다음으로 진행하는거야. 지금 당장에만 제외하는걸로"(2026-09-01 원문).

따라서 Phase 3 완료 판정에 **이 목록의 등재 확인**이 항목으로 들어간다. N1~N13을
어딘가에 등재하지 않고 사이클을 닫는 것은 승인 조건 위반이다.
