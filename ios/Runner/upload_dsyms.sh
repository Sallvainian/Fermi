#!/bin/zsh

# Firebase Crashlytics dSYM upload script
# This script uploads debug symbols to Firebase Crashlytics

if [ -z "$FLUTTER_BUILD_MODE" ] || [ "$FLUTTER_BUILD_MODE" = "release" ]; then
    echo "Uploading dSYMs to Firebase Crashlytics..."
    
    # Path to Crashlytics upload script (installed via Firebase SDK)
    UPLOAD_SCRIPT="${PODS_ROOT}/FirebaseCrashlytics/upload-symbols"
    
    if [ -f "$UPLOAD_SCRIPT" ]; then
        # Upload dSYMs
        "$UPLOAD_SCRIPT" -gsp "${PROJECT_DIR}/Runner/GoogleService-Info.plist" -p ios "${DWARF_DSYM_FOLDER_PATH}/${DWARF_DSYM_FILE_NAME}"
        echo "dSYM upload completed"
    else
        echo "Warning: Firebase Crashlytics upload script not found at $UPLOAD_SCRIPT"
        echo "Make sure FirebaseCrashlytics pod is installed"
    fi
else
    echo "Skipping dSYM upload for non-release build"
fi