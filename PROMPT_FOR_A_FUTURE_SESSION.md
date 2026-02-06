# Future Session: Refactor TorchAudio Build Recipes

## Objective

1. **Refactor** all TorchAudio build recipes to use the working three-overlay pattern
2. **Create** SM120 x86 variants to align with PyTorch/TorchVision

## Background

All existing TorchAudio variants are using:
- Old nixpkgs pin (`fe5e41d7...`) without CUDA 13.0 fixes
- No MAGMA patch overlay
- No PyTorch 2.10.0 upgrade overlay

They need to be updated to the three-overlay pattern:
- Overlay 1: CUDA 13.0 (`cudaPackages = final.cudaPackages_13`)
- Overlay 2: MAGMA patch for CUDA 13.0 (`cuda-13.0-clockrate-fix.patch`)
- Overlay 3: PyTorch 2.10.0 source upgrade

## Cleanup Completed

**8 invalid files were deleted** (SM110/SM121 paired with x86 ISAs - impossible combinations):
- SM110 (DRIVE Thor) is an ARM-based automotive platform
- SM121 (DGX Spark) uses the ARM-based Grace CPU (Neoverse V2)

Deleted files:
- `torchaudio-python313-cuda13_0-sm110-avx2.nix`
- `torchaudio-python313-cuda13_0-sm110-avx512.nix`
- `torchaudio-python313-cuda13_0-sm110-avx512bf16.nix`
- `torchaudio-python313-cuda13_0-sm110-avx512vnni.nix`
- `torchaudio-python313-cuda13_0-sm121-avx2.nix`
- `torchaudio-python313-cuda13_0-sm121-avx512.nix`
- `torchaudio-python313-cuda13_0-sm121-avx512bf16.nix`
- `torchaudio-python313-cuda13_0-sm121-avx512vnni.nix`

## Files to Refactor

### Valid ARM Variants (4 files)

These need the three-overlay pattern:

| File | GPU Target | CPU ISA | Platform |
|------|------------|---------|----------|
| `torchaudio-python313-cuda13_0-sm110-armv8_2.nix` | SM110 (DRIVE Thor) | ARMv8.2 | aarch64-linux |
| `torchaudio-python313-cuda13_0-sm110-armv9.nix` | SM110 (DRIVE Thor) | ARMv9 | aarch64-linux |
| `torchaudio-python313-cuda13_0-sm121-armv8_2.nix` | SM121 (DGX Spark) | ARMv8.2 | aarch64-linux |
| `torchaudio-python313-cuda13_0-sm121-armv9.nix` | SM121 (DGX Spark) | ARMv9 | aarch64-linux |

## New Variants to Create

SM120 (RTX 5090) x86 variants to align with PyTorch/TorchVision:

| Variant | GPU Target | CPU ISA | Platform | Notes |
|---------|------------|---------|----------|-------|
| `sm120-avx` | SM120 (RTX 5090) | AVX | x86_64-linux | Broader x86 compatibility |
| `sm120-avx512` | SM120 (RTX 5090) | AVX-512 | x86_64-linux | Primary x86 variant |

## Reference Implementation

Use TorchVision's working variants as reference:
- **x86 reference**: `/home/daedalus/dev/builds/build-torchvision/.flox/pkgs/torchvision-python313-cuda13_0-sm120-avx512.nix`
- **ARM reference**: `/home/daedalus/dev/builds/build-torchvision/.flox/pkgs/torchvision-python313-cuda13_0-sm121-armv9.nix`

### Key Elements to Add

1. **Nixpkgs pin**: `6a030d535719c5190187c4cec156f335e95e3211`
2. **Three overlays**:
   - Overlay 1: `cudaPackages = final.cudaPackages_13`
   - Overlay 2: MAGMA patch for CUDA 13.0 (`cuda-13.0-clockrate-fix.patch`)
   - Overlay 3: PyTorch 2.10.0 source upgrade
3. **customPytorch with all CUDA 13.0 fixes**:
   - CMake flags: `-DTORCH_BUILD_VERSION=2.10.0`, `-DCMAKE_CUDA_FLAGS=-I/build/cccl-compat`, `-DCUDA_VERSION=13.0`
   - preConfigure: Version fixes, CCCL symlink structure
   - postPatch: FindCUDAToolkit.cmake delegating stub
4. **TorchAudio override**: `torchaudio.override { torch = customPytorch }`

## Post-Refactor Documentation Updates

After refactoring is complete:

1. **Create `/home/daedalus/dev/builds/build-torchaudio/docs/` directory**

2. **Create `docs/torchaudio-cuda13-build-notes.md`**
   - Document the three-overlay pattern
   - List all available variants
   - Include verification steps

3. **Update `/home/daedalus/dev/builds/build-torchaudio/README.md`**
   - Document all available build variants
   - Add build instructions for each target

## Verification

After refactoring each variant:
1. Check for MAGMA patch overlay: `grep 'cuda-13.0-clockrate-fix.patch' <file>`
2. Check for old MAGMA-disable code: `grep -E 'filterMagma|USE_MAGMA=OFF|USE_MAGMA=0' <file>` (should return nothing)
3. Verify nixpkgs pin: `grep '6a030d535719c5190187c4cec156f335e95e3211' <file>`
4. Verify MAGMA enabled in echo: `grep 'MAGMA.*Enabled' <file>`
5. Build test (if hardware available): `flox build <package-name>`

## Alignment with PyTorch and TorchVision

### Valid GPU + CPU Combinations

| GPU | CPU ISA | PyTorch | TorchVision | TorchAudio | Notes |
|-----|---------|---------|-------------|------------|-------|
| SM110 | ARMv8.2 | ✓ (refactor) | ✓ | ✓ (refactor) | Valid ARM combo |
| SM110 | ARMv9 | ✓ (refactor) | ✓ | ✓ (refactor) | Valid ARM combo |
| SM120 | AVX | ✓ (refactor) | create | **create** | Broader x86 compat |
| SM120 | AVX-512 | ✓ | ✓ | **create** | Primary x86 variant |
| SM121 | ARMv8.2 | create | ✓ | ✓ (refactor) | Valid ARM combo |
| SM121 | ARMv9 | create | ✓ | ✓ (refactor) | Valid ARM combo |
