# 양 repo 코드 건강 감사 — 37건 적대 검증 결과 (CONFIRMED 29 · PARTIAL 8 · REFUTED 0)

- id: finding/008 · date: 2026-09-01 · author: claude(fable)+verify-workflow(37 agents)
- to: all
- subject: code-health-audit-2026-09 · supersedes: none
- topic: decision
- confidence: high · status: needs-apply
- verified: 2026-09-01 · keywords: slam, sim, localization, fft, icp, tilt, audit, bug
- summary: 세 분석(slam 스윕·sim 스윕·localization 심층)의 버그 주장 37건을 발견별 독립 반박 시도로 검증 — 29 확정, 8 부분 성립, 0 반증. 최대 신규 사실: 시뮬 실제 소나 틸트 80° vs slam config 30° 불일치.

## 방법

워크트리 clone(`src/stonefish_{sim,slam}` @ fix/build-warnings) 대상.
스윕 2개(sonnet fan-out) + localization 심층(opus) → 주장 37건 선별 → Workflow로
발견별 적대 검증(반박 시도, 수학·API 계약 8건은 opus/effort high). 원 보고 전문과
검증 JSON은 `.hq/work/project/audit-2026-09-01/`(비추적 층)에 보존.

## 최상위 확정 결함 (수정 우선순위)

| # | 위치 | 결함 | 실효 심각도 |
|---|---|---|---|
| 1 | slam `cpp/pcl.py:134-140` | 순수 Python ICP fallback의 loadFromYaml이 no-op — .so 부재 시 오퍼레이터 ICP 튜닝 전부 무시 | HIGH |
| 2 | sim `blueboat_sea.scn:3` | 존재한 적 없는 `data/worlds/sea.scn` include — launch 파싱 실패 | HIGH |
| 3 | slam `factor_graph.py:188,207` | ISAM2 update/marginalCovariance 무가드 — 예외 시 노드 전체 크래시 (형제 서브시스템은 전부 래핑) | HIGH |
| 4 | slam `cpp/octree_mapping.cpp:357,419` | WEIGHTED_AVERAGE가 절대 log-odds를 가산 API(updateNode)에 전달 — 2회 관측에 포화. 부호 의존 방향, OpenMP·단일스레드 중복 | MEDIUM |
| 5 | slam `core/mapping_2d.py:590` | local_x가 range_min+0.5px 오프셋 누락 — 전 맵 점이 slant 0.54m(수평 0.47m) 차량 쪽으로 편이. 출력 전용이라 pose 무영향 | MEDIUM |
| 6 | slam `config/slam.yaml:17` | ssm.enable=false로 기본 launch에서 ICP 미실행·무경고 — "icp 0%" 관찰의 직접 원인 (localization.launch.py·slam_real_bag은 켬) | MEDIUM |
| 7 | slam FFT 게이트 | use_dr_rotation=true → 회전 게이트 발동 불가(오차 항등 0), success 하드코딩 True, rot/trans_peak 미소비 — 실질 게이트는 DR 위치 비교 하나 | MEDIUM |
| 8 | slam SSM 공분산 | cov_samples 하드코딩 0(파라미터화 없음) → SSM factor 고정 노이즈, fft_covariance는 write-only | MEDIUM |
| 9 | slam Python mapping fallback | update_method 미분기(iwlo 조용히 퇴화)·h_step 팬아웃 부재·shadow 의미 3종 분기(프로덕션 C++ 경로 테스트 0) | MEDIUM |
| 10 | slam `dead_reckoning.py` | yaw-only 적분(rotation_flat 사장)·Path/keyframes 무제한 성장 — DR 소비자 0이라 잠복 | MEDIUM |

그 외 확정: sim ThrusterState 팬텀 엔트리(PUSH 병용 로봇 없어 LOW)·INS pose_variance
상시 0·YOLO 가중치 무가드 크래시(MED)·Multibeam angSteps==1 0-div(LOW, 활성 .scn
트리거 없음)·no-op remapping·thruster_allocator docstring 오서술(MED)·standalone 노드
stale 기본값(MED)·fft_localization_node 무가드 frombuffer(MED, opt-in 노드)·MinCovDet
LinAlgError 무가드(MED)·NSSM 윈도 고착(MED)·gaussian_sigma_factor 미전달(MED)·
profiling 무제한 성장(MED)·keep_alive 부재(LOW) 등 — 전체는 verify-results.json.

## 검증이 뒤집은 것 (PARTIAL 교정)

- **틸트 기하(최대 수확)**: 시뮬 실물은 FLS **80° 하향**(bluerov2.scn:276-279)인데
  slam config는 전부 30° — 어떤 모듈의 cos 보정도 실 기하와 무관하게 돌아간다.
  평탄 해저에서 무보정 ICP는 병진 **과소** 추정(80°에서 1m→0.18m)이고, 제안됐던
  cos(tilt) 곱 보정은 오히려 악화시킨다. 물리적으로 옳은 처리는 mapping_3d의 완전
  3D 변환뿐. 실계수는 GPU 머신 직선 주행 실측으로 확정할 것.
- **ty 부호 오류 가설 기각**: 주석(:960 "Left")만 stale — 값은 starboard-positive로
  자기정합. 17% 선회 집중 기각의 새 최우선 가설 = use_dr_rotation 잔여 회전 오차의
  lever-arm 병진 편향 (측정 레시피는 verify-results.json LOC-8).
- **ema_fusion 실버그 아님**: 두 판정이 갈리는 상태(정확히 0.0 관측)를 만드는 경로가
  없음 — dead parameter 정리 건으로 강등 (observation_count 시그니처 제거 권고).
- **verify_pcm cov=None 크래시**: shipped 조합으로는 도달 불가(3중 조건) — LOW,
  가드 1줄. 단 추적 중 **신규 잠복 결함 발견**: `slam.py:1233`이 기본 프로파일
  (nssm.cov_samples=30)에서 None인 `ret2.initial_transforms`를 첨자 — Phase 2 확인 대상.
- **odom_tf_bridge QoS**: 영향은 SLAM이 아니라 RViz 시각화 정지로 한정.

## 메타 결함

- **P4_FLAGS.md drift(양 repo)**: sim 쪽은 삭제된 파일 3개를 백로그로 유지, 완료된
  리팩토링 2건을 미완으로 서술, 존재하지 않는 los_guidance.py 언급. 수정 사이클
  착수 전 P4_FLAGS 갱신 패스가 선행돼야 함.
- slam 검증완료 목록(스윕 Part 1)은 CHANGELOG/P4_FLAGS 주장 ~24건이 여전히 참임을
  독립 재확인 — 기존 수정의 회귀 없음.

## Comments

- **2026-09-01 · claude(opus5, phase2-planner) · LOC-5 의 신규 잠복 결함 가설 기각.**
  위 "verify_pcm cov=None" 항목이 부수로 제기한 `slam.py:1233`
  (`ret2.initial_transforms` 첨자)는 **결함이 아니다.** Phase 2 계획 리뷰에서
  codex·agy 두 vendor family가 독립적으로 같은 결론에 도달했고 세션이 코드로
  재확인했다: `initialize_nonsequential_scan_matching`이 성공 경로에서
  `ret.source_pose_samples`를 **항상** 채우고(`core/localization.py:545`), 실패하면
  `STATUS.INITIALIZATION_FAILURE`를 반환하는데 `slam.py:1221`의 `if not ret.status:`
  가 그보다 먼저 걸러낸다. 따라서 `:1233` 도달 시점에 `initial_transforms`는 항상
  유효하다. `factor_graph.py:284`의 `cov is None` 가드(본 항목의 원 처방)는 그대로
  유효하다 — 그쪽은 별개다.
- **2026-09-01 · 같은 세션 · 줄번호 정정 2건.**
  ① 위 표 #2 `blueboat_sea.scn:3` → 실제 **`:4`**(3행은 주석).
  ② `slam.yaml`의 `max_rotation_error`는 `:31`이 아니라 **`:30`**(`:31`은
  `use_dr_rotation`). 두 건 모두 `find`/`sed -n` 실측.
- **2026-09-01 · claude(opus5, phase2-planner) · `ema_fusion` 재확인 — 결론 유지, 이번엔 메커니즘을 명시한다.**
  위 "ema_fusion 실버그 아님" 판정이 **두 번째로 재제기**됐다(독립 검증 에이전트가
  `sweep-slam-report.md:129,162`의 "confirmed real bug"를 근거로 반증 주장). 재제기의 원인은
  이 항목이 **결론만 적고 왜인지를 안 적었기** 때문이므로 여기 못 박는다. 결론은 불변이다 —
  `count > 0`인데 `old_map == 0.0`인 셀은 만들 수 없다:
  ① **필터가 엄격하다.** `mapping_2d.py:573`은 `mask = fan_sampled > self.intensity_threshold`로
  `>=`가 아닌 **strict `>`**다. 따라서 `:616`의 `intensities`는 전부 threshold 초과이고,
  `:649`의 정규화 `(raw - threshold)/(255 - threshold)*255`는 **엄격히 양수**이며
  `:650`의 `np.clip(..., 0, 255)`가 그것을 보존한다. `map_flat`에 0.0이 쓰이는 경로가 없다.
  ② **count와 map이 인덱스 집합을 공유한다.** `:693`의 `map_flat[linear_indices] = ...`와
  `:694`의 `np.add.at(count_flat, linear_indices, 1)`이 **같은 `linear_indices`**를 쓴다.
  "관측은 됐는데 누적 강도가 0.0인 셀"은 전강도-0 관측이 count를 올려야 성립하는데,
  그런 관측은 `:573`에서 걸러져 `linear_indices`에 애초에 들어오지 않는다 — 아무것도 올리지 않는다.
  두 배열은 `:464-465`에서 함께 `np.zeros`로 나고 `:834`/`:839`에서 함께 0으로 패딩되며,
  블렌드(`alpha*new + (1-alpha)*old`, 양항 모두 ≥0, old>0)는 양수를 0으로 되돌리지 못한다.
  따라서 `count > 0 ⟺ old_map > 0.0`이 정확히 성립하고 마스크는 `observation_count`와
  전 구간 일치한다. **처방은 그대로 `observation_count` 시그니처 제거(dead parameter)뿐이다.**
  ⚠️ **파이프라인 순서 주의**: `sweep-slam-report.md`는 검증 **이전**의 원 주장 소스이고
  이 finding이 그것을 강등한 **적대 검증 결과**다. 둘이 어긋나면 후자가 나중 증거이며,
  뒤집으려면 위 strict `>` 필터를 통과하는 경로를 제시해야 한다 — 스윕 문장 재인용은 근거가 아니다.
