# Dependency changelog audit

Reviewed on 5 November 2026 against the resolved packages in
`.dart_tool/package_config.json` and `pubspec.lock`, including the pinned image
Git checkout. Scope: all seven direct runtime dependencies and both development
dependencies. Transitive dependencies are consumed through those packages and
are not imported directly by this library.

A new API is adopted when it improves an existing operation. Maintenance,
internal performance, decoder robustness, and test runner fixes already apply
through the resolved version; they do not require application code changes.

| Dependency | Resolved version | Findings and action |
| --- | --- | --- |
| [archive](https://pub.dev/packages/archive/changelog) | 4.6.0 | Explicit strict decoding handles the changed damaged-data defaults. Added optional `verify` to both decode factories to enable CRC checks on entries as they are read. Preserve original untouched entries so the ZIP encoder can reuse compressed content and metadata. `encodeToStream` now uses `ZipEncoder(streamed: true)` to incrementally compress new entries as well as writing to the supplied stream. Retain normal byte output for the existing API. |
| [xml](https://pub.dev/packages/xml/changelog) | 7.1.0 | Migrated names and namespace builders to supported APIs, delegated shared-string text escaping to the serializer, and use `elementAttributes` to distinguish actual attributes from namespace declarations when deciding whether a worksheet format element can be removed. Preserve unrelated extension attributes and namespaces during saves. DOM parsing remains appropriate for editable workbooks. The new XPath machinery and document-position comparison have no corresponding operation here, so no artificial XPath conversion was added. |
| [collection](https://pub.dev/packages/collection/changelog) | 1.19.1 | Equality and nullable-search helpers were already used. Replace sorting solely to obtain row/column maxima with `maxOrNull`, reducing that operation from sorting to linear scans. The latest shuffle, sampling, canonical-map, and flattening additions do not match current workbook operations. |
| [equatable](https://pub.dev/packages/equatable/changelog) | 3.0.0 | Existing models already use `Equatable`, not the removed `EquatableMixin`. The changelog announces removal of the runtime-type guard; include runtime type in model properties to preserve type-specific equality independently of the base implementation. Added equality/hash regression coverage. Existing explicit string representations remain intact. The locally resolved implementation still contains the runtime-type guard despite the changelog; the explicit property also protects the intended contract if the implementation changes. |
| [web](https://pub.dev/packages/web/changelog) | 1.1.2 | Existing download code already uses JS interop, Blob, and object URLs. Use the typed `HTMLAnchorElement` constructor and reuse a `Uint8List` input instead of copying it. Select the web implementation with `dart.library.js_interop` so Wasm uses the browser helper too. The latest release primarily supplies migration tooling; no applicable deprecated storage or node-text calls remain. |
| [path](https://pub.dev/packages/path/changelog) | 1.9.1 | The newest release is SDK/maintenance work. Adopt explicit POSIX context for internal ZIP filenames and normalized relationship resolution, replacing host-dependent operations and hard-coded `..` replacement for images/drawings. No new drive-URI behavior is needed for ZIP entries. |
| [image Git fork](https://github.com/kumsumit/image/blob/5ee40b1045e5b9f209650548a1bbe9867c61811d/CHANGELOG.md) | 4.9.2, commit `5ee40b1045e5b9f209650548a1bbe9867c61811d` | Read the actual fork checkout's changelog. Its dependency removals and decoder fixes apply automatically. Replace duplicate partial magic-byte checks with `findFormatForData`, retaining the supported PNG/JPEG/GIF set. Decode only frame zero when dimensions are needed, avoiding decoding every animation frame. The new `findEncoderForData` is unnecessary because Excel embeds the original image bytes; re-encoding would add work and potentially lose metadata. Image filters, cropping, and color-conversion APIs are unrelated to embedding. |
| [test](https://pub.dev/packages/test/changelog) | 1.33.0 | Runner fixes apply automatically. Use the GitHub reporter in GitHub Actions to benefit from grouped passing output. Added compatibility tests for image codecs, relationship paths, checksum checks, sparse bounds, equality, and XML extension preservation. Sanitizer/native-CLI runners are unnecessary for this Dart-only library. |
| [lints](https://pub.dev/packages/lints/changelog) | 6.1.0 | Previously installed without an analysis-options include, so it provided no checks. Enable the core set plus the two 6.1 rules (`use_null_aware_elements`, `no_wildcard_variable_uses`). Adopt URI-based part directives, explicit missing function types, and package imports in examples. Broader style rules are not enabled because they would force unrelated API naming and cosmetic changes. |

## Limits

The editor still retains worksheet DOMs and cell models and rebuilds worksheet
XML during saving. Incremental ZIP output does not make workbook editing itself
streaming. A read-only row-streaming API or comprehensive dirty-part tracking
would require a separate design and tests for lossless preservation of unknown
OOXML content. No compression methods incompatible with common XLSX consumers
were enabled, and no dependency versions were changed by this audit.

## Validation

- 61 VM tests pass, including all existing tests and the new compatibility cases.
- Static analysis reports no issues with the configured lint rules enabled.
- A workbook creation/save smoke entrypoint compiles to JavaScript and Wasm.
  These are compilation checks, not browser download runtime tests.
- `git diff --check` passes.
