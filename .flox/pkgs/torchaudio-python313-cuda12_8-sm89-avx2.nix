# TorchAudio optimized for NVIDIA Ada Lovelace RTX 4090/L40 (SM89) + AVX2
# Package name: torchaudio-python313-cuda12_8-sm89-avx2

{ python3Packages
, lib
, config
, cudaPackages
, addDriverRunpath
, fetchPypi
}:

let
  # GPU target: SM89 (Ada Lovelace RTX 4090/L40)
  gpuArchNum = "89";        # For CMAKE_CUDA_ARCHITECTURES (just the integer)
  gpuArchSM = "sm_89";      # For TORCH_CUDA_ARCH_LIST (with sm_ prefix)

  # CPU optimization: AVX2 (broader compatibility)
  cpuFlags = [
    "-mavx2"   # AVX2 instruction set
    "-mfma"    # Fused multiply-add
  ];

  # Custom PyTorch with matching GPU/CPU configuration
  # TODO: Reference the actual pytorch package from build-pytorch
  customPytorch = (python3Packages.pytorch.override {
    cudaSupport = true;
    gpuTargets = [ gpuArchSM ];
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
    pname = "torchaudio-python313-cuda12_8-sm89-avx2";

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
      echo "GPU Target: SM89 (Ada Lovelace RTX 4090/L40)"
      echo "CPU Features: AVX2"
      echo "CUDA: 12.8 (Compute Capability 8.9)"
      echo "CXXFLAGS: $CXXFLAGS"
      echo "Build parallelism: 32 cores max"
      echo "========================================="
    '';

    meta = oldAttrs.meta // {
      description = "TorchAudio for NVIDIA Ada Lovelace RTX 4090/L40 (SM89) + AVX2";
      longDescription = ''
        Custom TorchAudio build with targeted optimizations:
        - GPU: NVIDIA Ada Lovelace RTX 4090/L40 (SM89)
        - CPU: x86-64 with AVX2 instruction set
        - CUDA: 12.8 with compute capability 8.9
        - Python: 3.13
        - PyTorch: Custom build with matching GPU/CPU configuration

        Hardware requirements:
        - GPU: NVIDIA RTX 4090, RTX 4080, L40
        - CPU: Intel Haswell+ (2013+), AMD Excavator+ (2015+)
        - Driver: NVIDIA 525+ required

        Broad CPU compatibility with Ada Lovelace GPU performance.
      '';
      platforms = [ "x86_64-linux" ];
    };
  })
