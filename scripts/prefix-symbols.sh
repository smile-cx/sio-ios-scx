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

# Clean any existing backup files
echo "Cleaning existing backup files..."
find "$FULL_SOURCE_PATH" -name "*.swift.backup" -type f -delete

# Extract all symbol names first
echo "Extracting symbols..."
SYMBOLS_FILE=$(mktemp)

# List of Foundation/Swift types to NEVER prefix
SYSTEM_TYPES="URL URLRequest URLResponse URLSession Data String Int Bool Double Float Array Dictionary Set Optional Result Error AnyObject Any Codable Decodable Encodable UUID Date DateFormatter TimeInterval NSObject DispatchQueue DispatchGroup Task OutputStream InputStream"

for file in $SWIFT_FILES; do
    # Extract class, struct, enum, protocol, actor names
    grep -E "^\s*(public|open|internal|private|fileprivate)?\s*(final|static)?\s*(class|struct|enum|protocol|actor|extension)\s+([A-Z][a-zA-Z0-9_]*)" "$file" | \
        gsed -E 's/.*\s(class|struct|enum|protocol|actor|extension)\s+([A-Z][a-zA-Z0-9_]*).*/\2/' >> "$SYMBOLS_FILE" || true
done

# Sort and unique
sort -u "$SYMBOLS_FILE" -o "$SYMBOLS_FILE"

# Filter out system types
FILTERED_SYMBOLS=$(mktemp)
while IFS= read -r symbol; do
    IS_SYSTEM=false
    for sys_type in $SYSTEM_TYPES; do
        if [ "$symbol" = "$sys_type" ]; then
            IS_SYSTEM=true
            break
        fi
    done

    if [ "$IS_SYSTEM" = false ]; then
        echo "$symbol" >> "$FILTERED_SYMBOLS"
    else
        echo "Skipping system type: $symbol"
    fi
done < "$SYMBOLS_FILE"

mv "$FILTERED_SYMBOLS" "$SYMBOLS_FILE"

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

            # Prefix type usage in various contexts
            # After colon (type annotations)
            gsed -i "s/:\s*\b${symbol}\b/: ${PREFIX}${symbol}/g" "$file"

            # In generics <Symbol>
            gsed -i "s/<\b${symbol}\b>/<${PREFIX}${symbol}>/g" "$file"
            gsed -i "s/<\b${symbol}\b,/<${PREFIX}${symbol},/g" "$file"
            gsed -i "s/,\s*\b${symbol}\b>/, ${PREFIX}${symbol}>/g" "$file"

            # In arrays/collections [Symbol]
            gsed -i "s/\[\b${symbol}\b\]/[${PREFIX}${symbol}]/g" "$file"

            # Symbol.self
            gsed -i "s/\b${symbol}\b\.self/${PREFIX}${symbol}.self/g" "$file"

            # Symbol.something (accessing static members/types)
            gsed -i "s/\b${symbol}\b\./${PREFIX}${symbol}./g" "$file"

            # Return types -> Symbol
            gsed -i "s/->\s*\b${symbol}\b/-> ${PREFIX}${symbol}/g" "$file"

            # Function parameters (Symbol)
            gsed -i "s/(\b${symbol}\b)/(${PREFIX}${symbol})/g" "$file"
            gsed -i "s/(\b${symbol}\b,/(${PREFIX}${symbol},/g" "$file"
            gsed -i "s/,\s*\b${symbol}\b)/, ${PREFIX}${symbol})/g" "$file"

            # Variable initialization = Symbol(
            gsed -i "s/=\s*\b${symbol}\b(/= ${PREFIX}${symbol}(/g" "$file"

            # "as Symbol" and "is Symbol" casts
            gsed -i "s/\s\+as\s\+\b${symbol}\b/ as ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/\s\+as?\s\+\b${symbol}\b/ as? ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/\s\+as!\s\+\b${symbol}\b/ as! ${PREFIX}${symbol}/g" "$file"
            gsed -i "s/\s\+is\s\+\b${symbol}\b/ is ${PREFIX}${symbol}/g" "$file"

            # Type constraints where Symbol:
            gsed -i "s/\bwhere\s\+\b${symbol}\b:/where ${PREFIX}${symbol}:/g" "$file"
        fi
    done < "$SYMBOLS_FILE"
done

# Clean up backups and verify files
echo ""
echo "Verifying processed files..."
EMPTY_FILES=0
for file in $SWIFT_FILES; do
    # Remove backup
    if [ -f "$file.backup" ]; then
        rm "$file.backup"
    fi

    # Check if file is empty
    if [ ! -s "$file" ]; then
        echo "WARNING: File is empty: $file"
        EMPTY_FILES=$((EMPTY_FILES + 1))
    fi
done

if [ $EMPTY_FILES -gt 0 ]; then
    echo "ERROR: $EMPTY_FILES files are empty after processing!"
    exit 1
fi

rm "$SYMBOLS_FILE"

echo ""
echo "================================================"
echo "Prefixing complete!"
echo "All symbols prefixed with: $PREFIX"
echo "Processed $(echo "$SWIFT_FILES" | wc -l) files successfully"
echo "================================================"
