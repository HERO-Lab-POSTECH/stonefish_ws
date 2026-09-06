# min_pcm 축의 pooled 단조성과 pcm5 검정력 부족 — '벽은 4' 는 6 쌍으로 성립하지 않는다

- id: finding/054 · date: 2026-09-06 · author: omx
- harness: omo · to: all
- subject: min_pcm-축의-pooled-단조성과-pcm5-검정력-부족-벽은-4-는-6-쌍으로-성립하지-않는다 · supersedes: none
- topic: decision
- confidence: high · status: needs-experiment
- verified: none · keywords: tilt30, min-pcm, pcm5, power, interleave, 4th-pair, loop-class
- summary: analysis `day-260905/diagnose-20260906-060611` §2·§5. (1) 계열 중앙값이 pcm2→3→4→5 로 단조: 2D 2.860/3.010/2.646/2.333 · ATE 2.82

analysis `day-260905/diagnose-20260906-060611` §2·§5. (1) 계열 중앙값이 pcm2→3→4→5 로 단조: 2D 2.860/3.010/2.646/2.333 · ATE 2.822/2.805/2.558/2.293 · len_r 0.887/0.898/0.917/0.929 · pcm_accepted 303/283/240/193. 비-pcm 오버라이드 없는 38 런 pooled 에서 len_r~pcm ρ = −0.615(p < 1e-4), ATE~pcm +0.535, 2D~pcm +0.505 인데 계열 안에서는 pcm3 ρ +0.155·pcm4 +0.059 로 0 — 개수가 아니라 min_pcm 이 제거하는 루프의 부류가 효과라는 추론(루프 단위 채택 로깅 전까지 MED, proposal next-20260906-062324 L1). (2) finding/049 의 pcm5 기각은 검정력 부족: 짝 차이 2D 평균 −0.155/중앙 −0.330/SD 0.467(Wilcoxon p 0.44), ATE −0.136/−0.253/0.380(p 0.31), 두 축 4/6 승. 0.30 m 효과·80 % 검정력에 13–19 쌍 필요, 6 쌍 실행 → '보이지 않았다' 가 지지되는 서술. pcm5 의 len_r 0.929 는 루프 없는 체인(0.929)과 같다. 재검정 proposal next-20260906-062325(L2, 8 블록 추가, n=14 부호검정 규칙은 사용자 확인 필요). (3) finding/048 의 pcm4 2D 완전분리는 vizbase/vizpcm4 4번째 쌍(+0.276)에서 깨지고 ATE(−0.080)·len_r 은 4/4 유지 — 채택 불변, 여유는 좁다.
## Comments
- (2026-09-06, claude opus5 exp-run) 2026-09-06 사용자 결정: L2(next-20260906-062325)에 한해 판정 규칙을 사전등록 부호검정으로 변경 승인. 규칙 = 2D·ATE 두 축 모두 14쌍 중 >=11승(부호검정 p=0.029) AND 짝 중앙 개선 <= -0.15 m AND seed_dr 짝 중앙 <= 0. 이 축에만 적용하며 다른 축의 n=3 양축 완전분리 규칙은 그대로다. 큐 실행 전에 등록했으므로 사후 기준 변경이 아니다.

- (2026-09-06, claude opus5 exp-run) finding/055 가 이 검정력 논지를 닫힌 축 전체로 일반화한다. n=3 두 축 완전분리 규칙의 검정력은 0.6 m 효과에서 8.5 %, 0.3 m 에서 3.9 % 라, pcm5 뿐 아니라 기각된 11 축 전부가 '기각' 이 아니라 '미증명' 이다.
