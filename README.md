# TorchAudio Architecture-Specific Builds

Build custom TorchAudio variants optimized for specific GPU architectures and CPU instruction sets using Flox and Nix.

## Overview

This project provides architecture-specific TorchAudio builds that match the GPU/CPU optimizations of corresponding PyTorch variants from `build-pytorch`. Each TorchAudio variant is compiled with targeted optimizations for specific hardware.

## Key Features

- **GPU-Optimized**: Builds for NVIDIA architectures (SM80-SM121)
- **CPU-Optimized**: AVX-512, AVX-512 BF16, AVX-512 VNNI, AVX2, ARMv8.2, ARMv9
- **Architecture-Specific**: Each build targets specific compute capabilities
- **Reproducible**: Managed with Flox/Nix for consistent builds

## Architecture Support

### GPU Architectures (CUDA 12.8)
- **SM121** (12.1) - DGX Spark (Specialized Datacenter)
- **SM120** (12.0) - Blackwell (RTX 5090)
- **SM110** (11.0) - NVIDIA DRIVE Thor, Orin+ (Automotive)
- **SM103** (10.3) - Blackwell B300 (Datacenter)
- **SM100** (10.0) - Blackwell B100/B200 (Datacenter)
- **SM90** (9.0) - Hopper (H100, L40S)
- **SM89** (8.9) - Ada Lovelace (RTX 4090, L40)
- **SM86** (8.6) - Ampere (RTX 3090, A40, A5000)
- **SM80** (8.0) - Ampere Datacenter (A100, A30)

### CPU Instruction Sets
- **AVX-512 BF16**: BF16 training on Intel Sapphire Rapids+
- **AVX-512 VNNI**: INT8 inference on Intel Cascade Lake+
- **AVX-512**: Intel Skylake-X+, AMD Zen 4+
- **AVX2**: Broad x86-64 compatibility
- **ARMv9**: AWS Graviton3+, Grace Hopper
- **ARMv8.2**: AWS Graviton2, NVIDIA Tegra

## Quick Start

### Prerequisites

1. **Matching PyTorch variant** from `build-pytorch`
2. **Flox** package manager
3. **NVIDIA GPU** (for CUDA builds) with appropriate drivers

### Building a Variant

```bash
# Navigate to build-torchaudio directory
cd build-torchaudio

# Activate flox environment
flox activate

# Build a specific variant
flox build torchaudio-python313-cuda12_8-sm120-avx512
```

## Current Status

**✅ 60/60 variants implemented (100%) 🎉 COMPLETE**

### Implemented (60 variants)
- ✅ **SM121 (DGX Spark)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM120 (RTX 5090)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM110 (DRIVE Thor)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM103 (B300)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM100 (B100/B200)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM90 (H100)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM89 (RTX 4090)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM86 (RTX 3090)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **SM80 (A100)**: All 6 CPU variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ **CPU-only**: All 6 variants (avx2, avx512, avx512bf16, avx512vnni, armv8.2, armv9)
- ✅ Flox environment initialized
- ✅ Git repository initialized
- ✅ Directory structure created
- ✅ RECIPE_TEMPLATE.md created
- ✅ BUILD_MATRIX.md created
- ✅ QUICKSTART.md created
- ✅ Memory saturation prevention implemented (requiredSystemFeatures)

### TODO (Enhancements)
- ⏳ Add test scripts
- ⏳ Configure proper PyTorch dependency resolution

## Package Naming Convention

```
torchaudio-python{VERSION}-cuda{CUDA_VERSION}-{GPU_ARCH}-{CPU_ISA}
```

Examples:
- `torchaudio-python313-cuda12_8-sm120-avx512` - RTX 5090 + AVX-512
- `torchaudio-python313-cuda12_8-sm90-avx512bf16` - H100 + AVX-512 BF16
- `torchaudio-python313-cuda12_8-sm86-avx2` - RTX 3090 + AVX2

## Dependencies

### PyTorch Integration

TorchAudio variants **must** be built against matching PyTorch variants:

```
torchaudio-python313-cuda12_8-sm120-avx512
  ↓ depends on
pytorch-python313-cuda12_8-sm120-avx512
```

**Important**: GPU architecture and CPU ISA must match between PyTorch and TorchAudio.

### Current Limitation

The sample .nix files currently reference nixpkgs' base `python3Packages.pytorch`. For production use, these should reference the actual PyTorch variants from `build-pytorch`.

**TODO**: Implement proper cross-project dependency resolution (options):
1. Reference `build-pytorch` packages via Flox
2. Use Nix overlays
3. Publish PyTorch to FloxHub and reference from there

## Directory Structure

```
build-torchaudio/
├── .flox/
│   ├── env/              # Flox environment configuration
│   ├── pkgs/             # Nix package definitions (.nix files)
│   └── ...
├── .git/                 # Git repository
├── README.md             # This file
└── (TODO: additional docs and scripts)
```

## Building Process

### Build Flow

1. TorchAudio .nix file specifies GPU/CPU configuration
2. Dependencies include matching PyTorch variant
3. Nix builds TorchAudio with:
   - GPU architecture targeting (inherited from PyTorch)
   - CPU optimization flags (CXXFLAGS/CFLAGS)
   - CUDA 12.8 support (via cudaPackages)

### Sample Build Command

```bash
# Build single variant
flox build torchaudio-python313-cuda12_8-sm120-avx512

# View build outputs
ls -l result*
```

## Build Configuration Details

### TorchAudio Build Pattern

TorchAudio variants use a custom build pattern similar to TorchVision:

```nix
# Create custom PyTorch with matching configuration
customPytorch = (python3Packages.pytorch.override {
  cudaSupport = true;
  gpuTargets = [ gpuArchNum ];  # or gpuArchSM for SM121
}).overrideAttrs (oldAttrs: {
  ninjaFlags = [ "-j32" ];
  requiredSystemFeatures = [ "big-parallel" ];

  preConfigure = (oldAttrs.preConfigure or "") + ''
    export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export MAX_JOBS=32
  '';
});

# Build TorchAudio with custom PyTorch
(python3Packages.torchaudio.override {
  torch = customPytorch;
}).overrideAttrs (oldAttrs: {
  pname = "torchaudio-python313-cuda12_8-sm120-avx512";
  ninjaFlags = [ "-j32" ];
  requiredSystemFeatures = [ "big-parallel" ];

  preConfigure = (oldAttrs.preConfigure or "") + ''
    export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export MAX_JOBS=32
  '';
})
```

### Memory Saturation Prevention (CRITICAL!)

**Problem:** TorchAudio builds trigger multiple concurrent derivations (PyTorch + TorchAudio + dependencies), each spawning unlimited CUDA compiler processes (`nvcc`, `cicc`, `ptxas`). On systems with `max-jobs = auto` and `cores = 0` (like Flox), this can saturate memory and spawn 95+ concurrent processes.

**Solution:** Use `requiredSystemFeatures = [ "big-parallel" ];` in **BOTH** the customPytorch and torchaudio sections:

```nix
customPytorch = (python3Packages.pytorch.override {
  cudaSupport = true;
  gpuTargets = [ gpuArchNum ];
}).overrideAttrs (oldAttrs: {
  ninjaFlags = [ "-j32" ];
  requiredSystemFeatures = [ "big-parallel" ];  # ← CRITICAL!

  preConfigure = (oldAttrs.preConfigure or "") + ''
    export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
    export MAX_JOBS=32
  '';
});

in
  (python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm120-avx512";
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];  # ← CRITICAL!

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32
    '';
  })
```

**Why this works:**
- `requiredSystemFeatures = [ "big-parallel" ]` tells Nix daemon to serialize resource-heavy builds
- Prevents concurrent builds of PyTorch + TorchAudio + dependencies
- Controls CUDA compiler parallelism at the Nix orchestration level
- `ninjaFlags = [ "-j32" ]` limits ninja build parallelism to 32 cores
- `MAX_JOBS=32` controls Python setuptools parallelism

**What doesn't work:**
- Environment variables like `NIX_BUILD_CORES` or `CMAKE_BUILD_PARALLEL_LEVEL` are ineffective
- CUDA compiler tools spawn their own processes outside ninja's control
- Only Nix-level serialization with `requiredSystemFeatures` prevents concurrent derivation builds

**All TorchAudio variants in this repository include this fix.** If creating new variants, see RECIPE_TEMPLATE.md for the correct pattern.

## Version Information

- **TorchAudio**: Latest from nixpkgs (tracks PyTorch version)
- **Python**: 3.13
- **CUDA**: 12.8
- **Platform**: Linux (x86_64-linux, aarch64-linux)

## Documentation

This project includes comprehensive documentation:

- **[README.md](./README.md)** - This file (overview and reference)
- **[QUICKSTART.md](./QUICKSTART.md)** - Quick start guide with examples
- **[BUILD_MATRIX.md](./BUILD_MATRIX.md)** - Complete build matrix (60/60 variants - 100% complete)
- **[RECIPE_TEMPLATE.md](./RECIPE_TEMPLATE.md)** - Templates for creating new variants

## GPU Architecture Patterns (CRITICAL!)

TorchAudio must match the GPU architecture pattern used by the corresponding PyTorch build. There are **TWO different patterns**:

### Pattern Type A: sm_XXX format

**Used by:** SM121, SM110, SM103, SM100, SM90, SM89, SM80 (7 architectures)

```nix
gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES
gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST
gpuTargets = [ gpuArchSM ]; # Uses sm_121
```

### Pattern Type B: Decimal format

**Used by:** SM120, SM86 (2 architectures)

```nix
# PyTorch's CMake accepts numeric format (12.0/9.0/8.9/etc) not sm_XXX
gpuArchNum = "12.0";       # Or "11.0", "10.3", "10.0", "9.0", "8.9", "8.6", "8.0"
# NO gpuArchSM variable
gpuTargets = [ gpuArchNum ]; # Uses numeric format directly
```

**ALWAYS check PyTorch pattern before creating variants!**

```bash
# Verify pattern for any architecture
grep -E "gpuArchNum|gpuArchSM|gpuTargets" \
  ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm{ARCH}-*.nix | head -5
```

## Relationship to build-pytorch

This project is a companion to `build-pytorch` and follows the same:
- Architecture support matrix
- Naming conventions
- Build patterns
- Documentation structure

## Next Steps

1. ✅ **All variants created**: 60/60 variants complete (9 GPU architectures + CPU-only)
2. **PyTorch dependency**: Implement proper dependency on `build-pytorch` packages
3. **Testing**: Add test scripts for verifying builds (TEST_GUIDE.md)
4. **CI/CD**: Add automated builds for all variants

## Contributing

This is a personal build system for creating optimized TorchAudio variants. The structure follows the established patterns from `build-pytorch`.

## Notes

- Builds are architecture-specific and won't work on mismatched hardware
- CUDA builds require NVIDIA drivers (570+ for Blackwell)
- Build times vary (20-40 minutes typical for TorchAudio)
- TorchAudio must match PyTorch version for ABI compatibility

## License

Follows the licensing of TorchAudio and nixpkgs packages.
