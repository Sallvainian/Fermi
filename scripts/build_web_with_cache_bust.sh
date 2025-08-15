#!/bin/bash
# Build script that properly updates service worker version for cache busting

echo -e "\033[32mBuilding Flutter web with cache busting...\033[0m"

# Clean previous build
echo -e "\033[33mCleaning previous build...\033[0m"
flutter clean

# Build the web app
echo -e "\033[33mBuilding Flutter web app...\033[0m"
flutter build web --release

# Generate a unique version based on current timestamp (milliseconds since epoch)
version=$(date +%s%3N)
echo -e "\033[36mGenerated version: $version\033[0m"

# Update serviceWorkerVersion in flutter_bootstrap.js
bootstrap_file="build/web/flutter_bootstrap.js"
if [ -f "$bootstrap_file" ]; then
    echo -e "\033[33mUpdating service worker version in flutter_bootstrap.js...\033[0m"
    
    # Use sed to replace the serviceWorkerVersion
    sed -i.bak -E "s/serviceWorkerVersion: \"[^\"]*\"/serviceWorkerVersion: \"$version\"/" "$bootstrap_file"
    
    # Remove backup file
    rm -f "${bootstrap_file}.bak"
    
    echo -e "\033[32mUpdated service worker version to: $version\033[0m"
else
    echo -e "\033[31mError: flutter_bootstrap.js not found!\033[0m"
    exit 1
fi

# Also update version.json with the same version for consistency
version_file="build/web/version.json"
cat > "$version_file" <<EOF
{
  "version": "$version",
  "build_number": "$version",
  "package_name": "teacher_dashboard"
}
EOF
echo -e "\033[32mUpdated version.json\033[0m"

# Update the service worker itself to force cache invalidation
service_worker_file="build/web/flutter_service_worker.js"
if [ -f "$service_worker_file" ]; then
    # Add a comment with the version at the top of the service worker
    echo "// Build version: $version" | cat - "$service_worker_file" > temp && mv temp "$service_worker_file"
    echo -e "\033[32mUpdated flutter_service_worker.js\033[0m"
fi

echo -e "\n\033[32mBuild complete with cache busting!\033[0m"
echo -e "\033[36mService worker version: $version\033[0m"
echo -e "\n\033[33mTo deploy, run: firebase deploy --only hosting\033[0m"