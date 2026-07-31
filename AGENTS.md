# Repository guidance

- Read `DEVELOPMENT_NOTES.md` before changing navigation animations, local-network parsing, build settings, or release packaging.
- Keep the local-network feature read-only and label uncertain interface ownership conservatively.
- Scope SwiftUI animations to lightweight visual state; do not animate the complete settings detail hierarchy from sidebar selection.
- Before committing, run the full Swift test suite and `git diff --check`.
- Release versions must align across Xcode `MARKETING_VERSION`, Git tags, DMG names, and GitHub Release titles.
- Do not claim notarization unless Developer ID signing, Apple notarization, and stapling have all been verified.
