# TorchAudio optimized for NVIDIA Blackwell (SM120: RTX 5090) + ARMv9
# Package name: torchaudio-python313-cuda12_8-sm120-armv9

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

  # CPU optimization: ARMv9 with SVE2 and other advanced features
  cpuFlags = [
    "-march=armv9-a+sve2"  # ARMv9 with SVE2 (Scalable Vector Extension 2)
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
    pytorch = customPytorch;
  }).overrideAttrs (oldAttrs: {
    pname = "torchaudio-python313-cuda12_8-sm120-armv9";

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
      echo "CPU Features: ARMv9 + SVE2"
      echo "CUDA: 12.8 (Compute Capability 12.0)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA RTX 5090 (SM120, Blackwell) + ARMv9";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Blackwell architecture (SM120) - RTX 5090
        - CPU: ARMv9 with SVE2 (Scalable Vector Extension 2)
        - CUDA: 12.8
        - Python: 3.13

        Hardware requirements:
        - GPU: RTX 5090, Blackwell architecture GPUs
        - CPU: AWS Graviton3+, NVIDIA Grace, ARM Neoverse V1+
        - Driver: NVIDIA 570+ required

        Choose this if: You have RTX 5090 in ARM-based system with
        latest processors (Graviton3+, Grace Hopper superchip). ARMv9
        with SVE2 provides best performance for ARM platforms.
      '';
      platforms = [ "aarch64-linux" ];
    };
  })
