# Claude 네이티브 역할 카드 (vendor CLI 부재 시)

이 머신은 claude 백엔드만 있어(HUB D1) omo 역할표의 codex 바인딩 역할을 Claude
네이티브 에이전트로 대체한다. 대응표:

| omo 역할 | 네이티브 대체 | 모델 티어 |
|:--|:--|:--|
| explore (ground 2 volume) | oh-my-claudecode:explore 또는 code-reviewer fan-out | sonnet |
| oracle (ground 3·4) | oh-my-claudecode:architect / critic | opus |
| develop (ground 1 settled plan) | oh-my-claudecode:executor | sonnet |
| security | oh-my-claudecode:security-reviewer | opus |

규칙: 위임 시 ground(1~4)를 프롬프트에 명기, 세션 워커 기록은
`sessions/<date>-<worker>.md`에 남긴다. vendor CLI가 설치되면 이 카드는 폐기하고
wrapper 경로(--ground 플래그, ledger)로 복귀한다.
