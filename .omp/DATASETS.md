# Dataset Catalog

_Generated from `manifest.json` — do not edit by hand. Re-run `omp-dataset` to update._

**Last updated**: 2026-06-23
**External versioning**: none (no DVC / git-lfs detected)

---

## Overview

| ID | Path | SHA-256 (group hash, first 8 / last 8) | Size | Files | Source |
|:---|:---|:---|---:|---:|:---|
| `stonefish-models-v1` | `src/stonefish_sim/stonefish_description/data/models` | `6c787f6f…0214bc3e` | 582 MB | 127 | HERO-Lab-POSTECH/stonefish_sim |
| `stonefish-robots-v1` | `src/stonefish_sim/stonefish_description/data/robots` | `b84c8237…85280282` | 35 MB | 89 | HERO-Lab-POSTECH/stonefish_sim |
| `stonefish-worlds-v1` | `src/stonefish_sim/stonefish_description/data/worlds` | `60f63d58…ac6be1e1` | 3.4 MB | 16 | HERO-Lab-POSTECH/stonefish_sim |

---

## Dataset Entries

### `stonefish-models-v1`

- **Path**: `src/stonefish_sim/stonefish_description/data/models`
- **Type**: 3D simulation assets — environment object meshes and textures (non-tabular)
- **SHA-256 (group hash)**: `6c787f6feff1c92cea6fa9b471fb67d506dee5b9eb0dc0b25bab254f0214bc3e`
- **Size**: 610,270,967 bytes (approx. 582 MB)
- **File count**: 127
- **Source**: `HERO-Lab-POSTECH/stonefish_sim` (vcstool repo, in-tree asset)
- **Added**: 2026-06-23
- **Split**: omitted — simulation input asset, not an ML train/val/test split
- **Rows**: omitted — non-tabular mesh/texture data
- **Lineage**: omitted — origin not evidenced in-tree (no producing script or upstream source found)

### `stonefish-robots-v1`

- **Path**: `src/stonefish_sim/stonefish_description/data/robots`
- **Type**: 3D simulation assets — robot URDF meshes and textures (non-tabular)
- **SHA-256 (group hash)**: `b84c8237afc04c6c092cb1cf3fd889d23be52577d984e0a7a3fd173385280282`
- **Size**: 36,459,688 bytes (approx. 35 MB)
- **File count**: 89
- **Source**: `HERO-Lab-POSTECH/stonefish_sim` (vcstool repo, in-tree asset)
- **Added**: 2026-06-23
- **Split**: omitted — simulation input asset, not an ML train/val/test split
- **Rows**: omitted — non-tabular mesh/texture data
- **Lineage**: omitted — origin not evidenced in-tree (no producing script or upstream source found)

### `stonefish-worlds-v1`

- **Path**: `src/stonefish_sim/stonefish_description/data/worlds`
- **Type**: 3D simulation assets — world scene descriptors and meshes (non-tabular)
- **SHA-256 (group hash)**: `60f63d5830f3aafe47bdb97e07b1ec7a11772f747a901d74f30005b5ac6be1e1`
- **Size**: 3,532,756 bytes (approx. 3.4 MB)
- **File count**: 16
- **Source**: `HERO-Lab-POSTECH/stonefish_sim` (vcstool repo, in-tree asset)
- **Added**: 2026-06-23
- **Split**: omitted — simulation input asset, not an ML train/val/test split
- **Rows**: omitted — non-tabular mesh/texture data
- **Lineage**: omitted — origin not evidenced in-tree (no producing script or upstream source found)

---

## Directory Hash Algorithm (for reproducibility)

Each entry uses a **deterministic directory hash** because the unit of registration is a
directory group, not a single file. The algorithm uses stdlib `hashlib` only and is fully
reproducible:

1. Recursively collect all files under the group directory.
2. Sort by POSIX-style relative path (lexicographic, stable across OS).
3. For each file in sorted order: stream raw bytes in 1 MiB chunks through
   `hashlib.sha256` to produce `file_hex` (lowercase 64-hex).
4. Feed into a top-level SHA-256 accumulator in order:
   `rel_path.encode("utf-8") + b"\x00" + file_hex.encode("ascii")`.
5. The accumulator's final `.hexdigest()` is the `sha256` value recorded here.

If any single file changes, is added, or is removed, the group hash changes — enabling
drift detection at the directory level without re-hashing the entire tree on every audit.

**install/ mirror excluded**: `install/share/stonefish_description/data/` is a
colcon-generated mirror of these src assets. It is intentionally excluded from
registration — it is a regenerable build artifact, not an immutable source dataset.
Only the `src/` originals are tracked here.

---

## External Versioning

No DVC (`.dvc/`, `*.dvc`) or git-lfs (`filter=lfs` in `.gitattributes`) detected.
`managed_by_external.tool = "none"` — omp tracks these datasets directly via the hashes above.
