#!/usr/bin/env python3
"""
Prefix all Swift type declarations and their usages across source files.

Usage: python3 prefix-symbols.py <source_dir> <prefix> [--dry-run] [--apply-to <other_dir>]

This script modifies third-party source code by prefixing symbol names.
This constitutes a modification under both MIT and Apache 2.0 licenses.
Ensure proper attribution and license preservation per LICENSE and NOTICE files.

This script:
1. Scans all .swift files for type declarations (class, struct, enum, protocol, actor, typealias)
2. Builds a rename map: OriginalName -> PREFIXOriginalName
3. Applies renames using whole-word matching to avoid partial replacements
4. Skips system/Foundation types and already-prefixed symbols
"""

import os
import re
import sys
from pathlib import Path
from typing import Dict, Set, List
from collections import defaultdict

# Types from Foundation/Swift stdlib that must NEVER be prefixed
SYSTEM_TYPES = frozenset([
    # Swift stdlib
    "String", "Int", "Int8", "Int16", "Int32", "Int64",
    "UInt", "UInt8", "UInt16", "UInt32", "UInt64",
    "Bool", "Double", "Float", "Float16", "Float80",
    "Character", "Unicode", "Substring",
    "Array", "Dictionary", "Set", "Optional", "Result",
    "Error", "Never", "Void", "Any", "AnyObject", "AnyClass",
    "Codable", "Decodable", "Encodable", "Hashable", "Equatable",
    "Comparable", "Identifiable", "Sendable", "CustomStringConvertible",
    "CustomDebugStringConvertible", "CaseIterable", "RawRepresentable",
    "ExpressibleByStringLiteral", "ExpressibleByIntegerLiteral",
    "ExpressibleByFloatLiteral", "ExpressibleByBooleanLiteral",
    "ExpressibleByNilLiteral", "ExpressibleByArrayLiteral",
    "ExpressibleByDictionaryLiteral", "LosslessStringConvertible",
    "Sequence", "Collection", "IteratorProtocol", "RandomAccessCollection",
    "BidirectionalCollection", "MutableCollection", "LazySequence",
    "Range", "ClosedRange", "CountableRange", "CountableClosedRange",
    "UUID", "Date", "Data", "URL", "URLRequest", "URLResponse",
    "URLSession", "URLSessionTask", "URLSessionDataTask",
    "URLSessionWebSocketTask", "URLSessionConfiguration",
    "URLComponents", "URLQueryItem",
    # Foundation
    "NSObject", "NSCoding", "NSSecureCoding", "NSCopying",
    "NSError", "NSException", "NSLock", "NSRecursiveLock",
    "NSNotification", "NotificationCenter", "NSNotificationName",
    "Timer", "NSTimer", "RunLoop",
    "DispatchQueue", "DispatchGroup", "DispatchSemaphore",
    "DispatchWorkItem", "DispatchSource", "DispatchTime",
    "OperationQueue", "Operation", "BlockOperation",
    "OutputStream", "InputStream", "Stream",
    "JSONEncoder", "JSONDecoder", "JSONSerialization",
    "PropertyListEncoder", "PropertyListDecoder",
    "DateFormatter", "NumberFormatter", "ISO8601DateFormatter",
    "TimeInterval", "TimeZone", "Calendar", "Locale",
    "FileManager", "FileHandle", "Bundle",
    "ProcessInfo", "Thread",
    "UserDefaults", "HTTPURLResponse", "HTTPCookie",
    "Notification", "NSNull",
    # Security/Network
    "SecTrust", "SecCertificate", "SecIdentity", "SecKey", "SecPolicy",
    "SSLContext", "NWEndpoint", "NWConnection", "NWListener",
    "NWParameters", "NWProtocolOptions",
    # CoreFoundation
    "CFString", "CFData", "CFURL", "CFArray", "CFDictionary",
    "CFHTTPMessage", "CFReadStream", "CFWriteStream", "CFStreamError",
    # Combine
    "Published", "ObservableObject", "AnyCancellable",
    "PassthroughSubject", "CurrentValueSubject", "AnyPublisher",
    # SwiftUI
    "ObservedObject", "StateObject", "EnvironmentObject",
    # Concurrency
    "Task", "TaskGroup", "TaskPriority", "AsyncStream",
    "AsyncThrowingStream", "CheckedContinuation", "UnsafeContinuation",
    "MainActor", "GlobalActor", "Actor",
    # zlib / Compression
    "Adler32", "Crc32",
    # Common protocols used as constraints
    "Strideable", "Numeric", "SignedNumeric", "FloatingPoint",
    "BinaryInteger", "FixedWidthInteger", "UnsignedInteger", "SignedInteger",
    "StringProtocol", "TextOutputStream", "TextOutputStreamable",
    # Associated types from Collection/Sequence protocols (used in where clauses)
    "Element", "Index", "SubSequence", "Indices", "Iterator",
    "Key", "Value",
])

# Pattern to match type declarations
DECL_PATTERN = re.compile(
    r'(?:^|\n)\s*'
    r'(?:(?:public|open|internal|private|fileprivate|package)\s+)?'
    r'(?:(?:final|static|indirect|nonisolated)\s+)*'
    r'(?:class|struct|enum|protocol|actor|typealias)\s+'
    r'([A-Z][a-zA-Z0-9_]*)',
    re.MULTILINE
)


def validate_prefix(prefix: str) -> None:
    """Validate that prefix is suitable for Swift type names."""
    if not prefix:
        print("Error: Prefix cannot be empty", file=sys.stderr)
        sys.exit(1)

    if not prefix[0].isupper():
        print(f"Error: Prefix '{prefix}' must start with an uppercase letter", file=sys.stderr)
        sys.exit(1)

    if not re.match(r'^[A-Z][a-zA-Z0-9]*$', prefix):
        print(f"Error: Prefix '{prefix}' must contain only alphanumeric characters", file=sys.stderr)
        sys.exit(1)

    if len(prefix) > 10:
        print(f"Warning: Prefix '{prefix}' is quite long ({len(prefix)} chars)", file=sys.stderr)


def find_swift_files(source_dir: str) -> List[Path]:
    """Find all .swift files recursively."""
    path = Path(source_dir)
    if not path.exists():
        print(f"Error: Directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    if not path.is_dir():
        print(f"Error: Not a directory: {source_dir}", file=sys.stderr)
        sys.exit(1)

    files = sorted(path.rglob("*.swift"))
    return files


def extract_symbols(swift_files: List[Path]) -> Set[str]:
    """Extract all type declaration names from Swift files."""
    symbols = set()
    errors = []

    for filepath in swift_files:
        try:
            content = filepath.read_text(encoding='utf-8')
            for match in DECL_PATTERN.finditer(content):
                name = match.group(1)
                if name not in SYSTEM_TYPES:
                    symbols.add(name)
        except UnicodeDecodeError:
            errors.append(f"  ⚠ Failed to read (encoding issue): {filepath.name}")
        except IOError as e:
            errors.append(f"  ⚠ Failed to read: {filepath.name} ({e})")

    if errors:
        print("\nWarnings during symbol extraction:", file=sys.stderr)
        for err in errors:
            print(err, file=sys.stderr)

    return symbols


def rename_symbols_in_content(content: str, rename_map: Dict[str, str],
                              own_types: Set[str]) -> tuple[str, int]:
    """
    Apply symbol renames using whole-word boundary matching.

    Sorts by length descending to avoid partial replacements
    (e.g., "SocketEngine" before "Socket").

    When a symbol appears after a dot (e.g. Foo.Event), it checks whether
    the qualifier before the dot is one of OUR types or a system type:
    - OurType.Event  -> SCXOurType.SCXEvent  (rename)
    - Stream.Event   -> Stream.Event         (keep)

    Returns: (modified_content, replacement_count)
    """
    # Sort by length descending so longer names are replaced first
    sorted_names = sorted(rename_map.keys(), key=len, reverse=True)
    total_replacements = 0

    for old_name in sorted_names:
        new_name = rename_map[old_name]
        pattern = re.compile(r'\b' + re.escape(old_name) + r'\b')

        def make_replacer(new_name_val):
            def replacer(match):
                nonlocal total_replacements
                start = match.start()
                text = match.string
                # Check if preceded by a dot (member access)
                if start > 0 and text[start - 1] == '.':
                    # Walk backwards past the dot to find the qualifier word
                    dot_pos = start - 1
                    word_end = dot_pos
                    word_start = word_end
                    while word_start > 0 and (text[word_start - 1].isalnum() or text[word_start - 1] == '_'):
                        word_start -= 1
                    qualifier = text[word_start:word_end]
                    # Only rename if the qualifier is one of our own types
                    if qualifier in own_types:
                        total_replacements += 1
                        return new_name_val
                    else:
                        return match.group(0)  # system type, don't rename
                total_replacements += 1
                return new_name_val
            return replacer

        content = pattern.sub(make_replacer(new_name), content)

    return content, total_replacements


def process_files(source_dir: str, prefix: str, dry_run: bool = False) -> Dict[str, str]:
    """
    Main processing pipeline:
    1. Find all Swift files
    2. Extract symbols
    3. Build rename map
    4. Apply renames

    Returns the rename map for use by callers.
    """
    validate_prefix(prefix)

    swift_files = find_swift_files(source_dir)
    if not swift_files:
        print(f"Error: No Swift files found in {source_dir}", file=sys.stderr)
        sys.exit(1)

    # Extract symbols
    symbols = extract_symbols(swift_files)

    # Build rename map, skip already-prefixed
    rename_map = {}
    skipped = []
    for sym in sorted(symbols):
        if sym.startswith(prefix):
            skipped.append(sym)
            continue
        rename_map[sym] = f"{prefix}{sym}"

    print(f"Found {len(swift_files)} files, {len(symbols)} symbols ({len(rename_map)} to rename)")

    if dry_run:
        print("[DRY RUN] No files modified.")
        return rename_map

    # Build the set of "our" types: both original and prefixed names
    own_types = set(rename_map.keys()) | set(rename_map.values())

    # Apply renames to file contents
    modified_count = 0
    total_replacements = 0
    errors = []

    for filepath in swift_files:
        try:
            original = filepath.read_text(encoding='utf-8')
            modified, replacement_count = rename_symbols_in_content(original, rename_map, own_types)

            if modified != original:
                filepath.write_text(modified, encoding='utf-8')
                modified_count += 1
                total_replacements += replacement_count
        except Exception as e:
            errors.append(f"✗ {filepath.name}: {e}")

    if errors:
        for err in errors:
            print(err, file=sys.stderr)

    # Rename files whose names match a renamed symbol
    renamed_count = 0
    for filepath in swift_files:
        name_without_ext = filepath.stem
        if name_without_ext in rename_map:
            new_name = rename_map[name_without_ext] + '.swift'
            new_path = filepath.parent / new_name
            try:
                filepath.rename(new_path)
                renamed_count += 1
            except OSError as e:
                print(f"✗ Failed to rename {filepath.name}: {e}", file=sys.stderr)

    print(f"✓ Modified {modified_count} files, {total_replacements} replacements, {renamed_count} files renamed")

    return rename_map


def apply_rename_map_to_dir(target_dir: str, rename_map: Dict[str, str]):
    """Apply an existing rename map to all Swift files in target_dir."""
    swift_files = find_swift_files(target_dir)
    if not swift_files:
        print(f"Warning: No Swift files found in {target_dir}", file=sys.stderr)
        return

    own_types = set(rename_map.keys()) | set(rename_map.values())

    modified_count = 0
    total_replacements = 0
    errors = []

    for filepath in swift_files:
        try:
            original = filepath.read_text(encoding='utf-8')
            modified, replacement_count = rename_symbols_in_content(original, rename_map, own_types)

            if modified != original:
                filepath.write_text(modified, encoding='utf-8')
                modified_count += 1
                total_replacements += replacement_count
        except Exception as e:
            errors.append(f"✗ {filepath.name}: {e}")

    if errors:
        for err in errors:
            print(err, file=sys.stderr)

    print(f"✓ Applied to {modified_count} files, {total_replacements} replacements")


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <source_dir> <prefix> [--dry-run] [--apply-to <other_dir>]", file=sys.stderr)
        print(f"\nExamples:", file=sys.stderr)
        print(f"  {sys.argv[0]} ./Sources SCX", file=sys.stderr)
        print(f"  {sys.argv[0]} ./Sources SCX --dry-run", file=sys.stderr)
        print(f"  {sys.argv[0]} ./Starscream SCX --apply-to ./SocketIO", file=sys.stderr)
        sys.exit(1)

    source_dir = sys.argv[1]
    prefix = sys.argv[2]
    dry_run = '--dry-run' in sys.argv

    # Optional: apply the same rename map to another directory
    apply_to = None
    if '--apply-to' in sys.argv:
        idx = sys.argv.index('--apply-to')
        if idx + 1 < len(sys.argv):
            apply_to = sys.argv[idx + 1]
        else:
            print("Error: --apply-to requires a directory argument", file=sys.stderr)
            sys.exit(1)

    # Validate directories
    if not os.path.isdir(source_dir):
        print(f"Error: Source directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    if apply_to and not os.path.isdir(apply_to):
        print(f"Error: Target directory not found: {apply_to}", file=sys.stderr)
        sys.exit(1)

    try:
        rename_map = process_files(source_dir, prefix, dry_run)

        if apply_to and rename_map and not dry_run:
            apply_rename_map_to_dir(apply_to, rename_map)

    except KeyboardInterrupt:
        print("\nInterrupted by user", file=sys.stderr)
        sys.exit(130)
    except Exception as e:
        print(f"✗ Fatal error: {e}", file=sys.stderr)
        import traceback
        traceback.print_exc()
        sys.exit(1)
