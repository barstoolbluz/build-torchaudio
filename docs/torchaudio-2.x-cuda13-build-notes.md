# TorchAudio 2.x + CUDA 13.0 Build Notes

This document captures the build architecture and configuration for TorchAudio with PyTorch 2.10.0 and CUDA 13.0, targeting all GPU architectures from SM80 (Ampere) through SM121 (DGX Spark).

## Overview

- **Purpose**: Build TorchAudio with a custom PyTorch 2.10.0 that includes all CUDA 13.0 compatibility fixes
- **TorchAudio Version**: 2.x (exact version depends on nixpkgs pin)
- **PyTorch Version**: 2.10.0 (upgraded via overlay)
- **CUDA Version**: 13.0
- **Target GPUs**: SM80–SM121 (Ampere through DGX Spark)
- **Target CPUs**: x86-64 (AVX2, AVX-512, AVX-512 BF16, AVX-512 VNNI) and ARM (ARMv8.2, ARMv9)

---

## Architecture: Three-Stage Build Pattern

Building TorchAudio with CUDA 13.0 requires a three-stage approach because TorchAudio must link against a PyTorch built with matching CUDA version and all compatibility fixes.

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: nixpkgs_pinned with Overlays                           │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Overlay 1: cudaPackages = cudaPackages_13                   │ │
│ │ Overlay 2: magma + CUDA 13.0 patch (clockRate fix)          │ │
│ │ Overlay 3: opencv + CUDA 13.0 patch (clockRate + thrust)    │ │
│ │ Overlay 4: torch → 2.10.0 (version, src, patches=[])        │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                              ↓                                  │
│ Stage 2: customPytorch                                          │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ torch.override { cudaSupport, gpuTargets }                  │ │
│ │ + overrideAttrs with CUDA 13.0 fixes:                       │ │
│ │   - Version fixes                                           │ │
│ │   - CCCL symlinks                                           │ │
│ │   - FindCUDAToolkit stub                                    │ │
│ │   - Gloo CUDA version hint                                  │ │
│ │   (MAGMA enabled via patched overlay)                       │ │
│ └─────────────────────────────────────────────────────────────┘ │
│                              ↓                                  │
│ Stage 3: TorchAudio                                             │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ torchaudio.override { torch = customPytorch }               │ │
│ │ + overrideAttrs with:                                       │ │
│ │   - CPU optimization flags                                  │ │
│ │   - Build parallelism control                               │ │
│ │   - Platform metadata                                       │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Pattern?

TorchAudio cannot simply use a pre-built PyTorch from another derivation because:

1. **Build-time linking**: TorchAudio compiles C++/CUDA extensions that link against PyTorch libraries
2. **CUDA version matching**: The PyTorch used must be built with the same CUDA version
3. **Fix propagation**: All CUDA 13.0 compatibility fixes must be present in the PyTorch that TorchAudio links against

By embedding the full `customPytorch` definition within the TorchAudio nix expression, we ensure consistent, reproducible builds.

---

## PyTorch CUDA 13.0 Fixes (Summary)

All CUDA 13.0 compatibility fixes are applied in Stage 2 (`customPytorch`). TorchAudio itself requires no CUDA 13.0-specific fixes beyond the OpenCV patch.

> **Detailed Documentation**: For complete fix explanations with error messages and solutions, see:
> [`build-pytorch/docs/pytorch-2.10-cuda13-build-notes.md`](https://github.com/barstoolbluz/build-pytorch/blob/cuda-13_0/docs/pytorch-2.10-cuda13-build-notes.md)
> (Note: This is in the separate `build-pytorch` repository)

### Summary Table

| Issue | Error Signature | Fix Applied |
|-------|-----------------|-------------|
| **MAGMA** | `no member named 'clockRate'` | MAGMA patch overlay (commit 235aefb7) |
| **OpenCV** | `no member named 'clockRate'` | OpenCV patch overlay (commit f0888a10) |
| **OpenCV contrib** | `thrust::not1 not a member` | opencv_contrib patch (commit 9a9b173) |
| **Version** | `TORCH_FEATURE_VERSION >= TORCH_VERSION_2_10_0` | `version.txt` + `PYTORCH_BUILD_VERSION` env + cmake flag |
| **CCCL** | `cccl/cuda/std/utility: No such file` | Symlink structure in `/build/cccl-compat` |
| **FindCUDA** | `file INSTALL cannot find` | Delegating cmake stub in `postPatch` |
| **Gloo** | *(preventative)* | `-DCUDA_VERSION=13.0` cmake flag |
| **Patches** | `can't find file to patch` | `patches = []` in overlay and overrideAttrs |

### Key Code Patterns

**MAGMA Patch Overlay** (Overlay 2):
```nix
(final: prev: {
  magma = prev.magma.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      (final.fetchpatch {
        name = "cuda-13.0-clockrate-fix.patch";
        url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
        hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU=";
      })
    ];
  });
})
```

**OpenCV Patch Overlay** (Overlay 3):
```nix
(final: prev: {
  opencv = prev.opencv.overrideAttrs (oldAttrs: {
    patches = (oldAttrs.patches or []) ++ [
      (final.fetchpatch {
        name = "opencv-cuda-13.0-deviceprop-fix.patch";
        url = "https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7.patch";
        hash = "sha256-zeDA8K7k6Sff5Xw/9XmqbCg/dhj9iu095rXuZTdj8PY=";
      })
    ];

    # Patch opencv_contrib for CUDA 13.0 (thrust::not1 removal)
    postPatch = (oldAttrs.postPatch or "") + ''
      if [ -d "opencv_contrib" ]; then
        echo "Patching opencv_contrib for CUDA 13.0 (thrust::not1 removal)..."
        patch -p2 -d opencv_contrib < ${final.fetchpatch {
          name = "opencv-contrib-cuda-13.0-videostab-fix.patch";
          url = "https://github.com/opencv/opencv_contrib/commit/9a9b173cd178e7c07a98896a009c2a2021a6b247.patch";
          hash = "sha256-W3eBv7HnoUrNBupXAykv5UsHcYG/o9P55VIddRYWrF8=";
        }}
      fi
    '';
  });
})
```

**CMake Flags**:
```nix
cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
  "-DTORCH_BUILD_VERSION=2.10.0"
  "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat"
  "-DCUDA_VERSION=13.0"
];
```

**CCCL Symlinks** (in preConfigure):
```bash
mkdir -p /build/cccl-compat/cccl
ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cuda /build/cccl-compat/cccl/cuda
ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cub /build/cccl-compat/cccl/cub
ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/thrust /build/cccl-compat/cccl/thrust
ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/nv /build/cccl-compat/cccl/nv
```

---

## TorchAudio-Specific Configuration

TorchAudio itself needs minimal configuration beyond using `customPytorch`. The TorchAudio `overrideAttrs` adds:

### 1. CPU Optimization Flags

```nix
preConfigure = (oldAttrs.preConfigure or "") + ''
  export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
  export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
  export MAX_JOBS=32
'';
```

### 2. Build Parallelism Control

```nix
ninjaFlags = [ "-j32" ];
requiredSystemFeatures = [ "big-parallel" ];
```

### 3. Platform Metadata

```nix
meta = oldAttrs.meta // {
  description = "TorchAudio for ...";
  platforms = [ "x86_64-linux" ];  # or [ "aarch64-linux" ] for ARM
};
```

---

## Available Variants

This branch provides 44 variants covering all GPU architectures and CPU ISAs:

### GPU Variants (x86-64)

| GPU Architecture | AVX2 | AVX-512 | AVX-512 BF16 | AVX-512 VNNI |
|------------------|------|---------|--------------|--------------|
| **SM121 (DGX Spark)** | `sm121-avx2` | `sm121-avx512` | `sm121-avx512bf16` | `sm121-avx512vnni` |
| **SM120 (Blackwell)** | `sm120-avx2` | `sm120-avx512` | `sm120-avx512bf16` | `sm120-avx512vnni` |
| **SM110 (DRIVE Thor)** | `sm110-avx2` | `sm110-avx512` | `sm110-avx512bf16` | `sm110-avx512vnni` |
| **SM103 (B300)** | `sm103-avx2` | `sm103-avx512` | `sm103-avx512bf16` | `sm103-avx512vnni` |
| **SM100 (B100/B200)** | `sm100-avx2` | `sm100-avx512` | `sm100-avx512bf16` | `sm100-avx512vnni` |
| **SM90 (Hopper)** | `sm90-avx2` | `sm90-avx512` | `sm90-avx512bf16` | `sm90-avx512vnni` |
| **SM89 (Ada)** | `sm89-avx2` | `sm89-avx512` | `sm89-avx512bf16` | `sm89-avx512vnni` |
| **SM86 (Ampere)** | `sm86-avx2` | `sm86-avx512` | `sm86-avx512bf16` | `sm86-avx512vnni` |
| **SM80 (Ampere DC)** | `sm80-avx2` | `sm80-avx512` | `sm80-avx512bf16` | `sm80-avx512vnni` |

### GPU Variants (ARM)

| GPU Architecture | ARMv8.2 | ARMv9 |
|------------------|---------|-------|
| **SM121 (DGX Spark)** | `sm121-armv8_2` | `sm121-armv9` |
| **SM110 (DRIVE Thor)** | `sm110-armv8_2` | `sm110-armv9` |

### CPU-Only Variants (x86-64)

| CPU ISA | Package Suffix | Use Case |
|---------|----------------|----------|
| AVX2 | `cpu-avx2` | Broad compatibility |
| AVX-512 | `cpu-avx512` | General workloads |
| AVX-512 BF16 | `cpu-avx512bf16` | BF16 training |
| AVX-512 VNNI | `cpu-avx512vnni` | INT8 inference |

### Package Naming Convention

All packages follow the pattern: `torchaudio-python313-cuda13_0-{gpu}-{cpu}`

Examples:
- `torchaudio-python313-cuda13_0-sm120-avx512` (RTX 5090 + AVX-512)
- `torchaudio-python313-cuda13_0-sm90-avx512vnni` (H100 + INT8 inference)
- `torchaudio-python313-cuda13_0-sm110-armv9` (DRIVE Thor + ARM Grace)
- `torchaudio-python313-cpu-avx2` (CPU-only development)

### GPU Architecture Notes

- **SM121**: DGX Spark workstation (Blackwell + Grace CPU)
- **SM120**: Blackwell consumer (RTX 50 series)
- **SM110**: Blackwell automotive/edge (NVIDIA DRIVE Thor)
- **SM103**: Blackwell datacenter (B300)
- **SM100**: Blackwell datacenter (B100, B200)
- **SM90**: Hopper datacenter (H100, H200, L40S)
- **SM89**: Ada Lovelace consumer (RTX 40 series, L4, L40)
- **SM86**: Ampere consumer (RTX 30 series high-end)
- **SM80**: Ampere datacenter (A100, A30)

### CPU ISA Notes

**x86-64:**
- **AVX2**: Intel Haswell+ (2013+), AMD Zen 1+ (2017+)
- **AVX-512**: Intel Skylake-X+ (2017+), AMD Zen 4+ (2022+)
- **AVX-512 BF16**: Intel Cooper Lake+ (2020+), AMD Zen 4+ (2022+) — for BF16 training
- **AVX-512 VNNI**: Intel Ice Lake+ (2019+), AMD Zen 4+ (2022+) — for INT8 inference

**ARM:**
- **ARMv8.2**: Neoverse N1, Cortex-A75+, AWS Graviton2
- **ARMv9**: Neoverse V1/V2, Cortex-X3+, NVIDIA Grace, AWS Graviton3+

---

## Canonical Reference Files

> **Canonical Reference**: The authoritative implementations are maintained at:
>
> - **x86 Reference**: `.flox/pkgs/torchaudio-python313-cuda13_0-sm120-avx512.nix`
> - **ARM Reference**: `.flox/pkgs/torchaudio-python313-cuda13_0-sm110-armv8_2.nix`
>
> The expression below is a snapshot for documentation purposes. Always refer to the canonical files for the latest working version.

---

## Full Working Nix Expression

```nix
# TorchAudio with PyTorch 2.10.0 for NVIDIA Blackwell (SM120: RTX 5090) + AVX-512
# Package name: torchaudio-python313-cuda13_0-sm120-avx512
#
# NOTE: This uses the same PyTorch 2.10.0 overlay approach as build-pytorch.
# See build-pytorch/docs/pytorch-2.10-cuda13-build-notes.md for details on fixes.
#
# CUDA 13.0 compatibility patches:
# - MAGMA: https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd
# - OpenCV: https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision with CUDA 13.0
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/6a030d535719c5190187c4cec156f335e95e3211.tar.gz";
  }) {
    config = {
      allowUnfree = true;
      allowBroken = true;
      cudaSupport = true;
    };
    overlays = [
      # Overlay 1: Use CUDA 13.0
      (final: prev: { cudaPackages = final.cudaPackages_13; })

      # Overlay 2: Patch MAGMA for CUDA 13.0 compatibility
      # This fixes: 'struct cudaDeviceProp' has no member named 'clockRate'
      (final: prev: {
        magma = prev.magma.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            (final.fetchpatch {
              name = "cuda-13.0-clockrate-fix.patch";
              url = "https://github.com/icl-utk-edu/magma/commit/235aefb7b064954fce09d035c69907ba8a87cbcd.patch";
              hash = "sha256-i9InbxD5HtfonB/GyF9nQhFmok3jZ73RxGcIciGBGvU=";
            })
          ];
        });
      })

      # Overlay 3: Patch OpenCV for CUDA 13.0 compatibility
      # This fixes: 'struct cudaDeviceProp' has no member named 'clockRate' (and others)
      # PR #27636: https://github.com/opencv/opencv/pull/27636
      # Also patches opencv_contrib for thrust::not1 removal (commit 9a9b173)
      (final: prev: {
        opencv = prev.opencv.overrideAttrs (oldAttrs: {
          patches = (oldAttrs.patches or []) ++ [
            (final.fetchpatch {
              name = "opencv-cuda-13.0-deviceprop-fix.patch";
              url = "https://github.com/opencv/opencv/commit/f0888a10e8266b2202d930c6974433a421e6f9a7.patch";
              hash = "sha256-zeDA8K7k6Sff5Xw/9XmqbCg/dhj9iu095rXuZTdj8PY=";
            })
          ];

          # Patch opencv_contrib for CUDA 13.0 (thrust::not1 removal)
          postPatch = (oldAttrs.postPatch or "") + ''
            if [ -d "opencv_contrib" ]; then
              echo "Patching opencv_contrib for CUDA 13.0 (thrust::not1 removal)..."
              patch -p2 -d opencv_contrib < ${final.fetchpatch {
                name = "opencv-contrib-cuda-13.0-videostab-fix.patch";
                url = "https://github.com/opencv/opencv_contrib/commit/9a9b173cd178e7c07a98896a009c2a2021a6b247.patch";
                hash = "sha256-W3eBv7HnoUrNBupXAykv5UsHcYG/o9P55VIddRYWrF8=";
              }}
            fi
          '';
        });
      })

      # Overlay 4: Upgrade PyTorch to 2.10.0
      (final: prev: {
        python3Packages = prev.python3Packages.override {
          overrides = pfinal: pprev: {
            torch = pprev.torch.overrideAttrs (oldAttrs: rec {
              version = "2.10.0";

              src = prev.fetchFromGitHub {
                owner = "pytorch";
                repo = "pytorch";
                rev = "v${version}";
                hash = "sha256-RKiZLHBCneMtZKRgTEuW1K7+Jpi+tx11BMXuS1jC1xQ=";
                fetchSubmodules = true;
              };

              # Clear patches - nixpkgs patches are for 2.9.1 and won't apply to 2.10.0
              patches = [];
            });
          };
        };
      })
    ];
  };

  # GPU target: SM120 (Blackwell consumer - RTX 5090)
  gpuArchSM = "12.0";

  # CPU optimization: AVX-512
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mfma"        # Fused multiply-add
  ];

  # Custom PyTorch 2.10.0 with all CUDA 13.0 fixes
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    pname = "pytorch210-for-torchaudio-sm120-avx512";

    # Clear patches
    patches = [];

    # Limit build parallelism
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    # CMake flags for CUDA 13.0 compatibility
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DTORCH_BUILD_VERSION=2.10.0"
      "-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat"
      "-DCUDA_VERSION=13.0"
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      # Version fixes for PyTorch 2.10.0
      export PYTORCH_BUILD_VERSION=2.10.0
      echo "2.10.0" > version.txt

      # CCCL header path compatibility for CUTLASS
      mkdir -p /build/cccl-compat/cccl
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cuda /build/cccl-compat/cccl/cuda
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/cub /build/cccl-compat/cccl/cub
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/thrust /build/cccl-compat/cccl/thrust
      ln -sf ${nixpkgs_pinned.cudaPackages.cuda_cccl}/include/nv /build/cccl-compat/cccl/nv
      export CXXFLAGS="-I/build/cccl-compat $CXXFLAGS"
      export CFLAGS="-I/build/cccl-compat $CFLAGS"
      export CUDAFLAGS="-I/build/cccl-compat $CUDAFLAGS"
    '';

    # FindCUDAToolkit.cmake delegating stub
    # Uses CMAKE_ROOT to directly include CMake's built-in module, avoiding infinite recursion when installed
    postPatch = (oldAttrs.postPatch or "") + ''
      mkdir -p cmake/Modules
      cat > cmake/Modules/FindCUDAToolkit.cmake << 'EOF'
# Delegating stub for FindCUDAToolkit
# Directly include CMake's built-in module to avoid infinite recursion
if(NOT CUDAToolkit_FOUND)
  include(''${CMAKE_ROOT}/Modules/FindCUDAToolkit.cmake)
endif()
EOF
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda13_0-sm120-avx512";

    # Limit build parallelism
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: ${gpuArchSM} (Blackwell: RTX 5090)"
      echo "CPU Features: AVX-512"
      echo "CUDA: 13.0"
      echo "PyTorch: 2.10.0 (with CUDA 13.0 fixes)"
      echo "MAGMA: Enabled (with CUDA 13.0 patch)"
      echo "TorchAudio: ${oldAttrs.version}"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 5090 (SM120, Blackwell) + AVX-512 with PyTorch 2.10.0";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell consumer architecture (SM120) - RTX 5090
        - CPU: x86-64 with AVX-512 instruction set
        - CUDA: 13.0 with compute capability 12.0
        - PyTorch: 2.10.0 (with all CUDA 13.0 compatibility fixes)
        - MAGMA: Enabled (patched for CUDA 13.0)
        - Python: 3.13

        Hardware requirements:
        - GPU: RTX 5090, RTX 5080, or other SM120 GPUs
        - CPU: Intel Skylake-X+ (2017+), AMD Zen 4+ (2022+)
        - Driver: NVIDIA 580+ required
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
```

---

## Verification Steps

### Build Verification

```bash
# Build the package
flox build torchaudio-python313-cuda13_0-sm120-avx512

# Check build artifacts
ls -la result-torchaudio-python313-cuda13_0-sm120-avx512/

# Verify library files
ls result-torchaudio-python313-cuda13_0-sm120-avx512/lib/python3.13/site-packages/torchaudio/
```

### Runtime Verification

```python
import torch
import torchaudio

# Check versions
print(f"PyTorch version: {torch.__version__}")
print(f"TorchAudio version: {torchaudio.__version__}")

# Check CUDA availability
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")

# Check GPU detection
if torch.cuda.is_available():
    print(f"GPU count: {torch.cuda.device_count()}")
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
    print(f"GPU capability: {torch.cuda.get_device_capability(0)}")

# Test TorchAudio functionality
# Load a sample audio file or generate test data
waveform = torch.randn(1, 16000)  # 1 second of random audio at 16kHz
print(f"Waveform shape: {waveform.shape}")

# Test spectrogram transform
spectrogram = torchaudio.transforms.Spectrogram()(waveform)
print(f"Spectrogram shape: {spectrogram.shape}")

# Test mel spectrogram
mel_spec = torchaudio.transforms.MelSpectrogram(sample_rate=16000)(waveform)
print(f"Mel spectrogram shape: {mel_spec.shape}")

# Test on GPU if available
if torch.cuda.is_available():
    waveform_cuda = waveform.cuda()
    mel_spec_cuda = torchaudio.transforms.MelSpectrogram(sample_rate=16000).cuda()(waveform_cuda)
    print(f"GPU mel spectrogram shape: {mel_spec_cuda.shape}")
```

---

## Known Limitations

1. **TorchAudio version depends on nixpkgs pin**: The exact TorchAudio version is determined by the nixpkgs commit `6a030d535719c5190187c4cec156f335e95e3211`. Future nixpkgs pins may have different versions.

2. **Build time**: The full build includes PyTorch compilation first, then TorchAudio. Expect several hours on a 32-core system.

3. **Overlay fragility**: This approach overrides nixpkgs packages (torch, magma, opencv) and may break if upstream packaging changes significantly.

4. **Cross-repo dependency**: The PyTorch fixes are documented in detail in the `build-pytorch` repository. Changes to PyTorch build requirements should be reflected in both repositories.

5. **MAGMA/OpenCV patch dependencies**: These CUDA 13.0 patches will become unnecessary once nixpkgs pins versions with the fixes (expected in future nixpkgs updates).

6. **ARM variant limitations**: ARM variants (SM110/SM121 with ARMv8.2/ARMv9) are only available for GPU architectures that have ARM-based deployment targets (DRIVE Thor, DGX Spark with Grace CPU).

---

## References

- [TorchAudio GitHub](https://github.com/pytorch/audio)
- [PyTorch GitHub](https://github.com/pytorch/pytorch)
- [PyTorch 2.10.0 + CUDA 13.0 Build Notes](https://github.com/barstoolbluz/build-pytorch/blob/cuda-13_0/docs/pytorch-2.10-cuda13-build-notes.md) (build-pytorch repository)
- [NVIDIA CUDA 13.0 Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/)
- [Nixpkgs CUDA Support](https://nixos.wiki/wiki/CUDA)
- [MAGMA Library](https://icl.utk.edu/magma/)
- [MAGMA CUDA 13.0 Fix](https://github.com/icl-utk-edu/magma/issues/61)
- [OpenCV CUDA 13.0 PR](https://github.com/opencv/opencv/pull/27636)
