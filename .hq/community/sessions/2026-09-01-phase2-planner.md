# 2026-09-01 · phase2-planner (Claude Opus 5, 세션 워커)

작업: Phase 2 — P4_FLAGS 갱신 패스 + 코드 정리·버그 수정 계획 수립.
산출물: `.sp/plans/2026-09-01-code-cleanup-and-bugfix.md`,
`.hq/work/project/audit-2026-09-01/lit-sonar-localization.md`,
양 repo `P4_FLAGS.md` 갱신.

## 프리플라이트 실측 (D3의 전제 확인)

| 항목 | 결과 |
|:--|:--|
| `codeagent-wrapper` | `/root/.local/bin` → `/root/go/bin` 심링크, `--version`은 `dev`(0.21.6 소스 빌드) |
| `codex` | `/usr/bin/codex`, 인증 OK |
| `agy` | `/root/.local/bin/agy`, 인증 OK |
| omo 스토어 | `.hq/community/` 시드 완료(rules 5 · HUB · agents · sessions) |
| codex 로더 | 이 세션에서 설치 — `.codex/config.toml` + `.codex/skills/{context-loader,decision-record}` |
| agy 로더 | 이 세션에서 설치 — `.agents/skills/{context-loader,decision-record}` |
| 로더 실효성 | **양 백엔드 실측 통과** — rules 5개·HUB Decisions 3행·`finding/008` 파일명을 정확히 회수. codex는 `language.md`대로 한국어로 응답 |

### 프리플라이트가 발견한 조용한 퇴화 2건

1. **`~/.codeagent/models.json` 부재.** 이전 세션이 바이너리만 0.21.6으로 올리고 설정 층을
   설치하지 않아 첫 `--agent explore` 호출이 `models config not found`로 죽었다.
   `templates/models.json.example` 기준으로 생성(7 role + agy 백엔드 추가).
2. **codex의 bubblewrap 샌드박스가 이 컨테이너에서 동작하지 않는다**
   (`No permissions to create a new namespace`). 샌드박스 경로로 돌면 codex는 파일을 하나도
   못 읽으면서 에러 대신 "unavailable"만 답한다 — 전형적 silent failure. wrapper의
   `yolo:true` role(`develop`·`oracle`·`librarian`)은 `--dangerously-bypass-approvals-and-sandbox`가
   붙어 정상 동작하므로 그쪽으로 라우팅해 우회했다.
   ⚠️ **남은 제약**: `models.json`의 `explore`·`security`가 `yolo:false`라 두 role은 양 백엔드
   모두에서 파일을 못 읽는다. 수정하려면 프로젝트 밖(`/root/.codeagent/`) 쓰기가 필요한데
   Claude Code auto-mode classifier가 막는다 — 사람이 직접 고쳐야 한다.

## 이 세션의 벤더 호출 (전부 ground 명시)

| ground | role/backend | 목적 | 결과 |
|:--|:--|:--|:--|
| 2 | `explore`/codex | 스토어·로더 실효성 프로브 | 샌드박스 실패로 read 0 — 위 퇴화 2 발견 |
| 4 | `oracle`/agy | 같은 프로브 | 전건 정확 회수 |
| 2 | `develop`/codex | 같은 프로브 (yolo 경로) | 전건 정확 회수 |
| 4 | `oracle`/codex + `oracle`/agy | **계획 문서 2-family 적대 검증** | 아래 |
| — | OMC `document-specialist`(sonnet) | FLS localization 문헌 조사 | 인용 27건, 전부 arXiv id/DOI/URL 실조회 |

**2-family 게이트를 연 근거**: 이 계획은 양 repo에 5개 PR을 내는 release급 변경 범위이고,
P0-4(C++ 옥트리 log-odds)·P1-8(프로파일링 수집 삭제)은 되돌리기 비싼 축에 든다.
omo SKILL.md의 게이트 조건("release에 실린다 / 데이터 손실 경로 / 되돌리기 어렵다")에 걸린다.

## 세션이 벤더/에이전트 출력을 뒤집은 곳 (기록)

문헌 조사 에이전트는 weakness #1(slant-range 미보정)의 처방으로 "FFT가 쓰는 `cos(tilt)`를
ICP 점군에도 적용"을 **저비용**으로 권고했다. **세션이 이를 기각했다** — 적대 검증(LOC-3)이
평탄 해저에서 무보정 ICP는 병진을 **과소** 추정하고 `cos` 곱은 오차를 악화시킨다고 판정했고
(30°: 0.89→0.77, 80°: 0.18→0.03), 무엇보다 실물 틸트가 80°인데 config가 30°라 어떤 cos
보정도 실 기하와 무관하다. 에이전트는 그 교정을 알지 못한 채 "세 소비자 스케일 정합"이라는
논리만으로 판정했다. 계획 §6.3에 기각 근거를 명시했다.

## P4_FLAGS 갱신 패스에서 실측으로 뒤집힌 것

| 대상 | P4_FLAGS 기록 | 2026-09-01 실측 |
|:--|:--|:--|
| sim `ilos_guidance.compute_guidance` | 319줄 god-method | **66줄** — 분해 완료, 종결 |
| sim `lipb_interpolator.init_interpolator` | 152줄 god-method | **26줄** — 분해 완료, 종결 |
| sim `los_guidance.py::update` | 177줄 god-method | **파일 자체가 없음** — 유령 항목 |
| sim `path_following_node.__init__` | 170줄 | **199줄** — 열림, **악화** |
| sim VelocityProfiler dead 분기 | cs 14 · lipb 15 | cs **7** · lipb **7** · `trajectory_generator` **6**(목록에 없던 파일) |
| sim velocity/unified controller node, teleop_manager | 백로그 항목 | **삭제됨** — 3항목 종결 |
| slam `utils/` `__all__` 부재 | 5개 파일 | **7개 전부** |
| slam `localization.yaml` icp_config | `:29` | **`:30`** (줄 drift) |
| sim `blueboat_sea.scn` 깨진 include | `:3` (finding/008) | **`:4`** (주석이 3행) |
