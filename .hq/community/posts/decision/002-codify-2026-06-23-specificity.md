# codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산

- id: decision/002 · date: 2026-06-23 · author: wiki-form-conversion
- to: all
- subject: naming-rules-codify · supersedes: none
- topic: convention
- confidence: none · status: none
- verified: 2026-06-23
- summary: codify 2026-06-23 — 글롭 수정·약어 예외·specificity 재계산

audit이 잡은 결함을 정리한 codify 패스. 3개 변경 + 죽은 규칙 정리.

## 변경
- **naming[8] cpp_ros2 글롭**: `src/stonefish_ros2/{src,include}/*`(0매칭) → `src/**/stonefish_ros2/{src,include}/**/ROS2*.{cpp,h}`(10매칭). 실제 패키지가 `src/stonefish_sim/stonefish_ros2/`로 한 단계 깊고, ROS2* 파일은 그 안 `stonefish_ros2/` 서브디렉토리에 또 있었음. info 유지.
- **naming[5] config yaml 약어 예외**: regex에 `|[A-Z][A-Z0-9_]+` 추가. `TAM.yaml`(Thruster Allocation Matrix) 통과, `Hybrid.yaml` 같은 PascalCase는 계속 차단.
- **specificity 0.80 → 0.941**: §4 재계산.

## 중요 — 작업 중 디스크가 바뀜 (회귀 방지)
codify 진행 도중 사용자/린터가 rules.json·PROJECT.md·STRUCTURE.md를 직접 편집해 `stonefish_control_utils` 패키지 제거를 반영함(GWO·SMAC3 옵티마이저가 실제 게인 산출에 안 쓰여 제거). 이로 인해:
- rule-architect draft는 옛 입력(structure 9 + ignore 12) 기준이라, 그대로 쓰면 사용자가 방금 지운 optimizer 죽은 규칙 4개(structure 1 + ignore 3)를 되살리는 **회귀**가 됨.
- 그래서 draft를 그대로 안 쓰고, **현재 디스크 상태(structure 8 + ignore 9) 위에** 승인된 변경 3개만 얹음.
- specificity도 사용자가 GATE에서 고른 0.889(optimizer 포함 가정)가 아니라, optimizer 제거 반영한 **16/17 = 0.941**이 정직한 값. preset 항목은 `data` 1개만 남음.

**교훈**: 서브에이전트 draft와 디스크 현실이 어긋날 수 있음(긴 작업 중 외부 편집). 쓰기 직전 디스크를 다시 읽어 baseline을 잡고, 그 위에 승인 변경만 얹어야 회귀를 막는다.

## 관련
- 근거 audit: [[../work/audits/audit-2026-06-23-0720.json]]
- rollback: [[../work/versions/rules-v01-2026-06-23.json]]
- 다음: 재-audit으로 warn 0 / info 0 확인 권장.
## Comments
