# TorchAudio optimized for NVIDIA Ampere RTX 3090/A40 (SM86) + ARMv9
# Package name: torchaudio-python313-cuda12_8-sm86-armv9

{ python3Packages
, lib
, config
, cudaPackages
, addDriverRunpath
, fetchPypi
}:

let
  # GPU target: SM86 (Ampere RTX 3090/A40)
  gpuArchNum = "8.6";

  # CPU optimization: ARMv9 with SVE and SVE2
  cpuFlags = [
    "-march=armv9-a+sve+sve2"  # ARMv9 with Scalable Vector Extensions
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
    pname = "torchaudio-python313-cuda12_8-sm86-armv9";

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
      echo "GPU Target: SM86 (Ampere RTX 3090/A40)"
      echo "CPU Features: ARMv9 + SVE + SVE2"
      echo "CUDA: 12.8 (Compute Capability 8.6)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA Ampere RTX 3090/A40 (SM86) + ARMv9";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Ampere RTX 3090/A40 (SM86)
        - CPU: ARMv9 with Scalable Vector Extensions (SVE/SVE2)
        - CUDA: 12.8 with compute capability 8.6
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: NVIDIA RTX 3090, RTX 3080 Ti, A5000, A40
        - CPU: AWS Graviton3+, NVIDIA Grace Hopper
        - Driver: NVIDIA 470+ required

        Maximum performance for next-gen ARM with Ampere GPUs.
      '';
      platforms = [ "aarch64-linux" ];
    };
  })
