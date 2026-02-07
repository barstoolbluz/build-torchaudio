# TorchVision 0.24 + CUDA 13.0 Build Notes

This document captures the build architecture and configuration for TorchVision with PyTorch 2.10.0 and CUDA 13.0, targeting Blackwell GPUs (SM120, SM110, SM121).

## Overview

- **Purpose**: Build TorchVision with a custom PyTorch 2.10.0 that includes all CUDA 13.0 compatibility fixes
- **TorchVision Version**: 0.24+ (exact version depends on nixpkgs pin)
- **PyTorch Version**: 2.10.0 (upgraded via overlay)
- **CUDA Version**: 13.0
- **Target GPUs**: SM120 (RTX 5090), SM110 (DRIVE Thor), SM121 (DGX Spark)
- **Target CPUs**: x86-64 (AVX-512) and ARM (ARMv8.2, ARMv9)

---

## Architecture: Three-Stage Build Pattern

Building TorchVision with CUDA 13.0 requires a three-stage approach because TorchVision must link against a PyTorch built with matching CUDA version and all compatibility fixes.

```
┌─────────────────────────────────────────────────────────────────┐
│ Stage 1: nixpkgs_pinned with Overlays                           │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ Overlay 1: cudaPackages = cudaPackages_13                   │ │
│ │ Overlay 2: magma + CUDA 13.0 patch (clockRate fix)          │ │
│ │ Overlay 3: torch → 2.10.0 (version, src, patches=[])        │ │
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
│ Stage 3: TorchVision                                            │
│ ┌─────────────────────────────────────────────────────────────┐ │
│ │ torchvision.override { torch = customPytorch }              │ │
│ │ + overrideAttrs with:                                       │ │
│ │   - CPU optimization flags                                  │ │
│ │   - Build parallelism control                               │ │
│ │   - Platform metadata                                       │ │
│ └─────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

### Why This Pattern?

TorchVision cannot simply use a pre-built PyTorch from another derivation because:

1. **Build-time linking**: TorchVision compiles C++/CUDA extensions that link against PyTorch libraries
2. **CUDA version matching**: The PyTorch used must be built with the same CUDA version
3. **Fix propagation**: All CUDA 13.0 compatibility fixes must be present in the PyTorch that TorchVision links against

By embedding the full `customPytorch` definition within the TorchVision nix expression, we ensure consistent, reproducible builds.

---

## PyTorch CUDA 13.0 Fixes (Summary)

All CUDA 13.0 compatibility fixes are applied in Stage 2 (`customPytorch`). TorchVision itself requires no CUDA 13.0-specific fixes.

> **Detailed Documentation**: For complete fix explanations with error messages and solutions, see:
> [`build-pytorch/docs/pytorch-2.10-cuda13-build-notes.md`](https://github.com/barstoolbluz/build-pytorch/blob/cuda-13_0/docs/pytorch-2.10-cuda13-build-notes.md)
> (Note: This is in the separate `build-pytorch` repository)

### Summary Table

| Issue | Error Signature | Fix Applied |
|-------|-----------------|-------------|
| **MAGMA** | `no member named 'clockRate'` | MAGMA patch overlay (commit 235aefb7) |
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

## TorchVision-Specific Configuration

TorchVision itself needs minimal configuration beyond using `customPytorch`. The TorchVision `overrideAttrs` adds:

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
  description = "TorchVision for ...";
  platforms = [ "x86_64-linux" ];  # or [ "aarch64-linux" ] for ARM
};
```

---

## Available Variants

| Package | GPU Target | CPU ISA | Platform | Use Case |
|---------|------------|---------|----------|----------|
| `torchvision-python313-cuda13_0-sm120-avx512` | SM120 (12.0) | AVX-512 | x86_64-linux | RTX 5090, RTX 5080 |
| `torchvision-python313-cuda13_0-sm110-armv8_2` | SM110 (11.0) | ARMv8.2+FP16+DotProd | aarch64-linux | NVIDIA DRIVE Thor |
| `torchvision-python313-cuda13_0-sm110-armv9` | SM110 (11.0) | ARMv9+SVE+SVE2 | aarch64-linux | NVIDIA DRIVE Thor (newer ARM) |
| `torchvision-python313-cuda13_0-sm121-armv8_2` | SM121 (12.1) | ARMv8.2+FP16+DotProd | aarch64-linux | NVIDIA DGX Spark |
| `torchvision-python313-cuda13_0-sm121-armv9` | SM121 (12.1) | ARMv9+SVE2 | aarch64-linux | NVIDIA DGX Spark (newer ARM) |

### GPU Architecture Notes

- **SM120**: Blackwell consumer architecture (RTX 50 series)
- **SM110**: Blackwell automotive/edge architecture (NVIDIA DRIVE Thor)
- **SM121**: Blackwell workstation architecture (DGX Spark with Grace CPU)

### CPU ISA Notes

- **AVX-512**: x86-64 with AVX-512F, AVX-512DQ, AVX-512VL, AVX-512BW, FMA
- **ARMv8.2**: ARM with FP16 and dot product extensions (Neoverse N1, Cortex-A75+)
- **ARMv9**: ARM with SVE/SVE2 vector extensions (Neoverse V2, Cortex-X3+)

---

## Canonical Reference Files

> **Canonical Reference**: The authoritative implementations are maintained at:
>
> - **x86 Reference**: `.flox/pkgs/torchvision-python313-cuda13_0-sm120-avx512.nix`
> - **ARM Reference**: `.flox/pkgs/torchvision-python313-cuda13_0-sm110-armv8_2.nix`
>
> The expression below is a snapshot for documentation purposes. Always refer to the canonical files for the latest working version.

---

## Full Working Nix Expression

```nix
# TorchVision 0.24+ with PyTorch 2.10.0 for NVIDIA Blackwell (SM120: RTX 5090) + AVX-512
# Package name: torchvision-python313-cuda13_0-sm120-avx512
#
# MAGMA is enabled via a CUDA 13.0 compatibility patch.
# Patch reference: https://github.com/icl-utk-edu/magma/issues/61

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

      # Overlay 3: Upgrade PyTorch to 2.10.0 with all CUDA 13.0 compatibility fixes
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
    pname = "pytorch210-for-torchvision-sm120-avx512";

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
    postPatch = (oldAttrs.postPatch or "") + ''
      mkdir -p cmake/Modules
      cat > cmake/Modules/FindCUDAToolkit.cmake << 'EOF'
# Delegating stub for FindCUDAToolkit
if(NOT CUDAToolkit_FOUND)
  set(_orig_module_path "''${CMAKE_MODULE_PATH}")
  list(FILTER CMAKE_MODULE_PATH EXCLUDE REGEX "cmake/Modules")
  include(FindCUDAToolkit)
  set(CMAKE_MODULE_PATH "''${_orig_module_path}")
endif()
EOF
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchvision.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchvision-python313-cuda13_0-sm120-avx512";

    # Limit build parallelism
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchVision Build Configuration"
      echo "========================================="
      echo "GPU Target: ${gpuArchSM} (Blackwell: RTX 5090)"
      echo "CPU Features: AVX-512"
      echo "CUDA: 13.0"
      echo "PyTorch: 2.10.0 (with CUDA 13.0 fixes)"
      echo "MAGMA: Enabled (with CUDA 13.0 patch)"
      echo "TorchVision: ${oldAttrs.version}"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchVision for NVIDIA RTX 5090 (SM120, Blackwell) + AVX-512 with PyTorch 2.10.0";
      longDescription = ''
        Custom TorchVision build with targeted optimizations:
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
flox build torchvision-python313-cuda13_0-sm120-avx512

# Check build artifacts
ls -la result-torchvision-python313-cuda13_0-sm120-avx512/

# Verify library files
ls result-torchvision-python313-cuda13_0-sm120-avx512/lib/python3.13/site-packages/torchvision/
```

### Runtime Verification

```python
import torch
import torchvision

# Check versions
print(f"PyTorch version: {torch.__version__}")
print(f"TorchVision version: {torchvision.__version__}")

# Check CUDA availability
print(f"CUDA available: {torch.cuda.is_available()}")
print(f"CUDA version: {torch.version.cuda}")

# Check GPU detection
if torch.cuda.is_available():
    print(f"GPU count: {torch.cuda.device_count()}")
    print(f"GPU name: {torch.cuda.get_device_name(0)}")
    print(f"GPU capability: {torch.cuda.get_device_capability(0)}")

# Test TorchVision transforms
from torchvision import transforms
transform = transforms.Compose([
    transforms.ToTensor(),
    transforms.Normalize((0.5,), (0.5,))
])
print("Transforms: OK")

# Test TorchVision models (downloads weights on first run)
from torchvision import models
model = models.resnet18(weights=None)
if torch.cuda.is_available():
    model = model.cuda()
    x = torch.randn(1, 3, 224, 224, device='cuda')
    y = model(x)
    print(f"ResNet18 inference test: {y.shape}")
```

---

## Known Limitations

1. **TorchVision version depends on nixpkgs pin**: The exact TorchVision version (0.24.x) is determined by the nixpkgs commit `6a030d535719c5190187c4cec156f335e95e3211`. Future nixpkgs pins may have different versions.

2. **Build time**: The full build includes PyTorch compilation first, then TorchVision. Expect several hours on a 32-core system.

3. **Overlay fragility**: This approach overrides nixpkgs packages (torch, magma) and may break if upstream packaging changes significantly.

4. **Cross-repo dependency**: The PyTorch fixes are documented in detail in the `build-pytorch` repository. Changes to PyTorch build requirements should be reflected in both repositories.

5. **MAGMA patch dependency**: The MAGMA CUDA 13.0 patch will become unnecessary once nixpkgs pins a version with the fix (expected in future nixpkgs updates).

---

## References

- [TorchVision GitHub](https://github.com/pytorch/vision)
- [PyTorch GitHub](https://github.com/pytorch/pytorch)
- [PyTorch 2.10.0 + CUDA 13.0 Build Notes](https://github.com/barstoolbluz/build-pytorch/blob/cuda-13_0/docs/pytorch-2.10-cuda13-build-notes.md) (build-pytorch repository)
- [NVIDIA CUDA 13.0 Release Notes](https://docs.nvidia.com/cuda/cuda-toolkit-release-notes/)
- [Nixpkgs CUDA Support](https://nixos.wiki/wiki/CUDA)
- [MAGMA Library](https://icl.utk.edu/magma/)
- [MAGMA CUDA 13.0 Fix](https://github.com/icl-utk-edu/magma/issues/61)
