# Quick Start Guide

## Choosing Your Variant

**60 variants complete** (60/60 implemented - 100% ✅). Choose based on your hardware to match your PyTorch variant.

**IMPORTANT:** TorchAudio requires a matching PyTorch variant. Install PyTorch first from `../build-pytorch/`.

### Quick Selection

**Have NVIDIA GPU?**
```bash
# Check your GPU
nvidia-smi --query-gpu=name,compute_cap --format=csv,noheader
```

| Your GPU | Compute Cap | Architecture | Example Package | Status |
|----------|-------------|--------------|-----------------|--------|
| DGX Spark | 12.1 | SM121 | `torchaudio-python313-cuda12_8-sm121-avx512` | ✅ Available (6 variants) |
| RTX 5090 | 12.0 | SM120 | `torchaudio-python313-cuda12_8-sm120-avx512` | ✅ Available (6 variants) |
| NVIDIA DRIVE Thor, Orin+ | 11.0 | SM110 | `torchaudio-python313-cuda12_8-sm110-avx512` | ✅ Available (6 variants) |
| B300 | 10.3 | SM103 | `torchaudio-python313-cuda12_8-sm103-avx512` | ✅ Available (6 variants) |
| B100, B200 | 10.0 | SM100 | `torchaudio-python313-cuda12_8-sm100-avx512` | ✅ Available (6 variants) |
| H100, L40S | 9.0 | SM90 | `torchaudio-python313-cuda12_8-sm90-avx512` | ✅ Available (6 variants) |
| RTX 4090, L40 | 8.9 | SM89 | `torchaudio-python313-cuda12_8-sm89-avx512` | ✅ Available (6 variants) |
| RTX 3090, A40 | 8.6 | SM86 | `torchaudio-python313-cuda12_8-sm86-avx512` | ✅ Available (6 variants) |
| A100, A30 | 8.0 | SM80 | `torchaudio-python313-cuda12_8-sm80-avx512` | ✅ Available (6 variants) |

**CPU-only (no GPU)?**
```bash
# Check CPU features
lscpu | grep -E 'avx512|sve'
```

- See `avx512_bf16`? → Use `torchaudio-python313-cpu-avx512bf16` ✅
- See `avx512_vnni`? → Use `torchaudio-python313-cpu-avx512vnni` ✅
- See `avx512f`? → Use `torchaudio-python313-cpu-avx512` ✅
- See `avx2` only? → Use `torchaudio-python313-cpu-avx2` ✅
- See `sve2` (ARM)? → Use `torchaudio-python313-cpu-armv9` ✅
- ARM without sve2? → Use `torchaudio-python313-cpu-armv8.2` ✅

**Naming format:** `torchaudio-python313-{cuda12_8-smXX|cpu}-{cpu-isa}`

## Current Status

### All Variants Available (60/60) ✅ COMPLETE

All 60 TorchAudio variants are now available:
- **9 GPU architectures** × 6 CPU ISAs = 54 GPU variants
- **6 CPU-only variants** (all CPU ISAs)

See **BUILD_MATRIX.md** for the complete list of all variants.

## Building TorchAudio Variants

### Prerequisites

**IMPORTANT:** TorchAudio depends on PyTorch. Ensure matching PyTorch variant exists in `../build-pytorch/`:

```bash
# Check if matching PyTorch exists
ls ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm120-avx512.nix

# If not, build PyTorch first
cd ../build-pytorch
flox activate
flox build pytorch-python313-cuda12_8-sm120-avx512
cd ../build-torchaudio
```

### 1. Enter the Environment

```bash
cd /home/daedalus/dev/builds/build-torchaudio
flox activate
```

### 2. Build a Variant

```bash
# SM120 variants (RTX 5090) - Available now
flox build torchaudio-python313-cuda12_8-sm120-avx2        # Broad compatibility
flox build torchaudio-python313-cuda12_8-sm120-avx512      # General performance
flox build torchaudio-python313-cuda12_8-sm120-avx512bf16  # BF16 training
flox build torchaudio-python313-cuda12_8-sm120-avx512vnni  # INT8 inference

# SM121 variants (DGX Spark) - Available now
flox build torchaudio-python313-cuda12_8-sm121-avx512      # General performance

# ARM variants (if on ARM server)
flox build torchaudio-python313-cuda12_8-sm120-armv9       # Grace, Graviton3+
flox build torchaudio-python313-cuda12_8-sm120-armv8.2     # Graviton2

# Other GPU architectures - All available now!
flox build torchaudio-python313-cuda12_8-sm90-avx512      # H100 ✅
flox build torchaudio-python313-cuda12_8-sm89-avx512      # RTX 4090 ✅
flox build torchaudio-python313-cuda12_8-sm86-avx512      # RTX 3090 ✅
flox build torchaudio-python313-cuda12_8-sm80-avx512      # A100 ✅

# CPU-only variants - All available now!
flox build torchaudio-python313-cpu-avx2                   # CPU only ✅
flox build torchaudio-python313-cpu-avx512                 # CPU only ✅
```

### 3. Use the Built Package

```bash
# Result appears as a symlink
ls -lh result-torchaudio-python313-cuda12_8-sm120-avx512

# Test it
./result-torchaudio-python313-cuda12_8-sm120-avx512/bin/python -c "import torchaudio; print(torchaudio.__version__)"

# Activate the environment
source result-torchaudio-python313-cuda12_8-sm120-avx512/bin/activate
python -c "import torch, torchaudio; print(f'PyTorch: {torch.__version__}, TorchAudio: {torchaudio.__version__}')"
```

## What Happened

The build command:
```bash
flox build torchaudio-python313-cuda12_8-sm120-avx512
```

Is doing:
1. Reading `.flox/pkgs/torchaudio-python313-cuda12_8-sm120-avx512.nix`
2. Creating a custom PyTorch with matching GPU/CPU configuration
3. Calling `python3Packages.torchaudio.override` with the custom PyTorch
4. Setting `CXXFLAGS="-mavx512f -mavx512dq -mavx512vl -mavx512bw -mfma"` for CPU optimization
5. Compiling TorchAudio from source (~30-90 minutes)
6. Creating a result symlink: `./result-torchaudio-python313-cuda12_8-sm120-avx512`

## Successful Output

You should see output like this:

```
Building python3.13-torchaudio-python313-cuda12_8-sm120-avx512-2.5.1 in Nix expression mode
this derivation will be built:
  /nix/store/...-python3.13-torchaudio-python313-cuda12_8-sm120-avx512-2.5.1.drv
these X paths will be fetched (...):
```

This means:
- ✅ Flox found your Nix expression
- ✅ The package name is correct
- ✅ Dependencies (including PyTorch) are being resolved
- ✅ The build will compile TorchAudio with your custom flags

## Build Time Warning

**CPU-only builds:** 30-60 minutes on a multi-core system
**GPU builds:** 1-2 hours (CUDA compilation overhead + PyTorch compilation)

**Note:** TorchAudio builds are faster than PyTorch builds because the package is smaller.

**Recommendation:** Start with one variant to validate everything works, then queue up multiple builds to run in parallel or overnight.

## Publishing (After Build Completes)

Once you have successfully built packages:

```bash
# Push to git remote
git remote add origin <your-repo-url>
git push origin main

# Publish to Flox catalog (requires flox auth login)
flox publish -o <your-org> torchaudio-python313-cuda12_8-sm120-avx512
flox publish -o <your-org> torchaudio-python313-cuda12_8-sm120-avx2
flox publish -o <your-org> torchaudio-python313-cuda12_8-sm121-avx512

# Users can then install with:
flox install <your-org>/torchaudio-python313-cuda12_8-sm120-avx512
```

**IMPORTANT:** Ensure matching PyTorch variants are also published so users can install the complete stack!

## Adding More Variants

### Step 1: Check PyTorch Pattern

**CRITICAL:** Before creating TorchAudio variants for a new GPU architecture, check the PyTorch pattern!

```bash
# Example: Check SM90 pattern
grep -E "gpuArchNum|gpuArchSM|gpuTargets" \
  ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm90-*.nix | head -5
```

**If you see `gpuArchSM`:** Use Pattern Type A (like SM121)
**If you see only `gpuArchNum`:** Use Pattern Type B (like SM120)

### Step 2: Use RECIPE_TEMPLATE.md

See **RECIPE_TEMPLATE.md** for complete templates and variable lookup tables.

### Step 3: Copy and Modify

#### Example: Creating SM90 variants (Pattern Type A)

```bash
# SM90 uses Pattern Type A (like SM121)
# Copy an existing SM121 file as template
cp .flox/pkgs/torchaudio-python313-cuda12_8-sm121-avx512.nix \
   .flox/pkgs/torchaudio-python313-cuda12_8-sm90-avx512.nix
```

Edit the new file:
```nix
let
  # GPU target: SM90 (Hopper architecture - H100, L40S)
  gpuArchNum = "90";        # For CMAKE_CUDA_ARCHITECTURES
  gpuArchSM = "sm_90";      # For TORCH_CUDA_ARCH_LIST

  # CPU optimization: AVX-512
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mfma"        # Fused multiply-add
  ];

  customPytorch = (python3Packages.pytorch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];  # Uses sm_90 format for SM90
  }).overrideAttrs (oldAttrs: {
    # CRITICAL: Prevent memory saturation during builds
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

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
    pname = "torchaudio-python313-cuda12_8-sm90-avx512";  # Updated name

    # CRITICAL: Prevent memory saturation during builds
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="$CXXFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export CFLAGS="$CFLAGS ${lib.concatStringsSep " " cpuFlags}"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: SM90 (Hopper: H100, L40S)"
      echo "CPU Features: AVX-512"
      echo "CUDA: 12.8 (Compute Capability 9.0)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';
    # ... Update meta sections
  })
```

**Key changes:**
- Line 3 comment: Change to "SM90 (Hopper architecture - H100, L40S)"
- Line 4: Change `gpuArchNum = "90"` (was "121")
- Line 5: Change `gpuArchSM = "sm_90"` (was "sm_121")
- Line 35: Change `pname = "torchaudio-python313-cuda12_8-sm90-avx512"`
- Line 33: Use `torch = customPytorch;` (the correct override parameter for torchaudio)
- Update echo statements and meta description to reference H100/L40S

**CRITICAL:** Always include these in BOTH customPytorch and torchaudio sections:
- `ninjaFlags = [ "-j32" ];` - Limits ninja build parallelism
- `requiredSystemFeatures = [ "big-parallel" ];` - Prevents memory saturation
- `export MAX_JOBS=32` - Limits Python setuptools parallelism

See README.md "Memory Saturation Prevention" section for technical details.

### Step 4: Create All 6 Variants for the Architecture

For each GPU architecture, create 6 variants:
- 4 x86-64: `avx2`, `avx512`, `avx512bf16`, `avx512vnni`
- 2 ARM: `armv8.2`, `armv9`

Use **RECIPE_TEMPLATE.md** for the exact templates and variable substitutions.

### Step 5: Commit and Build

```bash
git add .flox/pkgs/torchaudio-python313-cuda12_8-sm90-*.nix
git commit -m "Add SM90 (H100/L40S) TorchAudio variants"
flox build torchaudio-python313-cuda12_8-sm90-avx512
```

## Pattern Type Reference

### Pattern Type A (SM121, SM110, SM103, SM100, SM90, SM89, SM80)

```nix
gpuArchNum = "121";        # For CMAKE_CUDA_ARCHITECTURES (or "110", "103", "100", "90", "89", "80")
gpuArchSM = "sm_121";      # For TORCH_CUDA_ARCH_LIST (or "sm_110", "sm_103", etc.)
gpuTargets = [ gpuArchSM ]; # Uses sm_XXX format
```

### Pattern Type B (SM120, SM86)

```nix
# PyTorch's CMake accepts numeric format (12.0/8.6) not sm_XXX
gpuArchNum = "12.0";       # Or "8.6"
# NO gpuArchSM variable
gpuTargets = [ gpuArchNum ]; # Uses numeric format directly
```

**ALWAYS check PyTorch pattern before creating variants!**

## Example: Creating SM90 Variants (Full Workflow)

```bash
# 1. Verify PyTorch SM90 pattern
grep -E "gpuArchNum|gpuArchSM|gpuTargets" \
  ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm90-*.nix | head -5

# Expected output shows Pattern Type A (sm_XXX format)
# gpuArchNum = "90";
# gpuArchSM = "sm_90";
# gpuTargets = [ gpuArchSM ];

# 2. Use RECIPE_TEMPLATE.md to create all 6 SM90 variants
# (Copy Pattern Type A template, substitute gpuArchNum = "90", gpuArchSM = "sm_90", etc.)

# 3. Verify files created
ls .flox/pkgs/torchaudio-python313-cuda12_8-sm90-*.nix

# Should see:
# torchaudio-python313-cuda12_8-sm90-avx2.nix
# torchaudio-python313-cuda12_8-sm90-avx512.nix
# torchaudio-python313-cuda12_8-sm90-avx512bf16.nix
# torchaudio-python313-cuda12_8-sm90-avx512vnni.nix
# torchaudio-python313-cuda12_8-sm90-armv8.2.nix
# torchaudio-python313-cuda12_8-sm90-armv9.nix

# 4. Commit
git add .flox/pkgs/torchaudio-python313-cuda12_8-sm90-*.nix
git commit -m "Add SM90 (H100/L40S) TorchAudio variants - all 6 CPU ISAs"

# 5. Build one variant to test
flox build torchaudio-python313-cuda12_8-sm90-avx512

# 6. If successful, build the rest
flox build torchaudio-python313-cuda12_8-sm90-avx2
flox build torchaudio-python313-cuda12_8-sm90-avx512bf16
flox build torchaudio-python313-cuda12_8-sm90-avx512vnni
flox build torchaudio-python313-cuda12_8-sm90-armv8.2
flox build torchaudio-python313-cuda12_8-sm90-armv9
```

## Testing Your Build

See **TEST_GUIDE.md** (when created) for comprehensive testing procedures.

Quick test:
```bash
# Test import and version
./result-torchaudio-python313-cuda12_8-sm120-avx512/bin/python -c "
import torch
import torchaudio
print(f'PyTorch: {torch.__version__}')
print(f'TorchAudio: {torchaudio.__version__}')
print(f'CUDA available: {torch.cuda.is_available()}')
"

# Test GPU detection (GPU builds only)
./result-torchaudio-python313-cuda12_8-sm120-avx512/bin/python -c "
import torch
if torch.cuda.is_available():
    print(f'GPU: {torch.cuda.get_device_name(0)}')
    print(f'Compute Capability: {torch.cuda.get_device_capability(0)}')
"

# Test TorchAudio functionality
./result-torchaudio-python313-cuda12_8-sm120-avx512/bin/python -c "
import torchaudio
import torch

# Test basic audio tensor creation
waveform = torch.randn(2, 16000)  # 2-channel, 1 second at 16kHz
print(f'Audio tensor shape: {waveform.shape}')

# Test available backends
print(f'Available audio backends: {torchaudio.list_audio_backends()}')
"
```

## Next Steps

See the full documentation:
- **RECIPE_TEMPLATE.md** - Templates for creating any variant
- **BUILD_MATRIX.md** - Complete build matrix and variant status
- **TEST_GUIDE.md** - Testing procedures (TO CREATE)
- **README.md** - Complete guide and overview

## Common Issues

### Issue: "Package not found"

**Problem:** TorchAudio variant doesn't exist yet.

**Solution:** All 60 variants are now available! Check `BUILD_MATRIX.md` for the complete list.

### Issue: "PyTorch dependency not found"

**Problem:** Matching PyTorch variant doesn't exist in `../build-pytorch/`.

**Solution:** Build the matching PyTorch variant first:
```bash
cd ../build-pytorch
flox build pytorch-python313-cuda12_8-sm120-avx512
cd ../build-torchaudio
flox build torchaudio-python313-cuda12_8-sm120-avx512
```

### Issue: "Wrong GPU pattern"

**Problem:** Created variant using wrong pattern (Type A vs Type B).

**Solution:** Always check PyTorch pattern first:
```bash
grep -E "gpuArchNum|gpuArchSM|gpuTargets" \
  ../build-pytorch/.flox/pkgs/pytorch-python313-cuda12_8-sm{ARCH}-*.nix | head -5
```

Then use the matching pattern for TorchAudio.

## Quick Reference Card

| Architecture | GPU | Pattern | Status | Example Package |
|--------------|-----|---------|--------|-----------------|
| SM121 | DGX Spark | Type A (sm_121) | ✅ Available | `torchaudio-python313-cuda12_8-sm121-avx512` |
| SM120 | RTX 5090 | Type B (12.0) | ✅ Available | `torchaudio-python313-cuda12_8-sm120-avx512` |
| SM110 | DRIVE Thor | Type A (sm_110) | ✅ Available | `torchaudio-python313-cuda12_8-sm110-avx512` |
| SM103 | B300 | Type A (sm_103) | ✅ Available | `torchaudio-python313-cuda12_8-sm103-avx512` |
| SM100 | B100/B200 | Type A (sm_100) | ✅ Available | `torchaudio-python313-cuda12_8-sm100-avx512` |
| SM90 | H100/L40S | Type A (sm_90) | ✅ Available | `torchaudio-python313-cuda12_8-sm90-avx512` |
| SM89 | RTX 4090 | Type A (sm_89) | ✅ Available | `torchaudio-python313-cuda12_8-sm89-avx512` |
| SM86 | RTX 3090 | Type B (8.6) | ✅ Available | `torchaudio-python313-cuda12_8-sm86-avx512` |
| SM80 | A100/A30 | Type A (sm_80) | ✅ Available | `torchaudio-python313-cuda12_8-sm80-avx512` |
| CPU | None | N/A | ✅ Available | `torchaudio-python313-cpu-avx512` |

**Pattern Type A (7 archs):** `gpuArchSM = "sm_XXX"`, `gpuTargets = [ gpuArchSM ]`
**Pattern Type B (2 archs):** `gpuArchNum = "X.Y"`, `gpuTargets = [ gpuArchNum ]` (NO gpuArchSM)
