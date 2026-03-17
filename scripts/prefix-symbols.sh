#!/bin/bash

# Script to prefix all Swift symbols (classes, structs, enums, protocols, extensions)
# Usage: ./prefix-symbols.sh <source_dir> <relative_source_path> <module_name> <prefix>

set -e

SOURCE_DIR=$1
RELATIVE_PATH=$2
MODULE_NAME=$3
PREFIX=$4

if [ -z "$SOURCE_DIR" ] || [ -z "$RELATIVE_PATH" ] || [ -z "$MODULE_NAME" ] || [ -z "$PREFIX" ]; then
    echo "Usage: $0 <source_dir> <relative_source_path> <module_name> <prefix>"
    exit 1
fi

FULL_SOURCE_PATH="$SOURCE_DIR/$RELATIVE_PATH"

echo "================================================"
echo "Prefixing symbols in: $FULL_SOURCE_PATH"
echo "Module: $MODULE_NAME -> ${PREFIX}${MODULE_NAME}"
echo "Prefix: $PREFIX"
echo "================================================"

if [ ! -d "$FULL_SOURCE_PATH" ]; then
    echo "Error: Source path does not exist: $FULL_SOURCE_PATH"
    exit 1
fi

# Find all Swift files
SWIFT_FILES=$(find "$FULL_SOURCE_PATH" -name "*.swift" -type f)

if [ -z "$SWIFT_FILES" ]; then
    echo "No Swift files found in $FULL_SOURCE_PATH"
    exit 1
fi

echo "Found $(echo "$SWIFT_FILES" | wc -l) Swift files"

# Extract all symbol names first
echo "Extracting symbols..."
SYMBOLS_FILE=$(mktemp)

for file in $SWIFT_FILES; do
    # Extract class, struct, enum, protocol, actor names
    grep -E "^\s*(public|open|internal|private|fileprivate)?\s*(final|static)?\s*(class|struct|enum|protocol|actor|extension)\s+([A-Z][a-zA-Z0-9_]*)" "$file" | \
        gsed -E 's/.*\s(class|struct|enum|protocol|actor|extension)\s+([A-Z][a-zA-Z0-9_]*).*/\2/' >> "$SYMBOLS_FILE" || true
done

# Sort and unique
sort -u "$SYMBOLS_FILE" -o "$SYMBOLS_FILE"

SYMBOL_COUNT=$(wc -l < "$SYMBOLS_FILE")
echo "Found $SYMBOL_COUNT unique symbols to prefix"

if [ $SYMBOL_COUNT -eq 0 ]; then
    echo "Warning: No symbols found to prefix"
    rm "$SYMBOLS_FILE"
    exit 0
fi

echo "Sample symbols (first 10):"
head -10 "$SYMBOLS_FILE"

# Apply prefixes to all files
echo ""
echo "Applying prefix '$PREFIX' to symbols..."

for file in $SWIFT_FILES; do
    echo "Processing: $(basename $file)"

    # Create backup
    cp "$file" "$file.backup"

    # Read symbols and apply prefix
    while IFS= read -r symbol; do
        if [ ! -z "$symbol" ]; then
            # Skip if already prefixed
            if [[ "$symbol" == ${PREFIX}* ]]; then
                continue
            fi

            # Prefix class/struct/enum/protocol/actor declarations
            gsed -i "s/\(class\|struct\|enum\|protocol\|actor\)\s\+\b${symbol}\b/\1 ${PREFIX}${symbol}/g" "$file"

            # Prefix extension declarations
            gsed -i "s/extension\s\+\b${symbol}\b/extension ${PREFIX}${symbol}/g" "$file"

            # Prefix type usage (: Symbol, <Symbol>, [Symbol], Symbol.self, etc.)
            gsed -i "s/:\s*\b${symbol}\b/: ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/<\s*\b${symbol}\b/<${PREFIX}${symbol}/g" "$file"
            gsed -i "s/\[\s*\b${symbol}\b/[${PREFIX}${symbol}/g" "$file"
            gsed -i "s/\b${symbol}\b\.self/${PREFIX}${symbol}.self/g" "$file"

            # Prefix in function parameters and return types
            gsed -i "s/->\s*\b${symbol}\b/-> ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/(\s*\b${symbol}\b/(${PREFIX}${symbol}/g" "$file"

            # Prefix initializations
            gsed -i "s/=\s*\b${symbol}\b(/= ${PREFIX}${symbol}(/g" "$file"
            gsed -i "s/let\s\+\w\+\s*:\s*\b${symbol}\b/let \0: ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/var\s\+\w\+\s*:\s*\b${symbol}\b/var \0: ${PREFIX}${symbol}/g" "$file"
        fi
    done < "$SYMBOLS_FILE"
done

# Clean up backups if everything went well
for file in $SWIFT_FILES; do
    if [ -f "$file.backup" ]; then
        rm "$file.backup"
    fi
done

rm "$SYMBOLS_FILE"

echo ""
echo "================================================"
echo "Prefixing complete!"
echo "All symbols prefixed with: $PREFIX"
echo "================================================"
