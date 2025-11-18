# TorchAudio optimized for NVIDIA Blackwell (SM120: RTX 5090) + AVX-512 BF16
# Package name: torchaudio-python313-cuda12_8-sm120-avx512bf16

{ python3Packages
, lib
, config
, cudaPackages
, addDriverRunpath
, fetchPypi
}:

let
  # GPU target: SM120 (Blackwell architecture - RTX 5090)
  # PyTorch's CMake accepts numeric format (12.0) not sm_120
  gpuArchNum = "12.0";

  # CPU optimization: AVX-512 with BF16 support
  cpuFlags = [
    "-mavx512f"    # AVX-512 Foundation
    "-mavx512dq"   # Doubleword and Quadword instructions
    "-mavx512vl"   # Vector Length extensions
    "-mavx512bw"   # Byte and Word instructions
    "-mavx512bf16" # BF16 (Brain Float16) instructions
    "-mfma"        # Fused multiply-add
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
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
  (python3Packages.torchaudio.override {
    torch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm120-avx512bf16";

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
      echo "CPU Features: AVX-512 + BF16"
      echo "CUDA: 12.8 (Compute Capability 12.0)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 5090 (SM120, Blackwell) + AVX-512 BF16";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell architecture (SM120) - RTX 5090
        - CPU: x86-64 with AVX-512 + BF16 instruction set
        - CUDA: 12.8
        - Python: 3.13

        Hardware requirements:
        - GPU: RTX 5090, Blackwell architecture GPUs
        - CPU: Intel Sapphire Rapids+ (2023+), AMD Genoa+ (2022+)
        - Driver: NVIDIA 570+ required

        Choose this if: You have RTX 5090 with latest datacenter CPUs and
        need BF16 training acceleration. BF16 provides better numerical
        stability than FP16 for training workloads.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
