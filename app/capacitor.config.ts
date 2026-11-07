import type { CapacitorConfig } from '@capacitor/cli';

// Changing anything in this file is a native change: it is baked into the iOS
// build at `cap sync`, so a live update cannot carry it. Raise
// MIN_NATIVE_BUILD (AD-18) in the same commit. CURRENT_PROJECT_VERSION in
// ios/App/App.xcodeproj/project.pbxproj must stay >= MIN_NATIVE_BUILD.
//
// Regenerating ios/: `cap add ios` rejects the dashed id below. Set appId to a
// temporary valid one (com.academictools.fermi), run `npm run build` (cap add
// needs dist/), then `npx cap add ios --packagemanager SPM`, restore the id here, then set PRODUCT_BUNDLE_IDENTIFIER
// in project.pbxproj to "com.academic-tools.fermi" (plus team, version, build).
const config: CapacitorConfig = {
  // Permanent. This is the App Store listing's bundle id, and the app's
  // on-device storage is keyed to it, so changing it strands every installed
  // copy and breaks the update path.
  appId: 'com.academic-tools.fermi',
  appName: 'Fermi+',
  webDir: 'dist',
};

export default config;
