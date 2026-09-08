# 기준선 없는 큐가 둘 있다 — ssm.target_frames=5 는 최고 후보이지만 기본값 대비 개선이 측정된 적이 없다

- id: finding/059 · date: 2026-09-06 · author: claude opus5 exp-run
- harness: omo · to: all
- subject: baseline-less-queues · supersedes: none
- topic: technique
- confidence: medium · status: none
- verified: none
- summary: '가장 성능 좋은 설정' 을 물어 설정별 중앙값을 냈더니 ssm.target_frames=5 가 1 위(2D 중앙 2.141, 전체 최고 단일 런 1.970)였다. 그러나 그 근거로 쓴 기본값 중앙 3.000 은 전 기간 62 런을 모은 값이라 큐 횡단 비교이고 finding/045·051 로 무효다. 큐 파일 전수 감사 결과 queue2(12 런)·queue4(7 런)에 기준선 팔이 0 개 — 총 19 런이 설계상 판정 불가다. 같은 큐 안 팔 비교로는 ssm.target_frames=5 가 네 팔 중 1 위가 맞지만(2.141 vs 2.598~3.170), 기본값 대비 개선폭은 미측정이다. runlist.sh 가 기준선 없는 큐를 조용히 돌리는 것이 원인. 덧붙여 TRAJREC 없이 돈 런은 궤적이 어디에도 안 남아 전체 1·2 위를 rviz 로 다시 볼 수 없다.

## 발단 — "가장 성능 좋은 알고리즘을 보여달라"

사용자가 채택 설정 말고 최고 성능 설정을 rviz 로 보자고 했다. 설정별로 묶어
중앙값을 내니 `ssm.target_frames=5` 가 1 위였고, 세션은 그것을 **"최고"라고 단정한 뒤**
근거를 확인했다. 확인 결과 그 비교는 이 프로그램이 무효로 규정한 형태였다.

## 이 프로그램에 기준선 없는 큐가 둘 있다

[FINDING] `queue2.txt`(12 런)와 `queue4.txt`(7 런)에 기준선 팔이 **0 개**다. 총 19 런이
자기 큐 안에서 기본값과 비교할 수 없다.
[EVIDENCE] 큐 파일 전수 감사 — 두 번째 필드(YAML_SET)가 빈 줄의 개수:

| 큐 | 런 | 기준선 팔 |
|:--|--:|--:|
| aniso · drift · pcmlog | 4 · 6 · 3 | 4 · 6 · 3 |
| interleave · loopaniso · pcm5 · pcm5b · pcmsweep · sep | 6~9 | 3 |
| pcm5c | 16 | 8 |
| **queue2** | **12** | **0** |
| **queue4** | **7** | **0** |

[CONFIDENCE: HIGH]

`queue2` 는 4 팔(`n8band` · `n4sep8` · `n7dft` · `n5tgt5`) × 3 런이고 기준선이 없다.
`queue4` 는 3 팔(`n4sep8` 추가분 · `n13rc1` · `n14rc8`)이고 역시 없다.

`finding/045`·`051` 은 큐를 가로지르는 비교를 무효로 규정한다. 기준선이 큐 안에 없으면
비교 대상이 다른 날 다른 큐의 런일 수밖에 없으므로, **기준선 없는 큐는 설계상 판정 불가다.**

## `ssm.target_frames=5` — 가장 유망하지만 미검증

[FINDING] `queue2` 네 팔 중 `ssm.target_frames=5` 가 2D 로 가장 좋고, 이 프로그램 전체
최고 단일 런(2D 1.970)도 이 설정이 냈다. 그러나 기본값과의 비교는 한 번도 유효하게
측정된 적이 없다.
[EVIDENCE] 같은 큐 안 팔별 비교(`feat_frames >= 10175` 게이트 통과분만):

| 팔 | n | 2D 중앙 | ATE 중앙 | 2D 최소 |
|:--|--:|--:|--:|--:|
| `ssm.target_frames=5` | 3 | **2.141** | 2.395 | **1.970** |
| `nssm.min_st_sep=8` | 2 | 2.598 | 2.513 | 2.531 |
| `fft…remove_radial_mean=true` | 3 | 2.774 | 2.730 | 2.473 |
| `fft…dft_refinement_enable=true` | 3 | 3.170 | 2.607 | 2.917 |

(`n4sep8-a` 는 featF 8090 으로 게이트 미달이라 제외.)
[CONFIDENCE: HIGH — 팔 간 순서는 같은 큐 안이라 유효. 기본값 대비 개선폭은 측정 없음.]

기전은 명확하다. `ssm.target_frames` 는 SSM(순차 스캔정합) ICP 의 **타깃 점군을 만드는
최근 키프레임 개수**다(`core/localization.py:78` 기본 3, `:396`
`range(self.fg.current_key)[-self.ssm_params.target_frames:]`). 5 로 올리면 얇은 고리 대신
진행방향으로 늘어난 국소 지도에 정합한다 — `queue2.txt` 주석의 Q3 가 그 의도다.

## 세션이 한 단정과 그 정정

[FINDING] 세션은 "`ssm.target_frames=5` 가 최고"라고 사용자에게 단정했다. 근거로 쓴
"기본값 중앙 3.000"은 전 기간 62 런을 모은 값이라 큐를 가로지르는 비교이고, 무효다.
[EVIDENCE] 그 62 런은 여러 날 여러 큐에서 왔다. `finding/051` 은 같은 설정의 표류가
블록 단위로 움직인다는 것을, `finding/055` 는 런 간 산포가 2D sd 0.828 m 임을 잰다.
설정 효과(약 0.86 m 주장)와 같은 크기라 구별되지 않는다.
[CONFIDENCE: HIGH]

정정된 진술: **`ssm.target_frames=5` 는 관측된 것 중 2D 가 가장 좋은 설정이되, 기본값
대비 개선은 미측정이다.** 채택 후보이지 채택 근거가 아니다.

같은 흠이 `keyframe_translation` 1.5/2.0(`n2kf15`·`n3kf20`)에도 있다 — 기준선 없는
배치에서 나왔다. 게다가 2.0 은 DR 폴백 8.05 % 라 사용자 제약 2 를 위반하므로 그 ATE
1.446 은 애초에 채택 대상이 아니다.

## 하네스에 넣을 규칙

[FINDING] 큐 파일에 기준선 팔이 없으면 그 큐의 런은 사후에 구제할 수 없다.
[EVIDENCE] 위 19 런이 그 상태이고, 유일한 구제는 같은 설정을 기준선과 함께 다시 도는 것
(런당 11 분)이다.
[CONFIDENCE: HIGH]

`runlist.sh` 가 큐를 읽을 때 기준선 팔(YAML_SET 이 빈 줄)이 하나도 없으면 경고하거나
거부해야 한다. 지금은 조용히 돈다. 이건 코드 변경이라 별도 승인 대상이다.

## 부수 관측 — 최고 런은 다시 볼 수 없다

`TRAJREC=1` 없이 돈 런은 궤적 좌표가 어디에도 안 남는다(로그에도 없다). 전체 1·2 위
(`n5tgt5-c` 2D 1.970, `b13pcm5` 2D 2.013)가 그 상태라 rviz 로 띄울 수 없고, 재실행해도
런 간 산포 sd 0.828 m 때문에 같은 궤적이 안 나온다. 오늘 사용자 요청이 이 벽에 부딪혔다.
`trajrec` 는 4 토픽 133 MB 이고 `finding/020` 실측으로 처리량 축을 안 건드리므로,
**앞으로 모든 판정 런에 기본으로 켜는 것을 검토**할 만하다(디스크 비용은 런당 133 MB).
## Comments
- (2026-09-06, claude opus5 exp-run) ssm.target_frames=5 의 4 번째 런(demo-best_260906_155216, RVIZ=1 TRAJREC=1). 2D 2.295 · ATE 2.108 · len_r 0.9316 · featF 10765 · DR 0.86 %(seed_fft/seed_dr 347/3) · factor_odom 0 · icp_rate 1.0 · nssm 336->318->pcm 250 · reject_pos 16 에서 warp 13 구제. 계열은 이제 2D 1.970/2.141/2.543/2.295 로 중앙 2.218 이고, 앞선 3 런 중앙 2.141 과의 차이는 런 간 산포(sd 0.828 m) 안쪽이라 계열 성적을 바꾸지 않는다. 이 런은 기준선 팔 없이 단독으로 돌았으므로 여전히 기본값 대비 개선의 증거가 아니다 — 다만 trajrec 를 켜서 이 계열 중 유일하게 궤적이 저장된 런이고(127 MB), showtraj.py 로 언제든 rviz 에 다시 띄울 수 있다. rviz 를 켜고 돌았으므로 처리량은 finding/020 대로 약간 손해를 봤을 수 있다(featF 10765, 게이트 10175 통과).
