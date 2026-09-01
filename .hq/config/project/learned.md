# 관찰 로그 (learned.md)

운영 중 쌓이는 관찰을 적는 곳. 여기 있는 항목은 **아직 규칙이 아닙니다** — `omp-learn`이 사람 승인 게이트를 거쳐 `rules.json`으로 승격할 때만 강제 규칙이 됩니다(heavy 채널). 가벼운 패턴/결정은 `wiki/`에 자동 누적됩니다(light 채널, 게이트 없음).

## init 시점 시드 관찰 (규칙화 보류 — 승격 후보)

- **모델 디렉토리 케이스 혼재** (2026-06-23): `data/models/<name>/`가 kebab-case(`vasa-the-hold`)와 단어 단수(`caighouse`)가 섞임 (9/13). 규칙화하기엔 혼재가 심함. 팀이 한쪽으로 통일하기로 하면 승격 후보.
- **`world_` 접두 서브패턴** (2026-06-23): `.scn` 31개 중 6개만 `world_` 접두 (6/31). 월드 씬에 `world_`를 의무화할지 결정되면 승격 후보.
- ~~**`stonefish` C++ 라이브러리 소스 부재** (2026-06-23)~~ — **2026-09-01 해소**: `vcs import`로 `src/stonefish` 클론 확인(워크트리 object_detection_to_2d_mapping), `rules.json`·`STRUCTURE.md`에 항목 추가 완료. (`/workspace` 본 체크아웃은 여전히 미클론 — install 산출물만으로 빌드 가능하므로 체크아웃별 선택 사항.)
