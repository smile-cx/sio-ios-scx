#!/usr/bin/env python3
"""
Add modification notices to Swift source files.

This ensures compliance with Apache License 2.0 Section 4(b), which requires
that modified files carry prominent notices stating they have been changed.

Usage: python3 add-modification-notices.py <source_dir>
"""

import os
import sys
from pathlib import Path
from typing import List

# Modification notice to add after existing copyright/license headers
MODIFICATION_NOTICE = """//
// MODIFIED by Smile.io: This file has been modified from its original version
// as part of the SCXSocketIO distribution. Modifications include symbol name
// prefixing and related code adjustments. See the NOTICE file for details.
//
"""

# Notice for MIT-licensed files (Socket.IO)
MIT_MODIFICATION_NOTICE = """//
// MODIFIED by Smile.io: This file has been modified from its original version
// as part of the SCXSocketIO distribution. Modifications include symbol name
// prefixing and related code adjustments. See the NOTICE file for details.
//
"""

def find_swift_files(source_dir: str) -> List[Path]:
    """Find all .swift files recursively."""
    path = Path(source_dir)
    if not path.exists():
        print(f"Error: Directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    return sorted(path.rglob("*.swift"))

def has_modification_notice(content: str) -> bool:
    """Check if file already has a modification notice."""
    return "MODIFIED by" in content or "Modified by" in content

def find_header_end(lines: List[str]) -> int:
    """
    Find the end of the file header (copyright/license block).
    Returns the line index after which to insert the modification notice.
    """
    in_header = False
    header_end = 0

    for i, line in enumerate(lines):
        stripped = line.strip()

        # Start of header comment block
        if stripped.startswith('//') and not in_header:
            in_header = True
            continue

        # Inside header block
        if in_header and stripped.startswith('//'):
            header_end = i + 1
            continue

        # End of header block - found first non-comment line
        if in_header and not stripped.startswith('//'):
            # If previous line was empty comment, go back one
            if header_end > 0 and lines[header_end - 1].strip() == '//':
                header_end -= 1
            return header_end

    return header_end

def add_modification_notice_to_file(filepath: Path) -> bool:
    """
    Add modification notice to a Swift file after the existing copyright header.
    Returns True if file was modified, False otherwise.
    """
    try:
        content = filepath.read_text(encoding='utf-8')

        # Skip if already has modification notice
        if has_modification_notice(content):
            return False

        lines = content.splitlines(keepends=True)

        # Find where to insert the notice (after copyright/license header)
        insert_pos = find_header_end(lines)

        if insert_pos == 0:
            # No header found, add at the beginning
            modified_content = MODIFICATION_NOTICE + content
        else:
            # Insert after header
            lines.insert(insert_pos, MODIFICATION_NOTICE)
            modified_content = ''.join(lines)

        filepath.write_text(modified_content, encoding='utf-8')
        return True

    except Exception as e:
        print(f"Error processing {filepath.name}: {e}", file=sys.stderr)
        return False

def main():
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <source_dir>", file=sys.stderr)
        sys.exit(1)

    source_dir = sys.argv[1]

    if not os.path.isdir(source_dir):
        print(f"Error: Directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    swift_files = find_swift_files(source_dir)

    if not swift_files:
        print(f"No Swift files found in {source_dir}")
        return

    modified_count = 0
    skipped_count = 0

    for filepath in swift_files:
        if add_modification_notice_to_file(filepath):
            modified_count += 1
        else:
            skipped_count += 1

    print(f"✓ Added modification notices to {modified_count} files")
    if skipped_count > 0:
        print(f"  Skipped {skipped_count} files (already had notices)")

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"Fatal error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
