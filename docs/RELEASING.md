# Shipping MacWhispr

## Current release candidate

Version 0.2.0 targets macOS 13 and later on Apple Silicon. The release bundles a statically linked whisper.cpp engine with embedded Metal kernels and only Apple system dependencies. A model is downloaded by the user on first setup. Intel releases and runtime compatibility on macOS 13 have not been verified.

The current local archive is **ad hoc signed and not notarized**. It is a development candidate, not a Gatekeeper approved public download. This machine has no Developer ID signing identity. Public distribution requires the author's Apple Developer ID certificate and notarization. Do not disable Gatekeeper or strip quarantine as a distribution step.

## Build the candidate

```bash
brew install cmake
./script/build_speech_engine.sh
./script/package_release.sh
```

The engine script downloads official whisper.cpp v1.9.4, checks the pinned archive SHA256, and builds for macOS 13 with static backends. It disables CPU tuning for the build host so the binary can run on other Apple Silicon chips.

Output: `dist/release/MacWhispr-0.2.0-arm64.zip`, its SHA256 file, and `MacWhispr.app`. Generated archives and downloaded sources are ignored by Git. `WHISPER_BINARY=/absolute/path/to/whisper-cli` can provide another engine; packaging rejects non-system dependencies or an incompatible minimum OS.

## Sign and notarize

Install your **Developer ID Application** identity in your login keychain. Store notarization credentials with Apple's `notarytool store-credentials`; do not put credentials or certificates in this repository. Then run:

```bash
MACWHISPR_SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)' \
MACWHISPR_NOTARY_PROFILE='macwhispr-notary' \
./script/package_release.sh
```

The script signs the helper before the app, enables Hardened Runtime, grants the app the audio input entitlement, verifies signatures, submits the ZIP, staples the accepted app, and verifies Gatekeeper before exporting the final ZIP. An unsuccessful notarization stops the script; the unsigned candidate must not be substituted for a public release.

[Apple distribution requirements](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution) and [audio input entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.device.audio-input).

## Verify before publishing

```bash
./script/test_runtime.sh
MACWHISPR_WHISPER="$PWD/dist/release/MacWhispr.app/Contents/Helpers/whisper-cli" \
./script/test_transcription.sh
codesign --verify --deep --strict dist/release/MacWhispr.app
xcrun stapler validate dist/release/MacWhispr.app
spctl --assess --type execute --verbose dist/release/MacWhispr.app
```

The last two commands are public release gates, and will not pass for an ad hoc candidate. On a second Mac, install the downloaded ZIP into Applications, grant Microphone and Accessibility access, download a model, and check Toggle, Push to Talk, silence handling, paste, model download retry, and Reduce Motion. Verify on the oldest supported macOS before declaring that OS tested.

## Website handoff

```bash
python3 -m http.server 8765 --directory site
```

The site is static HTML/CSS/JavaScript with local font and image assets. No backend or account service is required. Configure your hosting provider to serve `404.html` for unknown paths. Before a public launch, set an absolute production social-image URL, connect the download action to the signed release ZIP, and remove the preview availability note. Privacy and terms describe the current product and must match any analytics, billing, or cloud features added later.

Publish the signed app archive as a GitHub release asset rather than committing binaries. Do not change repository visibility without the owner's approval. The app's source rights are reserved; upstream engine and font notices are included in `THIRD_PARTY_NOTICES.md` and `licenses/`.
