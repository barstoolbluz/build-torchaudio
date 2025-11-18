# TorchAudio Build Matrix Documentation

## Overview

This document defines the complete build matrix for custom TorchAudio builds, explaining all dimensions and their interactions.

**📖 Related Documentation:**
- **[RECIPE_TEMPLATE.md](./RECIPE_TEMPLATE.md)** - Copy-paste templates for generating any variant
- **[README.md](./README.md)** - User guide and quick start
- **[../build-pytorch/BUILD_MATRIX.md](../build-pytorch/BUILD_MATRIX.md)** - PyTorch build matrix (dependency)

**🔗 Dependency:** TorchAudio builds require matching PyTorch variants from `../build-pytorch/`

## Matrix Dimensions

Our build matrix has **4 independent dimensions** (same as PyTorch):

```
Build Variant = f(Python_Version, GPU_Architecture, CPU_ISA, CUDA_Toolkit)
```

### 1. Python Version

**Supported Versions:**
- Python 3.13 (current)
- Python 3.12 (planned)
- Python 3.11 (planned)

**Naming:** `python313`, `python312`, `python311`

**Example:** `torchaudio-python313-...`

### 2. GPU Architecture (Compute Capability)

**Supported GPU Architectures:**

| SM Version | Architecture | GPUs | CUDA Requirement | Pattern | Status |
|------------|--------------|------|------------------|---------|--------|
| **SM121** | DGX Spark | DGX Spark (Specialized Datacenter) | CUDA 12.8+ | Type A | ✅ Created (6/6) |
| **SM120** | Blackwell | RTX 5090 | CUDA 12.8+ | Type B | ✅ Created (6/6) |
| **SM110** | Automotive | DRIVE Thor, Orin+ | CUDA 12.0+ | Type A | ✅ Created (6/6) |
| **SM103** | Blackwell DC | B300 (Datacenter) | CUDA 12.0+ | Type A | ✅ Created (6/6) |
| **SM100** | Blackwell DC | B100/B200 (Datacenter) | CUDA 12.0+ | Type A | ✅ Created (6/6) |
| **SM90** | Hopper | H100, H200, L40S | CUDA 12.0+ | Type A | ✅ Created (6/6) |
| **SM89** | Ada Lovelace | RTX 4090, L4, L40 | CUDA 11.8+ | Type A | ✅ Created (6/6) |
| **SM86** | Ampere | RTX 3090, A5000, A40 | CUDA 11.1+ | Type B | ✅ Created (6/6) |
| **SM80** | Ampere DC | A100, A30 | CUDA 11.0+ | Type A | ✅ Created (6/6) |
| **CPU** | None | N/A | N/A | N/A | ✅ Created (6/6) |

**Naming:** `sm121`, `sm120`, `sm110`, `sm103`, `sm100`, `sm90`, `sm89`, `sm86`, `sm80`, `cpu`

**Example:** `torchaudio-python313-cuda12_8-sm120-...`

**Important Notes:**
- **Pattern Type A (SM121, SM110, SM103, SM100, SM90, SM89, SM80):** Uses `gpuArchSM = "sm_XXX"` and `gpuTargets = [ gpuArchSM ]`
- **Pattern Type B (SM120, SM86):** Uses `gpuArchNum = "X.X"` (decimal) and `gpuTargets = [ gpuArchNum ]` (NO gpuArchSM)
- Always check the corresponding PyTorch pattern before creating TorchAudio variants!
- SM120 requires PyTorch 2.7+ with CUDA 12.8+ and driver 570+

### 3. CPU Instruction Set Architecture (ISA)

**x86-64 Optimizations:**

| ISA | Compiler Flags | Hardware | Performance Gain | Compatibility |
|-----|----------------|----------|------------------|---------------|
| **AVX-512 BF16** | `-mavx512f -mavx512dq -mavx512vl -mavx512bw -mavx512bf16 -mfma` | Intel Cooper Lake+ (2020), AMD Zen 4+ (2022) | ~2.5x over baseline (BF16) | Limited |
| **AVX-512 VNNI** | `-mavx512f -mavx512dq -mavx512vl -mavx512bw -mavx512vnni -mfma` | Intel Skylake-SP+ (2017), AMD Zen 4+ (2022) | ~2.2x over baseline (INT8) | Limited |
| **AVX-512** | `-mavx512f -mavx512dq -mavx512vl -mavx512bw -mfma` | Intel Skylake-X+ (2017), AMD Zen 4+ (2022) | ~2x over baseline | Limited |
| **AVX2** | `-mavx2 -mfma -mf16c` | Intel Haswell+ (2013+), AMD Zen 1+ (2017) | ~1.5x over baseline | Broad |

**ARM Optimizations:**

| ISA | Compiler Flags | Hardware | Status |
|-----|----------------|----------|--------|
| **ARMv9** | `-march=armv9-a+sve2` | Neoverse V1/V2, Cortex-X2+, Graviton3+ | ✅ Implemented (SM121, SM120) |
| **ARMv8.2** | `-march=armv8.2-a+fp16+dotprod` | Neoverse N1, Cortex-A75+, Graviton2 | ✅ Implemented (SM121, SM120) |

**Naming:** `avx512bf16`, `avx512vnni`, `avx512`, `avx2`, `armv9`, `armv8.2`

**Example:** `torchaudio-python313-cuda12_8-sm120-avx512`

### 4. CUDA Toolkit Version

**CUDA Toolkit Compatibility Table:**

| CUDA Version | Min Driver (Linux) | SM121 | SM120 | SM110 | SM90 | SM89 | SM86 | Notes |
|--------------|-------------------|-------|-------|-------|------|------|------|-------|
| **13.0** | 580+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Latest, removes SM 5.x-7.0 |
| **12.9** | 575+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | Latest 12.x |
| **12.8** | 570+ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | PyTorch 2.7 default |
| **12.6** | 560+ | ✅** | ✅** | ✅ | ✅ | ✅ | ✅ | Stable |

**Current Implementation:** CUDA 12.8 (default)

**Naming:** Package names currently use `cuda12_8` in the middle (e.g., `torchaudio-python313-cuda12_8-sm120-avx512`)

## Current Implementation Status

### Total Build Matrix

**Total possible variants:** 60
- **GPU builds:** 54 (9 GPU architectures × 6 CPU ISAs)
  - x86-64: 36 (9 GPU × 4 CPU ISAs)
  - ARM: 18 (9 GPU × 2 CPU ISAs)
- **CPU-only builds:** 6 (6 CPU ISAs)

**Currently implemented:** 60/60 (100% ✅ COMPLETE)

### Implemented Variants

#### SM121 Variants (6/6) ✅ COMPLETE

All SM121 variants use **Pattern Type A** (with gpuArchSM):

| Package Name | CPU ISA | Platform | Status |
|-------------|---------|----------|--------|
| `torchaudio-python313-cuda12_8-sm121-avx2` | AVX2 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm121-avx512` | AVX-512 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm121-avx512bf16` | AVX-512 BF16 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm121-avx512vnni` | AVX-512 VNNI | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm121-armv8.2` | ARMv8.2-A | aarch64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm121-armv9` | ARMv9-A | aarch64-linux | ✅ Created |

**GPU Pattern (SM121):**
```nix
gpuArchNum = "121";
gpuArchSM = "sm_121";
gpuTargets = [ gpuArchSM ];
```

#### SM120 Variants (6/6) ✅ COMPLETE

All SM120 variants use **Pattern Type B** (without gpuArchSM):

| Package Name | CPU ISA | Platform | Status |
|-------------|---------|----------|--------|
| `torchaudio-python313-cuda12_8-sm120-avx2` | AVX2 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm120-avx512` | AVX-512 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm120-avx512bf16` | AVX-512 BF16 | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm120-avx512vnni` | AVX-512 VNNI | x86_64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm120-armv8.2` | ARMv8.2-A | aarch64-linux | ✅ Created |
| `torchaudio-python313-cuda12_8-sm120-armv9` | ARMv9-A | aarch64-linux | ✅ Created |

**GPU Pattern (SM120):**
```nix
# PyTorch's CMake accepts numeric format (12.0) not sm_120
gpuArchNum = "12.0";
# NO gpuArchSM variable
gpuTargets = [ gpuArchNum ];
```

### All Remaining Variants (48/60) ✅ COMPLETE

#### SM110 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA DRIVE Thor, Orin+ (Automotive)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_110"`)

- `torchaudio-python313-cuda12_8-sm110-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm110-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm110-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm110-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm110-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm110-armv9` (aarch64) - ✅ Created

#### SM103 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA Blackwell B300 (Datacenter)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_103"`)

- `torchaudio-python313-cuda12_8-sm103-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm103-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm103-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm103-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm103-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm103-armv9` (aarch64) - ✅ Created

#### SM100 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA Blackwell B100/B200 (Datacenter)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_100"`)

- `torchaudio-python313-cuda12_8-sm100-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm100-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm100-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm100-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm100-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm100-armv9` (aarch64) - ✅ Created

#### SM90 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA Hopper (H100, L40S)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_90"`)

- `torchaudio-python313-cuda12_8-sm90-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm90-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm90-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm90-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm90-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm90-armv9` (aarch64) - ✅ Created

#### SM89 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA Ada Lovelace (RTX 4090, L40)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_89"`)

- `torchaudio-python313-cuda12_8-sm89-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm89-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm89-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm89-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm89-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm89-armv9` (aarch64) - ✅ Created

#### SM86 Variants (6/6) ✅ COMPLETE - Pattern Type B

**GPU:** NVIDIA Ampere (RTX 3090, A40, A5000)
**Pattern:** Decimal format (`gpuArchNum = "8.6"`)

- `torchaudio-python313-cuda12_8-sm86-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm86-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm86-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm86-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm86-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm86-armv9` (aarch64) - ✅ Created

#### SM80 Variants (6/6) ✅ COMPLETE - Pattern Type A

**GPU:** NVIDIA Ampere Datacenter (A100, A30)
**Pattern:** sm_XXX format (`gpuArchSM = "sm_80"`)

- `torchaudio-python313-cuda12_8-sm80-avx2` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm80-avx512` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm80-avx512bf16` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm80-avx512vnni` (x86_64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm80-armv8.2` (aarch64) - ✅ Created
- `torchaudio-python313-cuda12_8-sm80-armv9` (aarch64) - ✅ Created

#### CPU-only Variants (6/6) ✅ COMPLETE

- `torchaudio-python313-cpu-avx2` (x86_64 or both platforms) - ✅ Created
- `torchaudio-python313-cpu-avx512` (x86_64 or both platforms) - ✅ Created
- `torchaudio-python313-cpu-avx512bf16` (x86_64 or both platforms) - ✅ Created
- `torchaudio-python313-cpu-avx512vnni` (x86_64 or both platforms) - ✅ Created
- `torchaudio-python313-cpu-armv8.2` (aarch64 or both platforms) - ✅ Created
- `torchaudio-python313-cpu-armv9` (aarch64 or both platforms) - ✅ Created

## GPU Architecture Patterns (CRITICAL!)

TorchAudio must match the GPU architecture pattern used by the corresponding PyTorch build. There are **TWO different patterns**:

### Pattern Type A: sm_XXX format

**Used by:** SM121, SM110, SM103, SM100, SM90, SM89, SM80 (7 architectures)

```nix
gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES
gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST
gpuTargets = [ gpuArchSM ]; # Uses sm_121
```

**Verification command:**
```bash
grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm121-*.nix | head -5
```

### Pattern Type B: Decimal format

**Used by:** SM120, SM86 (2 architectures)

```nix
# PyTorch's CMake accepts numeric format (12.0/9.0/8.9/etc) not sm_XXX
gpuArchNum = "12.0";       # Or "11.0", "10.3", "10.0", "9.0", "8.9", "8.6", "8.0"
# NO gpuArchSM variable
gpuTargets = [ gpuArchNum ]; # Uses numeric format directly
```

**Verification command:**
```bash
grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm120-*.nix | head -5
```

### Before Creating Variants: ALWAYS CHECK PATTERN!

**CRITICAL:** Before creating TorchAudio variants for a new GPU architecture:

1. Check the PyTorch pattern first:
   ```bash
   grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm{ARCH}-*.nix | head -5
   ```

2. If you see `gpuArchSM` → Use Pattern Type A template
3. If you see only `gpuArchNum` → Use Pattern Type B template

**Reference:** See `/tmp/gpu-arch-pattern-reference.md` for detailed pattern documentation.

## User Selection Guide

### For Users: How to Choose Your Build

1. **Check your GPU:**
   ```bash
   nvidia-smi --query-gpu=name,compute_cap --format=csv
   ```

2. **Check your driver:**
   ```bash
   nvidia-smi | grep "Driver Version"
   ```

3. **Match to build variant:**

   | Your GPU | Your Driver | Install This |
   |----------|-------------|--------------|
   | DGX Spark | 570+ | `torchaudio-python313-cuda12_8-sm121-avx512` (or other ISA) ✅ |
   | RTX 5090 | 570+ | `torchaudio-python313-cuda12_8-sm120-avx512` (or other ISA) ✅ |
   | RTX 5090 | < 570 | Upgrade driver first! |
   | H100/L40S | 570+ | `torchaudio-python313-cuda12_8-sm90-avx512` ✅ |
   | RTX 4090 | 570+ | `torchaudio-python313-cuda12_8-sm89-avx512` ✅ |
   | RTX 3090 | 570+ | `torchaudio-python313-cuda12_8-sm86-avx2` ✅ |
   | A100 | 570+ | `torchaudio-python313-cuda12_8-sm80-avx512` ✅ |
   | No GPU | Any | `torchaudio-python313-cpu-avx2` ✅ |

4. **Check CPU capabilities (for AVX-512 builds):**
   ```bash
   lscpu | grep -E 'avx512|avx2'
   ```

   If no AVX-512: Use AVX2 variant instead.

5. **Ensure matching PyTorch is installed:**
   ```bash
   # TorchAudio requires matching PyTorch variant
   flox install yourorg/pytorch-python313-cuda12_8-sm120-avx512
   flox install yourorg/torchaudio-python313-cuda12_8-sm120-avx512
   ```

## Build Strategy

### Completion Status

All variants have been created following this order:

1. **SM120 variants** (RTX 5090) - ✅ DONE
2. **SM121 variants** (DGX Spark) - ✅ DONE
3. **SM90 variants** (H100) - ✅ DONE
4. **SM89 variants** (RTX 4090) - ✅ DONE
5. **SM86 variants** (RTX 3090) - ✅ DONE
6. **SM80 variants** (A100) - ✅ DONE
7. **SM110/SM103/SM100** - ✅ DONE
8. **CPU-only variants** - ✅ DONE

### Generation Workflow

For each GPU architecture:

1. **Check PyTorch pattern:**
   ```bash
   grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm{ARCH}-*.nix | head -5
   ```

2. **Use RECIPE_TEMPLATE.md** to generate 6 variants:
   - 4 x86-64 variants: avx2, avx512, avx512bf16, avx512vnni
   - 2 ARM variants: armv8.2, armv9

3. **Verify pattern matches PyTorch**

4. **Build and test** (optional but recommended)

5. **Commit to git**

## Build Time Considerations

### Build Duration by Variant Type

| Variant Type | Estimated Time | Reason |
|--------------|----------------|--------|
| CPU-only | 30-60 minutes | Fewer compilation targets, depends on PyTorch |
| GPU (single SM) | 1-2 hours | CUDA compilation overhead, builds on top of PyTorch |

**Note:** TorchAudio builds are faster than PyTorch builds because they're smaller packages.

### Disk Space Requirements

| Component | Size per Build |
|-----------|----------------|
| Build artifacts | ~5-8 GB |
| Final package | ~500 MB - 1 GB |
| **Total per variant** | ~6-9 GB |

**Recommendation:** Build on CI/CD with at least 100GB free space to accommodate multiple variants.

## PyTorch Dependency Resolution (TODO)

**Current Status:** TorchAudio variants use `pytorch.override` to create a custom PyTorch with matching GPU/CPU configuration.

**Future Work:** Set up proper dependency resolution to reference actual PyTorch packages from `../build-pytorch` instead of using `pytorch.override`. This will ensure exact matching between TorchAudio and PyTorch builds.

**Implementation Notes:**
```nix
# Current (uses override):
customPytorch = (python3Packages.pytorch.override {
  cudaSupport = true;
  gpuTargets = [ gpuArchNum ];
}).overrideAttrs (oldAttrs: { ... });

# Future (reference actual package):
customPytorch = inputs.build-pytorch.packages.{system}.pytorch-python313-cuda12_8-sm120-avx512;
```

## Summary

**Current Status:**
- ✅ SM121: 6/6 variants created (100%)
- ✅ SM120: 6/6 variants created (100%)
- ✅ SM110: 6/6 variants created (100%)
- ✅ SM103: 6/6 variants created (100%)
- ✅ SM100: 6/6 variants created (100%)
- ✅ SM90: 6/6 variants created (100%)
- ✅ SM89: 6/6 variants created (100%)
- ✅ SM86: 6/6 variants created (100%)
- ✅ SM80: 6/6 variants created (100%)
- ✅ CPU-only: 6/6 variants created (100%)

**Total Progress: 60/60 (100% ✅ COMPLETE)**

**All variants created!** 🎉

**Pattern Reference:**
- Pattern Type A (SM121, SM110, SM103, SM100, SM90, SM89, SM80): with gpuArchSM
- Pattern Type B (SM120, SM86): without gpuArchSM, decimal format
- Always verify PyTorch pattern before creating variants!
