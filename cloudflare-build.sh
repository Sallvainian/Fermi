#!/bin/bash
# Cloudflare Pages build script
git clone https://github.com/flutter/flutter.git -b stable --depth 1
export PATH="$PATH:`pwd`/flutter/bin"
flutter --version
cd apps/fermi
flutter pub get
flutter build web --release