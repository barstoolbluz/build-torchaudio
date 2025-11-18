# TorchAudio optimized for NVIDIA Blackwell (SM120: RTX 5090) + AVX-512
# Package name: torchaudio-python313-cuda12_8-sm120-avx512

{ python3Packages
, lib
, config
, cudaPackages
, addDriverRunpath
, fetchPypi
}:

let
  # GPU target: SM120 (Blackwell architecture - RTX 5090)
  gpuArchNum = "12.0";

  # CPU optimization: AVX-512
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mfma"        # Fused multiply-add
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  # For now, using nixpkgs pytorch with similar configuration
  customPytorch = (python3Packages.pytorch.override {
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
  # Override torchaudio to use our custom pytorch
  (python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm120-avx512";

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
      echo "GPU Target: SM120 (Blackwell: RTX 5090)"
      echo "CPU Features: AVX-512"
      echo "CUDA: 12.8 (Compute Capability 12.0)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 5090 (SM120, Blackwell) + AVX-512";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell architecture (SM120) - RTX 5090
        - CPU: x86-64 with AVX-512 instruction set
        - CUDA: 12.8 with compute capability 12.0
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: RTX 5090, Blackwell architecture GPUs
        - CPU: Intel Skylake-X+ (2017+), AMD Zen 4+ (2022+)
        - Driver: NVIDIA 570+ required

        NOTE: This package depends on a matching PyTorch variant.
        Ensure pytorch-python313-cuda12_8-sm120-avx512 is installed.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
