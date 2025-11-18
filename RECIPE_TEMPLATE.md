# TorchAudio Build Recipe Templates

This document provides **mechanical, copy-paste templates** for creating any TorchAudio variant in the build matrix. Use these templates to generate `.nix` files for any combination of Python version, CUDA version, GPU architecture, and CPU ISA.

**IMPORTANT:** TorchAudio builds depend on matching PyTorch variants. The GPU architecture pattern varies by architecture - always check the corresponding PyTorch pattern first!

## Table of Contents

1. [Quick Reference](#quick-reference)
2. [GPU Architecture Patterns](#gpu-architecture-patterns)
3. [GPU Build Template](#gpu-build-template)
4. [CPU Build Template](#cpu-build-template)
5. [Variable Lookup Tables](#variable-lookup-tables)
6. [Examples](#examples)

---

## Quick Reference

### File Naming Convention

**GPU builds:**
```
.flox/pkgs/torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-{GPU_ARCH}-{CPU_ISA}.nix
```

**CPU builds:**
```
.flox/pkgs/torchaudio-{PYTHON}-cpu-{CPU_ISA}.nix
```

### Package Naming Convention

**GPU:** `torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-{GPU_ARCH}-{CPU_ISA}`
**CPU:** `torchaudio-{PYTHON}-cpu-{CPU_ISA}`

---

## GPU Architecture Patterns

**CRITICAL:** GPU architecture patterns vary! There are TWO different patterns used in PyTorch/TorchAudio:

### Pattern Type A: sm_XXX format (SM121)

Used by: **SM121** (and potentially newer architectures)

```nix
gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)
gpuTargets = [ gpuArchSM ]; # Uses sm_121
```

### Pattern Type B: Decimal format (SM120 and older)

Used by: **SM120, SM110, SM103, SM100, SM90, SM89, SM86, SM80**

```nix
# PyTorch's CMake accepts numeric format (12.0/9.0/8.9/etc) not sm_XXX
gpuArchNum = "12.0";       # Or "9.0", "8.9", "8.6", "8.0", etc.
# NO gpuArchSM variable
gpuTargets = [ gpuArchNum ]; # Uses numeric format directly
```

### Before Creating Variants: CHECK PYTORCH PATTERN!

**Command to verify pattern:**
```bash
grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-{PYTHON}-cuda{CUDA}-{GPU_ARCH}-*.nix | head -5
```

**Always match the pattern used in the corresponding PyTorch variant!**

---

## GPU Build Template

### Template for SM121 (Pattern Type A)

**File:** `.flox/pkgs/torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-sm121-{CPU_ISA}.nix`

```nix
# TorchAudio optimized for {GPU_DESC} + {CPU_ISA_DESC}
# Package name: torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-sm121-{CPU_ISA}

{ {PYTHON_PACKAGES}
, lib
, config
, cudaPackages
, addDriverRunpath
}:

let
  # GPU target: SM121 ({GPU_DESC})
  gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)

  # CPU optimization: {CPU_ISA_DESC}
  cpuFlags = [
    {CPU_FLAGS}
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  customPytorch = ({PYTHON_PACKAGES}.pytorch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  });

in
  ({PYTHON_PACKAGES}.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-sm121-{CPU_ISA}";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: SM121 ({GPU_DESC})"
      echo "CPU Features: {CPU_ISA_DESC}"
      echo "CUDA: {CUDA_VERSION} (Compute Capability 12.1)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for {GPU_DESC} + {CPU_ISA_DESC}";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: {GPU_DESC}
        - CPU: {CPU_ISA_DESC}
        - CUDA: {CUDA_VERSION}
        - Python: {PYTHON_VERSION}

        Hardware requirements:
        - GPU: {GPU_HARDWARE}
        - CPU: {CPU_HARDWARE}
        - Driver: NVIDIA 570+ required

        {CHOOSE_THIS_IF}
      '';
      platforms = [ "{PLATFORM}" ];
    };
  })
```

### Template for SM120 and Older (Pattern Type B)

**File:** `.flox/pkgs/torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-{GPU_ARCH}-{CPU_ISA}.nix`

```nix
# TorchAudio optimized for {GPU_DESC} + {CPU_ISA_DESC}
# Package name: torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-{GPU_ARCH}-{CPU_ISA}

{ {PYTHON_PACKAGES}
, lib
, config
, cudaPackages
, addDriverRunpath
}:

let
  # GPU target: {GPU_ARCH_UPPER} ({GPU_DESC})
  # PyTorch's CMake accepts numeric format ({GPU_ARCH_DECIMAL}) not sm_{GPU_ARCH_NUM}
  gpuArchNum = "{GPU_ARCH_DECIMAL}";

  # CPU optimization: {CPU_ISA_DESC}
  cpuFlags = [
    {CPU_FLAGS}
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  customPytorch = ({PYTHON_PACKAGES}.pytorch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchNum ];
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  });

in
  ({PYTHON_PACKAGES}.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-{PYTHON}-cuda{CUDA_MAJOR}_{CUDA_MINOR}-{GPU_ARCH}-{CPU_ISA}";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: {GPU_ARCH_UPPER} ({GPU_DESC})"
      echo "CPU Features: {CPU_ISA_DESC}"
      echo "CUDA: {CUDA_VERSION} (Compute Capability {GPU_ARCH_DECIMAL})"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for {GPU_DESC} + {CPU_ISA_DESC}";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: {GPU_DESC}
        - CPU: {CPU_ISA_DESC}
        - CUDA: {CUDA_VERSION}
        - Python: {PYTHON_VERSION}

        Hardware requirements:
        - GPU: {GPU_HARDWARE}
        - CPU: {CPU_HARDWARE}
        - Driver: NVIDIA 570+ required

        {CHOOSE_THIS_IF}
      '';
      platforms = [ "{PLATFORM}" ];
    };
  })
```

---

## CPU Build Template

**File:** `.flox/pkgs/torchaudio-{PYTHON}-cpu-{CPU_ISA}.nix`

```nix
# TorchAudio CPU-only optimized for {CPU_ISA_DESC}
# Package name: torchaudio-{PYTHON}-cpu-{CPU_ISA}

{ {PYTHON_PACKAGES}
, lib
, openblas
}:

let
  # CPU optimization: {CPU_ISA_DESC} (no GPU)
  cpuFlags = [
    {CPU_FLAGS}
  ];

  # Custom PyTorch with CPU-only configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  customPytorch = ({PYTHON_PACKAGES}.pytorch.override {
    cudaSupport = false;
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  });

in
  ({PYTHON_PACKAGES}.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-{PYTHON}-cpu-{CPU_ISA}";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: None (CPU-only build)"
      echo "CPU Features: {CPU_ISA_DESC}"
      echo "CUDA: Disabled"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio CPU-only build optimized for {CPU_ISA_DESC}";
      longDescription = ''
        Custom TorchAudio build for CPU-only workloads:
        - GPU: None (CPU-only)
        - CPU: {CPU_ISA_DESC}
        - Python: {PYTHON_VERSION}

        This build is suitable for inference, development, and workloads
        that don't require GPU acceleration.
      '';
      platforms = [ "{PLATFORMS}" ];
    };
  })
```

---

## Variable Lookup Tables

### Python Versions

| Variable | {PYTHON} | {PYTHON_PACKAGES} | {PYTHON_VERSION} |
|----------|----------|-------------------|------------------|
| Python 3.13 | `python313` | `python313Packages` or `python3Packages` | `3.13` |
| Python 3.12 | `python312` | `python312Packages` | `3.12` |
| Python 3.11 | `python311` | `python311Packages` | `3.11` |

### CUDA Versions

| Variable | {CUDA_MAJOR}_{CUDA_MINOR} | {CUDA_VERSION} | Available? |
|----------|---------------------------|----------------|------------|
| CUDA 12.8 | `12_8` | `12.8` | ✅ Yes (default) |
| CUDA 12.9 | `12_9` | `12.9` | ✅ Yes |
| CUDA 12.6 | `12_6` | `12.6` | ✅ Yes |
| CUDA 12.4 | `12_4` | `12.4` | ✅ Yes |
| CUDA 13.0 | `13_0` | `13.0` | ❌ Not in nixpkgs yet |

### GPU Architectures

**Status:** Only SM121 and SM120 are currently implemented (12/60 variants created).

| Variable | {GPU_ARCH} | {GPU_ARCH_UPPER} | {GPU_ARCH_DECIMAL} | {GPU_DESC} | Pattern | Status |
|----------|------------|------------------|-------------------|------------|---------|--------|
| SM121 | `sm121` | `SM121` | `12.1` | `NVIDIA DGX Spark (Specialized Datacenter)` | Type A | ✅ Done (6/6) |
| SM120 | `sm120` | `SM120` | `12.0` | `NVIDIA Blackwell (RTX 5090)` | Type B | ✅ Done (6/6) |
| SM110 | `sm110` | `SM110` | `11.0` | `NVIDIA DRIVE Thor, Orin+ (Automotive)` | Type B | ❌ Not created |
| SM103 | `sm103` | `SM103` | `10.3` | `NVIDIA Blackwell B300 (Datacenter)` | Type B | ❌ Not created |
| SM100 | `sm100` | `SM100` | `10.0` | `NVIDIA Blackwell B100/B200 (Datacenter)` | Type B | ❌ Not created |
| SM90 | `sm90` | `SM90` | `9.0` | `NVIDIA Hopper (H100, L40S)` | Type B | ❌ Not created |
| SM89 | `sm89` | `SM89` | `8.9` | `NVIDIA Ada Lovelace (RTX 4090, L40)` | Type B | ❌ Not created |
| SM86 | `sm86` | `SM86` | `8.6` | `NVIDIA Ampere (RTX 3090, A40, A5000)` | Type B | ❌ Not created |
| SM80 | `sm80` | `SM80` | `8.0` | `NVIDIA Ampere Datacenter (A100, A30)` | Type B | ❌ Not created |

**Pattern Type A** (SM121): Uses `gpuArchSM = "sm_121"` and `gpuTargets = [ gpuArchSM ]`
**Pattern Type B** (SM120 and older): Uses `gpuArchNum = "{GPU_ARCH_DECIMAL}"` and `gpuTargets = [ gpuArchNum ]` (NO gpuArchSM)

### GPU Architecture Extra Variables

| {GPU_ARCH} | {GPU_HARDWARE} | {CPU_HARDWARE} (x86) | {CPU_HARDWARE} (ARM) | {CHOOSE_THIS_IF} (x86) | {CHOOSE_THIS_IF} (ARM) |
|------------|----------------|---------------------|---------------------|----------------------|----------------------|
| sm121 | DGX Spark, specialized datacenter GPUs | Intel Sapphire Rapids+, AMD Zen 4+ | AWS Graviton3+, NVIDIA Grace | Choose this if: You have DGX Spark or specialized datacenter GPUs with latest server CPUs | Choose this if: You have DGX Spark in ARM-based datacenter with Graviton3+/Grace |
| sm120 | RTX 5090, Blackwell architecture GPUs | Intel Sapphire Rapids+, AMD Zen 4+ | AWS Graviton3+, NVIDIA Grace | Choose this if: You have RTX 5090 with latest CPUs | Choose this if: You have RTX 5090 in ARM-based system with latest processors |
| sm110 | DRIVE Thor, Orin+ automotive GPUs | Intel Alder Lake+, AMD Zen 3+ | NVIDIA Orin, Tegra automotive | Choose this if: You have automotive/embedded GPUs | Choose this if: You have automotive ARM platforms |
| sm103 | Blackwell B300 datacenter GPUs | Intel Sapphire Rapids+, AMD EPYC Genoa+ | AWS Graviton3+, Ampere Altra | Choose this if: You have B300 datacenter GPUs | Choose this if: You have B300 in ARM datacenter |
| sm100 | Blackwell B100/B200 datacenter GPUs | Intel Sapphire Rapids+, AMD EPYC Genoa+ | AWS Graviton3+, Ampere Altra | Choose this if: You have B100/B200 datacenter GPUs | Choose this if: You have B100/B200 in ARM datacenter |
| sm90 | H100, L40S (Hopper) | Intel Sapphire Rapids, AMD EPYC Milan+ | AWS Graviton2+, Ampere Altra | Choose this if: You have H100 or L40S GPUs | Choose this if: You have H100/L40S in ARM servers |
| sm89 | RTX 4090, RTX 4080, L40 (Ada Lovelace) | Intel Alder Lake+, AMD Zen 3+ | AWS Graviton2, ARM Neoverse | Choose this if: You have RTX 4090 or L40 GPUs | Choose this if: You have RTX 4000-series in ARM systems |
| sm86 | RTX 3090, RTX 3080, A40, A5000 (Ampere) | Intel 10th gen+, AMD Zen 2+ | AWS Graviton2, ARM Cortex-A76+ | Choose this if: You have RTX 3000-series or A40/A5000 GPUs | Choose this if: You have RTX 3000-series in ARM systems |
| sm80 | A100, A30 (Ampere datacenter) | Intel Cascade Lake+, AMD EPYC Rome+ | AWS Graviton2, Ampere eMAG+ | Choose this if: You have A100 or A30 datacenter GPUs | Choose this if: You have A100/A30 in ARM datacenter |

### CPU ISA (x86-64)

| Variable | {CPU_ISA} | {CPU_ISA_DESC} | {CPU_FLAGS} | {PLATFORM} |
|----------|-----------|----------------|-------------|------------|
| AVX-512 BF16 | `avx512bf16` | `AVX-512 with BF16` | `"-mavx512f"    "-mavx512dq"   "-mavx512vl"   "-mavx512bw"   "-mavx512bf16" "-mfma"` | `x86_64-linux` |
| AVX-512 VNNI | `avx512vnni` | `AVX-512 with VNNI` | `"-mavx512f"    "-mavx512dq"   "-mavx512vl"   "-mavx512bw"   "-mavx512vnni" "-mfma"` | `x86_64-linux` |
| AVX-512 | `avx512` | `AVX-512` | `"-mavx512f"    "-mavx512dq"   "-mavx512vl"   "-mavx512bw"   "-mfma"` | `x86_64-linux` |
| AVX2 | `avx2` | `AVX2` | `"-mavx2"       "-mfma"        "-mf16c"` | `x86_64-linux` |

**x86 CPU Hardware Details:**

| {CPU_ISA} | {CPU_HARDWARE} |
|-----------|----------------|
| avx512bf16 | Intel Cooper Lake+ (2020+), AMD Zen 4+ (2022+) with BF16 support |
| avx512vnni | Intel Cascade Lake+ (2019+), AMD Zen 4+ (2022+) |
| avx512 | Intel Skylake-X+ (2017+), AMD Zen 4+ (2022+) |
| avx2 | Intel Haswell+ (2013+), AMD Excavator+ (2015+) |

### CPU ISA (ARM)

| Variable | {CPU_ISA} | {CPU_ISA_DESC} | {CPU_FLAGS} | {PLATFORM} |
|----------|-----------|----------------|-------------|------------|
| ARMv9 | `armv9` | `ARMv9-A with SVE2` | `"-march=armv9-a+sve2"` | `aarch64-linux` |
| ARMv8.2 | `armv8.2` | `ARMv8.2-A with FP16 and dot product` | `"-march=armv8.2-a+fp16+dotprod"` | `aarch64-linux` |

**ARM CPU Hardware Details:**

| {CPU_ISA} | {CPU_HARDWARE} |
|-----------|----------------|
| armv9 | AWS Graviton3+, NVIDIA Grace, ARM Neoverse V1+, latest server/mobile processors |
| armv8.2 | AWS Graviton2, NVIDIA Tegra Xavier+, ARM Cortex-A76+ |

### Platform Combinations

| Build Type | CPU ISA | {PLATFORM} | {PLATFORMS} (CPU builds) |
|------------|---------|------------|--------------------------|
| GPU x86-64 | avx*, any x86 | `x86_64-linux` | N/A |
| GPU ARM | armv9, armv8.2 | `aarch64-linux` | N/A |
| CPU x86-64 | avx*, any x86 | N/A | `x86_64-linux` or both |
| CPU ARM | armv9, armv8.2 | N/A | `aarch64-linux` or both |

**Recommendation for CPU builds:** Use `[ "x86_64-linux" "aarch64-linux" ]` for maximum compatibility unless ISA is architecture-specific.

---

## Examples

### Example 1: SM121 (DGX Spark) with AVX-512, Python 3.13, CUDA 12.8

**File:** `.flox/pkgs/torchaudio-python313-cuda12_8-sm121-avx512.nix`

**Pattern:** Type A (uses gpuArchSM)

**Substitutions:**
- `{PYTHON}` → `python313`
- `{PYTHON_PACKAGES}` → `python3Packages`
- `{PYTHON_VERSION}` → `3.13`
- `{CUDA_MAJOR}_{CUDA_MINOR}` → `12_8`
- `{CUDA_VERSION}` → `12.8`
- `{GPU_ARCH}` → `sm121`
- `{GPU_ARCH_UPPER}` → `SM121`
- `{GPU_DESC}` → `NVIDIA DGX Spark (Specialized Datacenter)`
- `{GPU_HARDWARE}` → `DGX Spark, specialized datacenter GPUs`
- `{CPU_ISA}` → `avx512`
- `{CPU_ISA_DESC}` → `AVX-512`
- `{CPU_FLAGS}` → `"-mavx512f"    "-mavx512dq"   "-mavx512vl"   "-mavx512bw"   "-mfma"`
- `{CPU_HARDWARE}` → `Intel Sapphire Rapids+, AMD Zen 4+`
- `{PLATFORM}` → `x86_64-linux`
- `{CHOOSE_THIS_IF}` → `Choose this if: You have DGX Spark or specialized datacenter GPUs with latest server CPUs.`

**Result:** Use this template to create the file.

---

### Example 2: SM120 (RTX 5090) with AVX2, Python 3.13, CUDA 12.8

**File:** `.flox/pkgs/torchaudio-python313-cuda12_8-sm120-avx2.nix`

**Pattern:** Type B (uses gpuArchNum, NO gpuArchSM)

**Substitutions:**
- `{PYTHON}` → `python313`
- `{PYTHON_PACKAGES}` → `python3Packages`
- `{PYTHON_VERSION}` → `3.13`
- `{CUDA_MAJOR}_{CUDA_MINOR}` → `12_8`
- `{CUDA_VERSION}` → `12.8`
- `{GPU_ARCH}` → `sm120`
- `{GPU_ARCH_UPPER}` → `SM120`
- `{GPU_ARCH_DECIMAL}` → `12.0`
- `{GPU_ARCH_NUM}` → `120`
- `{GPU_DESC}` → `NVIDIA Blackwell (RTX 5090)`
- `{GPU_HARDWARE}` → `RTX 5090, Blackwell architecture GPUs`
- `{CPU_ISA}` → `avx2`
- `{CPU_ISA_DESC}` → `AVX2`
- `{CPU_FLAGS}` → `"-mavx2"       "-mfma"        "-mf16c"`
- `{CPU_HARDWARE}` → `Intel Haswell+ (2013+), AMD Excavator+ (2015+)`
- `{PLATFORM}` → `x86_64-linux`
- `{CHOOSE_THIS_IF}` → `Choose this if: You have RTX 5090 with AVX2-capable CPUs (most modern CPUs). AVX2 provides good performance with broad compatibility.`

**Result:** Use this template to create the file.

---

### Example 3: SM120 (RTX 5090) with ARMv9, Python 3.13, CUDA 12.8

**File:** `.flox/pkgs/torchaudio-python313-cuda12_8-sm120-armv9.nix`

**Pattern:** Type B (uses gpuArchNum, NO gpuArchSM)

**Substitutions:**
- `{PYTHON}` → `python313`
- `{PYTHON_PACKAGES}` → `python3Packages`
- `{PYTHON_VERSION}` → `3.13`
- `{CUDA_MAJOR}_{CUDA_MINOR}` → `12_8`
- `{CUDA_VERSION}` → `12.8`
- `{GPU_ARCH}` → `sm120`
- `{GPU_ARCH_UPPER}` → `SM120`
- `{GPU_ARCH_DECIMAL}` → `12.0`
- `{GPU_DESC}` → `NVIDIA Blackwell (RTX 5090)`
- `{GPU_HARDWARE}` → `RTX 5090, Blackwell architecture GPUs`
- `{CPU_ISA}` → `armv9`
- `{CPU_ISA_DESC}` → `ARMv9-A with SVE2`
- `{CPU_FLAGS}` → `"-march=armv9-a+sve2"`
- `{CPU_HARDWARE}` → `AWS Graviton3+, NVIDIA Grace, ARM Neoverse V1+`
- `{PLATFORM}` → `aarch64-linux`
- `{CHOOSE_THIS_IF}` → `Choose this if: You have RTX 5090 in ARM-based system with latest processors (Graviton3+, Grace Hopper superchip). ARMv9 with SVE2 provides best performance for ARM platforms.`

**Result:** Use this template to create the file.

---

### Example 4: CPU-only AVX2, Python 3.13

**File:** `.flox/pkgs/torchaudio-python313-cpu-avx2.nix`

**Substitutions:**
- `{PYTHON}` → `python313`
- `{PYTHON_PACKAGES}` → `python3Packages`
- `{PYTHON_VERSION}` → `3.13`
- `{CPU_ISA}` → `avx2`
- `{CPU_ISA_DESC}` → `AVX2`
- `{CPU_FLAGS}` → `"-mavx2"       "-mfma"        "-mf16c"`
- `{PLATFORMS}` → `"x86_64-linux" "aarch64-linux"` (both for compatibility)

---

## Generation Workflow

To create a new variant:

1. **Determine dimensions:**
   - Python version: 311, 312, or 313?
   - GPU architecture: sm121, sm120, sm90, sm86, etc., or CPU?
   - CPU ISA: avx512, avx2, armv9, etc.?
   - CUDA version (GPU only): 12_8, 12_9, etc.?

2. **CHECK PYTORCH PATTERN FIRST:**
   ```bash
   grep -E "gpuArchNum|gpuArchSM|gpuTargets" ../build-pytorch/.flox/pkgs/pytorch-{PYTHON}-cuda{CUDA}-{GPU_ARCH}-*.nix | head -5
   ```
   - If you see `gpuArchSM` → Use Pattern Type A template
   - If you see only `gpuArchNum` → Use Pattern Type B template

3. **Look up variables** from the tables above

4. **Copy the appropriate template** (GPU Pattern A, GPU Pattern B, or CPU)

5. **Find-and-replace** all `{VARIABLE}` placeholders

6. **Save** with the correct filename

7. **Verify the pattern matches PyTorch** (double-check!)

8. **Commit** to git:
   ```bash
   git add .flox/pkgs/torchaudio-{name}.nix
   git commit -m "Add {description}"
   ```

9. **Build** (optional, build time varies):
   ```bash
   flox build {package-name}
   ```

10. **Publish** (after successful build):
    ```bash
    flox publish -o <your-org> {package-name}
    ```

---

## Notes

- **CRITICAL:** Always check the corresponding PyTorch pattern before creating TorchAudio variants!
  - SM121 uses Pattern Type A (with gpuArchSM)
  - SM120 and older use Pattern Type B (without gpuArchSM)
- TorchAudio depends on a matching PyTorch variant with the same GPU/CPU configuration
- All GPU builds include custom PyTorch with matching optimizations
- **IMPORTANT:** TorchAudio uses `torch = customPytorch` (the correct override parameter)
- CUDA 13.0 is not available in nixpkgs yet (as of 2025-11-17)
- Default `cudaPackages` points to CUDA 12.8
- Default `python3Packages` points to Python 3.13
- ARM GPU builds should use `platforms = [ "aarch64-linux" ]`
- x86-64 GPU builds should use `platforms = [ "x86_64-linux" ]`
- CPU-only builds can use both platforms for maximum compatibility
- **Current Status:** Only SM121 (6/6) and SM120 (6/6) variants are created (12/60 total)

---

## PyTorch Dependency Resolution (TODO)

Future work: Set up proper dependency resolution to reference actual PyTorch packages from `../build-pytorch` instead of using `pytorch.override`. This will ensure exact matching between TorchAudio and PyTorch builds.

Currently, the `customPytorch` section uses `TODO: Reference the actual pytorch package from build-pytorch` as a placeholder.
