fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## Mac

### mac setup_signing

```sh
[bundle exec] fastlane mac setup_signing
```

Setup certificates for Developer ID signing

### mac build

```sh
[bundle exec] fastlane mac build
```

Build macOS app

### mac package

```sh
[bundle exec] fastlane mac package
```

Create macOS package installer

### mac ci_release

```sh
[bundle exec] fastlane mac ci_release
```

CI/CD build and release

### mac local_build

```sh
[bundle exec] fastlane mac local_build
```

Local build with existing certificates

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
