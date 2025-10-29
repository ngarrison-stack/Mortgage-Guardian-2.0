fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios get_latest_build_number

```sh
[bundle exec] fastlane ios get_latest_build_number
```

Get latest TestFlight build number

### ios set_build_number

```sh
[bundle exec] fastlane ios set_build_number
```

Increment build number

### ios beta

```sh
[bundle exec] fastlane ios beta
```

Build and upload to TestFlight

### ios setup_app

```sh
[bundle exec] fastlane ios setup_app
```

Create the App Store Connect app record and initial setup

### ios setup_signing

```sh
[bundle exec] fastlane ios setup_signing
```

Setup code signing using match (stores certs in a private git repo)

### ios test

```sh
[bundle exec] fastlane ios test
```

Run tests using the test-build.sh script

### ios build_dev

```sh
[bundle exec] fastlane ios build_dev
```

Build for development

### ios unit_tests

```sh
[bundle exec] fastlane ios unit_tests
```

Run unit tests only

### ios integration_tests

```sh
[bundle exec] fastlane ios integration_tests
```

Run integration tests

### ios release_beta

```sh
[bundle exec] fastlane ios release_beta
```

Build and upload to TestFlight with automatic version management

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
