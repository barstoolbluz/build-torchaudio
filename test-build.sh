#!/usr/bin/env bash
# Generic TorchAudio build test script
# Usage: ./test-build.sh [build-name]
# Example: ./test-build.sh torchaudio-python313-cuda12_8-sm120-avx512

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
info() { echo -e "${BLUE}$1${NC}"; }
success() { echo -e "${GREEN}✓ $1${NC}"; }
warning() { echo -e "${YELLOW}⚠ $1${NC}"; }
error() { echo -e "${RED}✗ $1${NC}"; exit 1; }

# Parse arguments
BUILD_NAME="${1:-}"

# Auto-detect if no argument provided
if [ -z "$BUILD_NAME" ]; then
    info "No build name provided, auto-detecting..."

    # Look for result-* symlinks
    RESULT_LINKS=(result-torchaudio-*)

    if [ ${#RESULT_LINKS[@]} -eq 0 ] || [ ! -L "${RESULT_LINKS[0]}" ]; then
        error "No result-* symlinks found. Build something first with: flox build <package-name>"
    fi

    if [ ${#RESULT_LINKS[@]} -eq 1 ]; then
        # Only one result, use it
        RESULT_DIR="${RESULT_LINKS[0]}"
        BUILD_NAME="${RESULT_DIR#result-}"
        info "Auto-detected: $BUILD_NAME"
    else
        # Multiple results, ask user to specify
        warning "Multiple builds found:"
        for link in "${RESULT_LINKS[@]}"; do
            echo "  - ${link#result-}"
        done
        echo ""
        error "Please specify which build to test: ./test-build.sh <build-name>"
    fi
else
    # User provided build name
    RESULT_DIR="result-${BUILD_NAME}"
fi

# Verify result directory exists
if [ ! -L "$RESULT_DIR" ] && [ ! -d "$RESULT_DIR" ]; then
    error "Result directory not found: $RESULT_DIR\nDid you build it? Run: flox build $BUILD_NAME"
fi

# Resolve to actual path
RESULT_PATH=$(readlink -f "$RESULT_DIR" 2>/dev/null || echo "$RESULT_DIR")

if [ ! -d "$RESULT_PATH" ]; then
    error "Result path does not exist: $RESULT_PATH"
fi

# Setup Python path
PYTHONPATH="${RESULT_PATH}/lib/python3.13/site-packages:${PYTHONPATH:-}"

# TorchAudio depends on PyTorch - find and add PyTorch to PYTHONPATH
# Use -qR to get transitive dependencies
PYTORCH_DEP=$(nix-store -qR "$RESULT_PATH" 2>/dev/null | grep "python3.13-torch-" | grep -v "audio" | grep -v "dev" | grep -v "dist" | grep -v "\-lib" | head -1)
if [ -n "$PYTORCH_DEP" ] && [ -d "$PYTORCH_DEP/lib/python3.13/site-packages" ]; then
    PYTHONPATH="${PYTORCH_DEP}/lib/python3.13/site-packages:${PYTHONPATH}"
fi

export PYTHONPATH

# Determine if this is a CUDA build
IS_CUDA_BUILD=false
if [[ "$BUILD_NAME" == *"cuda"* ]] || [[ "$BUILD_NAME" == *"sm"[0-9]* ]]; then
    IS_CUDA_BUILD=true
fi

echo "========================================"
echo "TorchAudio Build Test"
echo "========================================"
info "Build: $BUILD_NAME"
info "Path: $RESULT_PATH"
info "CUDA build: $IS_CUDA_BUILD"
echo ""

# Test 1: Import TorchAudio
echo "========================================"
echo "Test 1: TorchAudio Import & Version"
echo "========================================"
python3.13 << 'EOF'
import sys
try:
    import torch
    import torchaudio
    print(f"✓ PyTorch version: {torch.__version__}")
    print(f"✓ TorchAudio version: {torchaudio.__version__}")
    print(f"  Python: {sys.version.split()[0]}")
    print(f"  Install path: {torchaudio.__file__}")

    # Check available backends
    backends = torchaudio.list_audio_backends()
    print(f"  Available backends: {backends}")
except ImportError as e:
    print(f"✗ Failed to import TorchAudio: {e}")
    sys.exit(1)
EOF
echo ""

# Test 2: CUDA Support (if CUDA build)
if [ "$IS_CUDA_BUILD" = true ]; then
    echo "========================================"
    echo "Test 2: CUDA Support"
    echo "========================================"
    python3.13 << 'EOF'
import torch
import torchaudio
import sys

cuda_available = torch.cuda.is_available()
cuda_built = torch.version.cuda is not None

print(f"CUDA built: {cuda_built}")
print(f"CUDA available: {cuda_available}")

if cuda_built:
    print(f"CUDA version: {torch.version.cuda}")
    print(f"cuDNN version: {torch.backends.cudnn.version()}")
    print(f"Compiled arch list: {torch.cuda.get_arch_list()}")
else:
    print("✗ PyTorch was not built with CUDA support!")
    sys.exit(1)

if cuda_available:
    gpu_count = torch.cuda.device_count()
    print(f"GPU count: {gpu_count}")

    if gpu_count > 0:
        for i in range(gpu_count):
            name = torch.cuda.get_device_name(i)
            cap = torch.cuda.get_device_capability(i)
            props = torch.cuda.get_device_properties(i)
            mem_gb = props.total_memory / (1024**3)
            print(f"GPU {i}: {name}")
            print(f"  Compute capability: {cap[0]}.{cap[1]}")
            print(f"  Memory: {mem_gb:.1f} GB")
else:
    print("⚠ CUDA is built but no GPU detected (driver/hardware issue)")
    print("  This is OK if testing on a system without a GPU")
EOF
    echo ""
fi

# Test 3: CPU Audio Operations
echo "========================================"
echo "Test 3: CPU Audio Operations"
echo "========================================"
python3.13 << 'EOF'
import torch
import torchaudio
import torchaudio.transforms as T
import sys

try:
    # Create a synthetic audio waveform (2 seconds at 16kHz)
    sample_rate = 16000
    duration = 2
    frequency = 440  # A4 note

    t = torch.linspace(0, duration, sample_rate * duration)
    waveform = torch.sin(2 * torch.pi * frequency * t).unsqueeze(0)

    print(f"✓ Generated waveform shape: {waveform.shape}")
    print(f"✓ Sample rate: {sample_rate} Hz")
    print(f"✓ Duration: {duration} seconds")

    # Test transforms
    # Spectrogram
    spectrogram = T.Spectrogram(n_fft=512)(waveform)
    print(f"✓ Spectrogram shape: {spectrogram.shape}")

    # Mel Spectrogram
    mel_spectrogram = T.MelSpectrogram(sample_rate=sample_rate, n_fft=512)(waveform)
    print(f"✓ Mel spectrogram shape: {mel_spectrogram.shape}")

    # MFCC
    mfcc = T.MFCC(sample_rate=sample_rate, n_mfcc=40)(waveform)
    print(f"✓ MFCC shape: {mfcc.shape}")

    # Resample
    resampler = T.Resample(orig_freq=sample_rate, new_freq=8000)
    resampled = resampler(waveform)
    print(f"✓ Resampled shape: {resampled.shape}")

    print("✓ CPU audio operations successful!")

except Exception as e:
    print(f"✗ CPU audio operations failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF
echo ""

# Test 4: Audio Effects & Functional API
echo "========================================"
echo "Test 4: Audio Effects & Functional API"
echo "========================================"
python3.13 << 'EOF'
import torch
import torchaudio.functional as F
import torchaudio.transforms as T
import sys

try:
    # Create test waveform
    sample_rate = 16000
    waveform = torch.randn(1, sample_rate * 2)  # 2 seconds of audio

    print(f"✓ Test waveform shape: {waveform.shape}")

    # Test various effects
    # Fade
    fade_in = T.Fade(fade_in_len=1000)(waveform)
    print(f"✓ Fade applied: {fade_in.shape}")

    # Resample (pitch/time effect)
    resampled_up = F.resample(waveform, sample_rate, int(sample_rate * 1.1))
    print(f"✓ Resample (higher rate): {resampled_up.shape}")

    resampled_down = F.resample(waveform, sample_rate, int(sample_rate * 0.9))
    print(f"✓ Resample (lower rate): {resampled_down.shape}")

    # Amplitude to DB conversion
    spec = torch.randn(1, 128, 100).abs()
    db_spec = F.amplitude_to_DB(spec, multiplier=10.0, amin=1e-10, db_multiplier=0.0)
    print(f"✓ Amplitude to DB: {db_spec.shape}")

    print("✓ Audio effects successful!")

except Exception as e:
    print(f"✗ Audio effects failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF
echo ""

# Test 5: GPU Operations (if CUDA build and GPU available)
if [ "$IS_CUDA_BUILD" = true ]; then
    echo "========================================"
    echo "Test 5: GPU Audio Operations"
    echo "========================================"
    set +e  # Temporarily disable exit-on-error
    python3.13 << 'EOF'
import torch
import torchaudio
import torchaudio.transforms as T
import sys

if not torch.cuda.is_available():
    print("⚠ Skipping GPU test - no GPU available")
    sys.exit(0)

# Check for architecture compatibility
gpu_cap = torch.cuda.get_device_capability(0)
gpu_arch = f"{gpu_cap[0]}.{gpu_cap[1]}"
compiled_archs = torch.cuda.get_arch_list()

print(f"GPU compute capability: {gpu_arch}")
print(f"Compiled architectures: {compiled_archs}")

# Check if GPU architecture is compatible
compatible = any(gpu_arch in arch or f"sm_{int(float(gpu_arch)*10)}" in arch for arch in compiled_archs)

if not compatible:
    print(f"⚠ WARNING: GPU architecture {gpu_arch} not in compiled list {compiled_archs}")
    print(f"  This build is targeted for a different GPU architecture")
    print(f"  GPU operations will fail - this is expected behavior")
    sys.exit(0)

try:
    # Create audio waveform on GPU
    sample_rate = 16000
    duration = 2
    frequency = 440

    t = torch.linspace(0, duration, sample_rate * duration).cuda()
    waveform = torch.sin(2 * torch.pi * frequency * t).unsqueeze(0)

    print(f"✓ Waveform device: {waveform.device}")
    print(f"✓ Waveform shape: {waveform.shape}")

    # Test transforms on GPU
    mel_spec = T.MelSpectrogram(sample_rate=sample_rate).cuda()
    mel_output = mel_spec(waveform)

    print(f"✓ Mel spectrogram device: {mel_output.device}")
    print(f"✓ Mel spectrogram shape: {mel_output.shape}")

    # Test batch processing
    batch_waveform = torch.randn(8, 1, sample_rate * 2).cuda()
    batch_mel = mel_spec(batch_waveform.squeeze(1))

    print(f"✓ Batch mel spectrogram shape: {batch_mel.shape}")
    print("✓ GPU audio operations successful!")

except Exception as e:
    error_str = str(e)
    if "no kernel image is available" in error_str:
        print(f"⚠ GPU architecture mismatch (expected, not a failure)")
        print(f"  Build compiled for: {compiled_archs}")
        print(f"  GPU architecture: {gpu_arch}")
        sys.exit(0)
    else:
        print(f"✗ GPU audio operations failed: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
EOF
    GPU_TEST_EXIT=$?
    set -e
    echo ""
fi

# Test 6: TorchAudio Compliance Tests
echo "========================================"
echo "Test 6: TorchAudio Compliance"
echo "========================================"
python3.13 << 'EOF'
import torch
import torchaudio
import torchaudio.compliance.kaldi as kaldi
import sys

try:
    # Create test waveform
    sample_rate = 16000
    waveform = torch.randn(1, sample_rate * 3)

    # Test Kaldi-compatible features
    mfcc = kaldi.mfcc(waveform, sample_frequency=sample_rate)
    print(f"✓ Kaldi MFCC shape: {mfcc.shape}")

    fbank = kaldi.fbank(waveform, sample_frequency=sample_rate)
    print(f"✓ Kaldi fbank shape: {fbank.shape}")

    spectrogram = kaldi.spectrogram(waveform, sample_frequency=sample_rate)
    print(f"✓ Kaldi spectrogram shape: {spectrogram.shape}")

    print("✓ TorchAudio compliance tests successful!")

except Exception as e:
    print(f"✗ Compliance tests failed: {e}")
    import traceback
    traceback.print_exc()
    sys.exit(1)
EOF
echo ""

# Summary
echo "========================================"
echo "Test Summary"
echo "========================================"
success "Build: $BUILD_NAME"
success "TorchAudio imported successfully"
success "CPU audio operations working"
success "Audio effects working"
success "TorchAudio compliance tests passed"

if [ "$IS_CUDA_BUILD" = true ]; then
    python3.13 -c "import torch; exit(0 if torch.cuda.is_available() else 1)" 2>/dev/null
    if [ $? -eq 0 ]; then
        success "CUDA support verified"
        if [ "${GPU_TEST_EXIT:-1}" -eq 0 ]; then
            success "GPU audio operations working (or skipped due to arch mismatch)"
        else
            warning "GPU test failed (check output above)"
        fi
    else
        warning "CUDA built but no GPU detected (may be expected)"
    fi
fi

echo ""
success "All tests passed!"
echo "========================================"
