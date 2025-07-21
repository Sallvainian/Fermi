#!/bin/bash

echo "Creating module maps for Firebase pods..."

# Array of Firebase pods that need module maps
FIREBASE_PODS=(
  "GoogleUtilities"
  "FirebaseCoreInternal"
  "FirebaseSharedSwift"
  "FirebaseAuth"
  "FirebaseCore"
)

# Create module maps for each pod
for POD_NAME in "${FIREBASE_PODS[@]}"; do
  POD_DIR="Pods/$POD_NAME"
  MODULE_MAP="$POD_DIR/module.modulemap"
  
  if [ -d "$POD_DIR" ]; then
    echo "Creating module map for $POD_NAME..."
    
    # Create a basic module map
    cat > "$MODULE_MAP" << EOF
module $POD_NAME {
  umbrella header "$POD_NAME-umbrella.h"
  export *
  module * { export * }
}
EOF
    
    # If umbrella header doesn't exist, create it
    UMBRELLA_HEADER="$POD_DIR/$POD_NAME-umbrella.h"
    if [ ! -f "$UMBRELLA_HEADER" ]; then
      echo "Creating umbrella header for $POD_NAME..."
      
      # Find all public headers
      HEADERS=$(find "$POD_DIR" -name "*.h" -type f | grep -v "Private" | head -20)
      
      # Create umbrella header
      cat > "$UMBRELLA_HEADER" << EOF
#ifdef __OBJC__
#import <Foundation/Foundation.h>
EOF
      
      # Add imports for each header
      for HEADER in $HEADERS; do
        HEADER_NAME=$(basename "$HEADER")
        echo "#import \"$HEADER_NAME\"" >> "$UMBRELLA_HEADER"
      done
      
      echo "#endif" >> "$UMBRELLA_HEADER"
    fi
  else
    echo "Warning: Pod directory $POD_DIR not found"
  fi
done

echo "Module maps creation completed!"