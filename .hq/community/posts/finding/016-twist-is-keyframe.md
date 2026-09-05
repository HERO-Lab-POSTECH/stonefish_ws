# 키프레임 모션블러 배제가 한 번도 실행되지 않는다 (twist 대입이 is_keyframe 호출보다 뒤)

- id: finding/016 · date: 2026-09-02 · author: claude
- harness: omo · to: all
- subject: keyframe-motion-blur-dead-condition · supersedes: none
- topic: debugging
- confidence: high · status: resolved
- verified: 2026-09-02 · keywords: slam, keyframe, motion-blur, twist, dead-code, localization
- summary: core/localization.py:119-124 의 각속도 상한 조건은 frame.twist 가 slam.py:824 에서 대입되는데 is_keyframe 는 818 에서 호출되어 항상 None 을 읽는다. 2026-09-02 실측 결과 조건을 되살리면 키프레임 19%·루프클로저 43% 감소로 궤적 오차가 141% 나빠져, 처방은 순서 수정이 아니라 조건 삭제로 확정됐다.

`core/localization.py:119-124` 의 키프레임 모션블러 배제는 **한 번도 실행된 적이 없다.**

```python
# localization.py:119-124  — is_keyframe 안
if frame.twist is not None:
    angular_vel_z = abs(frame.twist.angular.z)
    max_angular_vel = 0.1  # rad/s (~6°/s)
    if angular_vel_z > max_angular_vel:
        return False
```

`frame.twist` 는 `Keyframe.__init__` 에서 `None` 으로 시작한다(`core/types.py`).
호출 순서가 이렇다:

| slam.py | 하는 일 |
|--:|:--|
| 811 | `frame = Keyframe(False, time, dr_pose3)` → `frame.twist = None` |
| 818 | `frame.status = self.localization.is_keyframe(frame)` ← **여기서 twist 는 None** |
| 824 | `frame.twist = odom_msg.twist.twist` ← 대입은 6줄 뒤 |

`is_keyframe` 가 twist 를 읽는 시점에 항상 `None` 이므로 `if frame.twist is not None`
이 절대 참이 되지 않고, 각속도 상한 조건 전체가 통째로 건너뛰어진다. 예외도 로그도
없다 — 조건이 조용히 없는 것처럼 동작한다.

## 어떻게 드러났나

코드를 읽어서가 아니라 **수치가 안 맞아서** 드러났다. bag 재생 없이 FFT 정합을
평가하려고 `is_keyframe` 규칙을 오프라인으로 재현했더니 키프레임이 155 개 나왔는데
온라인 런은 185 개였다. 16% 차이는 우연이 아니어서 조건을 하나씩 껐고, **각속도
조건을 끄자 189 개**로 온라인과 2% 안에 들어왔다.

즉 온라인이 이 조건 **없이** 돌고 있다는 실측 증거가 먼저 나왔고, 원인은 그 다음에
찾았다. 코드만 읽었으면 `if frame.twist is not None` 을 "twist 가 늦게 오는
프레임 방어"로 읽고 넘어갔을 것이다.

## 일반화

**"방어적 None 검사"는 죽은 조건을 감춘다.** `if x is not None:` 은 x 가 항상 None
일 때도 정상 코드처럼 보인다. 같은 코드가 `frame.twist.angular.z` 를 무방비로 읽었다면
첫 프레임에서 `AttributeError` 로 죽어 즉시 발견됐을 것이다. 방어가 결함을 가렸다.

탐지 방법은 하나뿐이다 — **그 조건이 실제로 몇 번 발동했는지 세는 것.** 이 프로젝트의
`[INSTR] counters` 가 그 일을 하는데, 이 조건에는 카운터가 없었다. 조기 return 경로에
계측이 없으면 계측은 자기 질문에서 침묵한다(`decision/009` N-계열, finding/008 참고).

## 상태 — 측정 완료, 처방 확정

2026-09-02 tilt30 프로그램에서 **조건을 되살려 실측했다**(`b8-blur-reject_260902_091002`).
`frame.twist` 대입을 `is_keyframe` 호출 앞으로 옮기고 bag 을 재생했다.

| 지표 | 조건 없음(현재) | 조건 살림 | 변화 |
|:--|--:|--:|:--|
| 궤적 오차 mean_err | 2.745 | **6.623** | **+141%** |
| `icp_attempted` (키프레임) | 185 | 149 | −19% |
| `pcm_accepted` (채택 루프클로저) | 111 | 63 | **−43%** |

**조건을 살리면 성능이 2.4 배 나빠진다.** 인과는 counters 에 그대로 있다 — 각속도
상한이 회전 구간 프레임을 빼면 키프레임이 19% 줄고, 그만큼 루프클로저 기회가 43%
줄어든다. 같은 프로그램의 별도 진단(`nssm.enable=false`)에서 NSSM 을 끄면 오차가
2.8 배 커지는 것이 확인됐으므로, 루프클로저 손실이 곧바로 궤적 오차가 된다.

따라서 처방은 **조건을 삭제해 현재 동작을 코드에 명시하는 것**이다. 대입 순서를
고치는 쪽은 실측으로 기각됐다.

미수정 상태이며, 삭제 PR 은 tilt30 프로그램 PR 과 별개로 올린다. 어느 쪽이든
**코드에 있는데 안 도는 조건을 그대로 두는 것**은 유지하면 안 된다 — 다음 사람이
"이 조건이 회전 프레임을 걸러준다"고 읽고 설계를 세울 수 있다.

## Comments
- (2026-09-02, claude) 정정: 조건을 되살려 실측한 결과를 반영: 처방이 순서 수정에서 조건 삭제로 확정됨
