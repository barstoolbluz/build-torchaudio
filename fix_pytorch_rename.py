#!/usr/bin/env python3
"""
Fix pytorch to torch rename in all TorchAudio nix expressions.
"""

import os
import glob
import re

def fix_pytorch_rename(filepath):
    """Fix pytorch to torch rename in a single file."""
    with open(filepath, 'r') as f:
        content = f.read()

    # Replace python3Packages.pytorch with python3Packages.torch
    original_content = content
    content = re.sub(r'python3Packages\.pytorch', 'python3Packages.torch', content)

    if content != original_content:
        with open(filepath, 'w') as f:
            f.write(content)
        print(f"✅ Fixed: {os.path.basename(filepath)}")
        return True
    else:
        print(f"✓ No changes needed: {os.path.basename(filepath)}")
        return False

def main():
    """Fix all TorchAudio nix expressions."""
    nix_files = glob.glob('/home/daedalus/dev/builds/build-torchaudio/.flox/pkgs/*.nix')

    fixed = 0
    unchanged = 0

    for filepath in sorted(nix_files):
        if fix_pytorch_rename(filepath):
            fixed += 1
        else:
            unchanged += 1

    print(f"\n📊 Summary:")
    print(f"  Fixed: {fixed}")
    print(f"  Unchanged: {unchanged}")
    print(f"  Total files: {len(nix_files)}")

if __name__ == "__main__":
    main()