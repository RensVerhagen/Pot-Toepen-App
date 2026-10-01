# Pot Toepen test-APK's

- When handing over app changes for device testing, build an installable Android APK from the current code and place a copy in this repository's `artifacts/` directory. Do this even when a GitHub Actions artifact is also available; that remote artifact does not replace the local file.
- Give each APK a distinct, descriptive filename that includes the app version. Preserve existing APKs unless the user explicitly asks to replace or remove them.
- Verify that the build succeeded and that the copied file matches the build output. Check the APK's package/version and signing certificate before saying it is ready. For updates over an earlier local test build, use the same debug signing key when possible; warn the user if an in-place update has not been verified.
- `artifacts/` is intentionally excluded from Git. Link the local APK in the handoff, and state clearly if no local APK could be produced.
