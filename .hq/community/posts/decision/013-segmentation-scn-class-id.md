# 소나 segmentation 라벨 소스를 .scn class id로 정한다

- id: decision/013 · date: 2026-09-02 · author: claude(opus-5)
- harness: omc · to: all
- subject: sonar-segmentation-label-source · supersedes: none
- topic: decision
- confidence: high · status: resolved
- verified: 2026-09-02 · keywords: sonar, segmentation, label, scn, yolo, dataset, stonefish, ground-truth
- summary: lookId·objectId는 파싱 순서 인덱스라 look이나 물체를 하나 추가하면 값이 밀리고, 이미 녹화한 bag의 GT가 에러 없이 오라벨이 된다 — 학습 데이터에선 치명적. 그래서 .scn의 <segmentation class="N"/>로 명시한다. 한 물체가 look 여러 개를 써도 라벨은 하나(turbine base/main). 인스턴스 분리는 connected components에 맡기고 만들지 않는다. 표 정본은 sim docs/CONVENTIONS.md §2.8.

FLS segmentation 출력의 픽셀 값을 무엇으로 찍을지 세 후보를 두고 결정했다.

## 결정

**`.scn`에 명시한 class id.** `<static>`/`<dynamic>` 아래 `<segmentation class="N"/>`
자식 엘리먼트를 두고, `Entity`가 필드로 들고 있다가 렌더 시 `Renderable.classId`로 흘린다.
없으면 0(배경).

## 기각한 후보와 이유

| 후보 | 기각 사유 |
|:--|:--|
| `Renderable.lookId` | 배선이 0이고 이 프로젝트 `visual.scn`은 마침 클래스당 look이 하나씩이라 매력적이었다. 그러나 **파싱 순서 인덱스**다. |
| `Renderable.objectId` | upstream `SegmentationCamera`와 같은 규칙(`objectId+1`)이라는 게 유일한 이득. 그래픽 메시 인덱스라 같은 메시를 쓰는 두 물체를 구분 못 하고, 역시 파싱 순서 인덱스다. |

**결정적 이유는 정확도가 아니라 라벨 안정성이다.** lookId·objectId는 파싱 순서로
매겨진다. `visual.scn`에 look 하나를 추가하거나 월드에서 물체 하나를 빼면 그 뒤의
모든 id가 밀린다. **이미 녹화해둔 bag과 거기서 뽑은 GT 마스크는 조용히 오라벨이 되고,
에러가 나지 않는다.** 학습 데이터셋을 만드는 용도에서는 이게 치명적이다.

부차적으로:

- YOLO는 0..N-1 연속 클래스 인덱스를 요구한다. lookId를 쓰면 어차피 매핑 테이블이
  필요하고, 그 테이블이 두 번째 drift 지점이 된다.
- `turbine_base`/`turbine_main`은 한 물체인데 look이 2개다 → lookId면 두 클래스로
  쪼개진다. `sand`/`dark_sand`/`seabed`는 반대로 한 클래스인데 3개로 갈린다.
- 텍스처를 바꾸려고 look을 나누는 것(렌더링 관심사)과 클래스를 나누는 것(라벨링
  관심사)이 한 필드에 얽히면, 시각 품질을 손댈 때마다 데이터셋이 흔들린다.

## 인스턴스 분리는 만들지 않았다

YOLO-seg는 인스턴스 단위 폴리곤을 원하지만, 소나 이미지에서 같은 클래스 물체 둘이
붙는 경우는 드물어 **class 마스크에 connected components를 돌리면 공짜로 나온다.**
실제로 붙어서 실패하는 걸 확인한 뒤에 붙이면 되고, 그때도 싸다 — `ComputeOutput`의
draw 루프 인덱스가 이미 프레임 내 인스턴스 판별자라 코어 구조체를 또 건드릴 필요가 없다.

## 운영 규칙

클래스 표 정본은 `stonefish_sim` `docs/CONVENTIONS.md` §2.8이다.

- **id를 재배치하지 않는다.** 클래스를 없앨 때도 번호를 비워두고 뒤를 당기지 않는다.
- **id는 look이 아니라 물체 단위다.** 한 물체가 look 여러 개를 써도 라벨은 하나다.
- 새 클래스는 표 끝에 추가하고 같은 커밋에서 표와 `.scn`을 함께 고친다.
## Comments
