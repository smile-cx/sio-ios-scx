#!/usr/bin/env python3
"""
Prefix all Swift type declarations and their usages across source files.

Usage: python3 prefix-symbols.py <source_dir> <prefix> [--dry-run]

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


def find_swift_files(source_dir: str) -> list[str]:
    """Find all .swift files recursively."""
    files = []
    for root, _, filenames in os.walk(source_dir):
        for f in filenames:
            if f.endswith('.swift'):
                files.append(os.path.join(root, f))
    return sorted(files)


def extract_symbols(swift_files: list[str]) -> set[str]:
    """Extract all type declaration names from Swift files."""
    symbols = set()
    for filepath in swift_files:
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        for match in DECL_PATTERN.finditer(content):
            name = match.group(1)
            if name not in SYSTEM_TYPES:
                symbols.add(name)
    return symbols


def rename_symbols_in_content(content: str, rename_map: dict[str, str],
                              own_types: set[str]) -> str:
    """
    Apply symbol renames using whole-word boundary matching.

    Sorts by length descending to avoid partial replacements
    (e.g., "SocketEngine" before "Socket").

    When a symbol appears after a dot (e.g. Foo.Event), it checks whether
    the qualifier before the dot is one of OUR types or a system type:
    - OurType.Event  -> SCXOurType.SCXEvent  (rename)
    - Stream.Event   -> Stream.Event         (keep)
    """
    # Sort by length descending so longer names are replaced first
    sorted_names = sorted(rename_map.keys(), key=len, reverse=True)

    for old_name in sorted_names:
        new_name = rename_map[old_name]
        pattern = re.compile(r'\b' + re.escape(old_name) + r'\b')

        def make_replacer(new_name_val):
            def replacer(match):
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
                        return new_name_val
                    else:
                        return match.group(0)  # system type, don't rename
                return new_name_val
            return replacer

        content = pattern.sub(make_replacer(new_name), content)

    return content


def process_files(source_dir: str, prefix: str, dry_run: bool = False) -> dict[str, str]:
    """
    Main processing pipeline:
    1. Find all Swift files
    2. Extract symbols
    3. Build rename map
    4. Apply renames

    Returns the rename map for use by callers.
    """
    swift_files = find_swift_files(source_dir)
    if not swift_files:
        print(f"No Swift files found in {source_dir}")
        sys.exit(1)

    print(f"Found {len(swift_files)} Swift files in {source_dir}")

    # Extract symbols
    symbols = extract_symbols(swift_files)
    print(f"Found {len(symbols)} unique type symbols")

    # Build rename map, skip already-prefixed
    rename_map = {}
    for sym in sorted(symbols):
        if sym.startswith(prefix):
            print(f"  [skip] {sym} (already prefixed)")
            continue
        rename_map[sym] = f"{prefix}{sym}"

    print(f"\nRename map ({len(rename_map)} symbols):")
    for old, new in sorted(rename_map.items()):
        print(f"  {old} -> {new}")

    if dry_run:
        print("\n[DRY RUN] No files modified.")
        return rename_map

    # Build the set of "our" types: both original and prefixed names
    own_types = set(rename_map.keys()) | set(rename_map.values())

    # Apply renames
    print(f"\nApplying renames to {len(swift_files)} files...")
    for filepath in swift_files:
        with open(filepath, 'r', encoding='utf-8') as f:
            original = f.read()

        modified = rename_symbols_in_content(original, rename_map, own_types)

        if modified != original:
            with open(filepath, 'w', encoding='utf-8') as f:
                f.write(modified)
            print(f"  [modified] {os.path.basename(filepath)}")
        else:
            print(f"  [unchanged] {os.path.basename(filepath)}")

    print(f"\nPrefixing complete. {len(rename_map)} symbols renamed with prefix '{prefix}'.")
    return rename_map


if __name__ == '__main__':
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <source_dir> <prefix> [--dry-run]")
        sys.exit(1)

    source_dir = sys.argv[1]
    prefix = sys.argv[2]
    dry_run = '--dry-run' in sys.argv

    if not os.path.isdir(source_dir):
        print(f"Error: {source_dir} is not a directory")
        sys.exit(1)

    process_files(source_dir, prefix, dry_run)
