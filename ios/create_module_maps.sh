#!/bin/bash

echo "Creating module maps for Firebase pods..."

# Create GoogleUtilities_NSData module map specifically - this is what Firebase expects
GOOGLE_UTILS_DIR="Pods/GoogleUtilities"
if [ -d "$GOOGLE_UTILS_DIR" ]; then
  echo "Creating GoogleUtilities_NSData module map..."
  
  # Find the actual header location
  NSDATA_HEADER=""
  if [ -f "$GOOGLE_UTILS_DIR/GoogleUtilities/GULNSData+zlib.h" ]; then
    NSDATA_HEADER="GoogleUtilities/GULNSData+zlib.h"
  elif [ -f "$GOOGLE_UTILS_DIR/NSData+zlib/Public/GoogleUtilities/GULNSData+zlib.h" ]; then
    NSDATA_HEADER="NSData+zlib/Public/GoogleUtilities/GULNSData+zlib.h"
  else
    # Search for it
    NSDATA_HEADER=$(find "$GOOGLE_UTILS_DIR" -name "GULNSData+zlib.h" | head -1 | sed "s|$GOOGLE_UTILS_DIR/||")
  fi
  
  if [ -n "$NSDATA_HEADER" ]; then
    cat > "$GOOGLE_UTILS_DIR/GoogleUtilities_NSData.modulemap" << EOF
module GoogleUtilities_NSData {
  header "$NSDATA_HEADER"
  export *
}
EOF
    echo "Created GoogleUtilities_NSData module map with header: $NSDATA_HEADER"
  else
    echo "ERROR: Could not find GULNSData+zlib.h header"
    find "$GOOGLE_UTILS_DIR" -name "*.h" | grep -i nsdata
  fi
fi

echo "Module maps creation completed!"