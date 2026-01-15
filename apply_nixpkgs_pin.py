#!/usr/bin/env python3
"""
Apply the nixpkgs pinning fix to all TorchAudio nix expressions.
This ensures PyTorch 2.8.0 and TorchAudio 2.8.0 compatibility.
"""

import os
import glob
import re

# The pinned nixpkgs configuration to insert
NIXPKGS_CONFIG = """  # Import nixpkgs at a specific revision where PyTorch 2.8.0 and TorchAudio 2.8.0 are compatible
  nixpkgs_pinned = import (builtins.fetchTarball {
    url = "https://github.com/NixOS/nixpkgs/archive/fe5e41d7ffc0421f0913e8472ce6238ed0daf8e3.tar.gz";
    # You can add the sha256 here once known for reproducibility
  }) {
    config = {
      allowUnfree = true;  # Required for CUDA packages
      cudaSupport = true;
    };
  };"""

def update_nix_file(filepath):
    """Update a single nix file to use pinned nixpkgs."""
    with open(filepath, 'r') as f:
        content = f.read()

    # Check if already updated
    if 'nixpkgs_pinned' in content:
        print(f"✓ Already updated: {os.path.basename(filepath)}")
        return False

    # Replace the function signature to accept pkgs
    content = re.sub(
        r'^\{ python3Packages\n, lib\n, config\n, cudaPackages\n, addDriverRunpath\n(, fetchPypi)?\n\}:',
        '{ pkgs ? import <nixpkgs> {} }:',
        content,
        flags=re.MULTILINE
    )

    # Add the let block with nixpkgs_pinned
    content = re.sub(
        r'(\nlet\n)',
        r'\1' + NIXPKGS_CONFIG + '\n\n',
        content
    )

    # Replace all python3Packages references with nixpkgs_pinned.python3Packages
    content = re.sub(r'\bpython3Packages\.', 'nixpkgs_pinned.python3Packages.', content)

    # Replace lib references with nixpkgs_pinned.lib
    content = re.sub(r'\blib\.', 'nixpkgs_pinned.lib.', content)

    # Write back the updated content
    with open(filepath, 'w') as f:
        f.write(content)

    print(f"✅ Updated: {os.path.basename(filepath)}")
    return True

def main():
    """Update all TorchAudio nix expressions."""
    nix_files = glob.glob('/home/daedalus/dev/builds/build-torchaudio/.flox/pkgs/*.nix')

    updated = 0
    already_updated = 0

    for filepath in sorted(nix_files):
        if update_nix_file(filepath):
            updated += 1
        else:
            already_updated += 1

    print(f"\n📊 Summary:")
    print(f"  Updated: {updated}")
    print(f"  Already updated: {already_updated}")
    print(f"  Total files: {len(nix_files)}")

if __name__ == "__main__":
    main()