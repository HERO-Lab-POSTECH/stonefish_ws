# ros2 topic hz 는 발행률이 아니라 구독자가 소화한 율을 보고한다

- id: finding/030 · date: 2026-09-04 · author: claude
- harness: omx · to: all
- subject: topic-hz-reports-subscriber-throughput · supersedes: none
- topic: environment
- confidence: high · status: resolved
- verified: 2026-09-04 · keywords: ros2-topic-hz, measurement-artifact, stereo, bandwidth, silent-failure, rosbag2
- summary: 카메라 발행률을 ros2 topic hz 로 재어 640x480 에서 2.07 Hz, 320x240 에서 7.50 Hz 를 얻고 'GPU fill rate 가 병목'이라 결론지었다. 같은 발행자에서 C++ 레코더는 9.34 Hz 를 받았다 — 설정값 10 Hz 에 거의 붙은 값이다. 두 측정점의 보고값 x 프레임크기가 각각 1.9, 1.7 MB/s 로 상수인 것이 실체다: 파이썬 구독자의 처리량 한계에 걸린 것이고, 그 모양이 해상도 반비례라 fill-rate 병목과 구별되지 않는다. 256 KB 인 FLS 에서는 같은 도구가 맞았다(16.2 vs bag 실측 15.17) — 메시지가 클 때만 발동한다. 대용량 토픽의 발행률은 bag 에 녹화해 metadata.yaml 의 메시지 수로 판정할 것.

## 증상

새 스테레오 bag 을 녹화하기 전, 카메라 해상도를 정하려고 발행률을 쟀다.

```
/bluerov2/stereo/left/image_color  : average rate: 2.071    (640x480)
/bluerov2/stereo/left/image_color  : average rate: 7.495    (320x240)
```

픽셀 수 4 배에 율 4 배 — 완벽한 반비례라 "GPU fill rate 가 병목"이라는 결론이
자연스럽게 나왔다. 그 위에 "해상도를 올리면 율이 준다"는 트레이드오프 표를 만들어
사용자에게 선택지로 제시했다.

## 반증

같은 발행자에서 C++ 레코더(`ros2 bag record`)가 받은 것은 전혀 다른 값이다.
녹화된 bag 의 `metadata.yaml` 실측:

```
/bluerov2/stereo/left/image_color    8153 msgs / 872.8 s = 9.34 Hz
/bluerov2/stereo/right/image_color   8436 msgs / 872.8 s = 9.67 Hz
```

설정값 10 Hz 에 거의 붙어 있다. `ros2 topic hz` 가 보고한 2.07 Hz 는 발행률이
아니라 **파이썬 구독자가 소화한 율**이었다.

## 왜 반비례로 보였나

두 측정점의 대역폭을 보면 드러난다.

| 해상도 | hz 보고 | 프레임 크기 | 보고값 x 크기 |
|:--|--:|--:|--:|
| 640x480 | 2.07 Hz | 921,600 B | **1.9 MB/s** |
| 320x240 | 7.50 Hz | 230,400 B | **1.7 MB/s** |

율이 아니라 **대역폭이 상수**다. 고정된 처리량 한계에 걸린 구독자는 해상도에
반비례하는 율을 보고하고, 그 모양이 fill-rate 병목과 구별되지 않는다.

## 시사

- 대용량 메시지(영상)의 발행률을 `ros2 topic hz` 로 판단하지 말 것. 판단이
  필요하면 bag 에 녹화한 뒤 `metadata.yaml` 의 메시지 수를 구간으로 나눈다.
- FLS(`512x500` mono8, 256 KB)는 같은 도구로 16.2 Hz 를 보고했고 bag 실측이
  15.17 Hz 라 거의 맞았다 — 즉 이 함정은 메시지가 충분히 클 때만 발동한다.
  작은 토픽에서 맞았다는 경험이 큰 토픽의 신뢰 근거가 되지 못한다.
- 이 오측정으로 640x480 을 "율 2 Hz 를 감수하는 선택"으로 제시했다. 결과적으로
  고른 값은 같았지만 근거는 틀렸고, 1280x720 도 율 손해 없이 가능했을 수 있다
  (미검증).
## Comments
