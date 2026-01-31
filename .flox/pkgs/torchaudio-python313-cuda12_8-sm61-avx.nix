# TorchAudio optimized for NVIDIA Pascal GTX 1070/1080 Ti (SM61) + AVX
# Package name: torchaudio-python313-cuda12_8-sm61-avx

{ pkgs ? import <nixpkgs> {} }:

let
  # Import nixpkgs at a specific revision where PyTorch 2.8.0 and TorchAudio 2.8.0 are compatible
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };

  # GPU target: SM61 (Pascal consumer - GTX 1070, 1080, 1080 Ti)
  gpuArchNum = "61";
  gpuArchSM = "6.1";  # Dot notation required for older archs in TORCH_CUDA_ARCH_LIST

  # CPU optimization: AVX only (Ivy Bridge lacks FMA3, BMI1, BMI2, AVX2)
  cpuFlags = [
    "-mavx"
    "-mno-fma"
    "-mno-bmi"
    "-mno-bmi2"
    "-mno-avx2"
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  customPytorch = (nixpkgs_pinned.python3Packages.torch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
  }).overrideAttrs (oldAttrs: {
    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    # Prevent ATen from compiling AVX2/AVX512 dispatch kernels.
    # FindAVX.cmake probe-compiles with -mavx2 and succeeds (the compiler
    # supports it), then Codegen.cmake force-compiles kernel TUs with -mavx2
    # regardless of project CXXFLAGS.  Lying to cmake here restricts the
    # dispatch codegen to AVX + baseline only.
    cmakeFlags = (oldAttrs.cmakeFlags or []) ++ [
      "-DCXX_AVX2_FOUND=FALSE"
      "-DC_AVX2_FOUND=FALSE"
      "-DCXX_AVX512_FOUND=FALSE"
      "-DC_AVX512_FOUND=FALSE"
      "-DCAFFE2_COMPILER_SUPPORTS_AVX512_EXTENSIONS=OFF"
    ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      # cuDNN 9.11+ dropped SM < 7.5 support — disable for SM61
      export USE_CUDNN=0
      # FBGEMM hard-requires AVX2 with no fallback — disable entirely
      export USE_FBGEMM=0
      # oneDNN/MKLDNN compiles AVX2/AVX512 dispatch variants internally
      export USE_MKLDNN=0
      export USE_MKLDNN_CBLAS=0
      # Force NNPACK to portable SIMD backend
      export NNPACK_BACKEND=psimd
    '';
  });

in
  (nixpkgs_pinned.python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm61-avx";

    # Limit build parallelism to prevent memory saturation
    ninjaFlags = [ "-j32" ];
    requiredSystemFeatures = [ "big-parallel" ];

    preConfigure = (oldAttrs.preConfigure or "") + ''
      export CXXFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CXXFLAGS"
      export CFLAGS="${nixpkgs_pinned.lib.concatStringsSep " " cpuFlags} $CFLAGS"
      export MAX_JOBS=32

      echo "========================================="
      echo "TorchAudio Build Configuration"
      echo "========================================="
      echo "GPU Target: ${gpuArchSM} (Pascal: GTX 1070, 1080, 1080 Ti)"
      echo "CPU Features: AVX (maximum compatibility)"
      echo "CUDA: Enabled (cuDNN disabled — SM61 unsupported by cuDNN 9.11+)"
      echo "FBGEMM: Disabled (requires AVX2)"
      echo "MKLDNN: Disabled (AVX2/AVX512 dispatch)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for GTX 1070/1080 Ti (SM61, Pascal) with AVX";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Pascal consumer architecture (SM61) - GTX 1070, 1080, 1080 Ti
        - CPU: x86-64 with AVX instruction set (maximum compatibility)
        - CUDA: 12.8 with compute capability 6.1
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: GTX 1070, 1080, 1080 Ti, or other SM61 GPUs
        - CPU: Intel Sandy Bridge+ (2011+), AMD Bulldozer+ (2011+)
        - Driver: NVIDIA 390+ required

        Note: cuDNN is disabled because cuDNN 9.11+ dropped SM < 7.5 support.
        FBGEMM, MKLDNN, and ATen AVX2/AVX512 dispatch are also disabled to
        prevent illegal-instruction crashes on AVX-only CPUs.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
