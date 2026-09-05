# shallow bag 런의 정확도 지표는 러너 밖 프로세스에 의존하고 있었다

- id: finding/029 · date: 2026-09-04 · author: claude
- harness: omx · to: all
- subject: accuracy-metrics-silent-without-tf · supersedes: none
- topic: environment
- confidence: high · status: resolved
- verified: 2026-09-04 · keywords: tf, odom_tf_bridge, silent-failure, accuracy-monitor, shallow-bag, bringup-launch, run_replay
- summary: shallow bag 재생 런에 [ACC] 줄이 0건이었다 — 에러·경고 없이. 그 bag 은 bringup.launch.py 로 녹화돼 /tf 가 remap 됐고, 관측기의 GT lookup(world_ned -> bluerov2/base_link_frd)이 매번 실패해 모든 지표가 조기 return 뒤에 있다. 9/3 런에 지표가 있던 것은 그때 우연히 odom_tf_bridge 계열 프로세스가 같은 도메인에 떠 있었기 때문 — 런 설정은 안 바뀌었는데 그 프로세스가 정리되자 지표만 사라졌다. 처방 2건: 관측기가 20회 연속 lookup 실패를 경고 1회로 신고(af46ae8), 러너가 bag 이름이 아니라 ros2 bag info 로 /tf 유무를 보고 브리지를 띄우고 끝에 죽임. CLAUDE.md 의 'RViz 표시만 안 됩니다' 서술은 과소평가였다.

## 증상

`run_replay.sh <label> shallow` 로 돌린 런의 `slam.log` 에 `err_gt=` 로 시작하는
`[ACC]` 줄이 **한 줄도 없다.** 노드는 정상 기동한다:

```
[INFO] [slam_accuracy_monitor-3]: process started with pid [1696674]
```

에러도, 경고도, 트레이스백도 없다. 로그만 보면 노드를 아예 안 띄운 런과 구별되지 않는다.

## 기전

`_traj_cb` 는 GT 를 TF 에서 읽는다 — `lookup_transform(traj_frame, self.gt_frame)`.
`gt_frame` 은 파라미터가 비면 `f"{vehicle}/base_link_frd"` 로 정해진다
(`core/slam_accuracy_monitor.py:104-107`). 그 변환이 없으면 조기 `return` 이고,
**err_gt · ATE · drift · dist_total · path metric 이 전부 그 return 뒤에 있다.**

shallow bag 에는 `/tf` 가 없다. `bringup.launch.py` 로 녹화해 remap 됐기 때문이고
이건 `CLAUDE.md` 의 bag 표에도 적혀 있다 — 다만 거기엔 "RViz 표시만 안 됩니다" 로
적혀 있었다. 실제로는 **정확도 계측 전체가 같이 죽는다.**

```
$ ros2 run tf2_ros tf2_echo world_ned bluerov2/base_link_frd
Could not find a connection between 'world_ned' and 'bluerov2/base_link_frd'
because they are not part of the same tree. Tf has two or more unconnected trees.
```

## 왜 9/3 런에는 ACC 줄이 있었나

그때는 `odom_tf2.py`(뒤에 `tools/odom_tf_bridge.py` 로 정리)가 같은
`ROS_DOMAIN_ID=77` 에서 따로 돌고 있었다. 그 프로세스가 `world_ned →
bluerov2/base_link{,_frd}` 를 발행한다. 즉 **shallow 런의 정확도 지표는 러너 밖에서
우연히 살아 있던 프로세스에 의존하고 있었다.** 그 프로세스가 정리되자 지표가 조용히
사라졌다 — 런 설정은 한 글자도 안 바뀐 채로.

`finding/022`(BLAS 스레드) 와 같은 계열이다: **머신도 로그도 정상으로 보이는데
숫자만 없다.**

## 처방 2건

1. **관측기가 자기 침묵을 신고한다.** GT lookup 이 20 회 연속 실패하고 성공이 0 이면
   경고를 한 번 낸다(커밋 `af46ae8`). 조용한 실패가 조용하지 않게 되는 게 요점.
2. **러너가 bag *이름* 이 아니라 bag *내용* 으로 판정한다.**
   `ros2 bag info "$BAG" | grep -q 'Topic: /tf '` 가 실패하면
   `tools/odom_tf_bridge.py` 를 띄우고 런 끝에 죽인다. 이름으로 분기하면 다음
   `/tf` 없는 bag 에서 같은 함정이 그대로 재발한다.

⚠️ `KILLPAT` 는 이 브리지를 안 잡는다(패턴이 `$W/install/lib/stonefish_slam/` 와
launch 만 매칭). 러너가 PID 로 직접 죽인다.
## Comments
