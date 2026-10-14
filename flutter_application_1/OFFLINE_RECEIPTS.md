# Offline receipt scanning

iOS uses Apple Vision accurate text recognition when the device reports Thai
support. Observations are reconstructed by visual rows so labels and amounts
in separate bank-slip columns remain together. Older iOS systems and Android
use flutter_tesseract_ocr with bundled Thai + English models. Neither engine
sends receipt images to a server.
Scanning has no API key, cloud endpoint, per-scan fee or runtime model download.
Do a full rebuild after installing dependencies; hot reload cannot register the
native plugin. Use the same Flutter SDK as the IDE (currently 3.44.8).

Run `flutter pub get`, then `cd ios && pod install` for iOS, and `flutter run`.
The iOS project includes a folder reference to assets/tessdata at the bundle root
for SwiftyTesseract, in addition to the Flutter asset declarations for Android.
Web/desktop currently show an unsupported-platform message instead of using a
paid cloud fallback.

The upstream SwiftyTesseract 3.1.3 binary has an x86_64 iOS simulator slice,
not an arm64 simulator slice. Apple Silicon iOS 26+ simulators cannot run it;
use a physical iPhone for native OCR testing. Android and iPhone device builds
are separate from this simulator restriction.

Receipt images are stored in app support storage, partitioned by a hash of the
signed-in user's ID. `local-receipt:` markers identify device-only attachments.
Images do not sync across devices and can be lost when app data is removed.
Failed transaction saves clean up the newly created local attachment.
Existing transaction metadata still uses the app's existing Firestore flow;
this change does not make all app services offline or remove Firestore quotas.
There is no attachment viewer in the current transaction details screen.

Validation:
- `flutter test test/receipt_parser_test.dart test/receipt_service_test.dart test/local_receipt_store_test.dart test/receipt_ocr_assets_test.dart`
- `flutter run -t tool/receipt_ocr_smoke.dart` runs synthetic native OCR without Firebase.
  Afterwards run `flutter run -t lib/main.dart` to return to the normal app.
- Test actual Thai slips on device, review amount/date/category, save, and reopen.
  OCR suggestions are not bank transfer verification.

Models: https://github.com/tesseract-ocr/tessdata/tree/4.1.0 (Apache-2.0).
Plugin setup: https://pub.dev/packages/flutter_tesseract_ocr

Native Apple Vision regression on macOS with Thai support:
`swiftc ios/Runner/ReceiptTextRecognizer.swift tool/receipt_vision_smoke/main.swift -o /tmp/receipt-vision-check && /tmp/receipt-vision-check`
This uses synthetic data; a passing result is not verification of a real slip.

## Thai slip formats

The parser does not restrict scanning to a bank-name allowlist. It recognizes
Thai/English transfer/payment/total labels, Thai digits and decomposed Thai
characters, split currency/value lines, numeric/ISO dates, all twelve full Thai
month names, abbreviated Thai months and English months. Thai two-digit named
month years use the Buddhist era; English month years use the Gregorian era.
Numeric two-digit years 50–99 use the Buddhist era; 00–49 use the Gregorian era.
The date remains a suggestion to review.

Explicit transfer principal outranks general totals. Fees, balances, references,
account numbers, malformed numbers and conflicting same-priority amounts are
not silently used as the expense amount. The original display text is preserved.

`test/thai_slip_formats_test.dart` uses synthetic OCR variants and does not
certify every bank/template. Local native OCR + parser validation on the user's
SCB image returned 350.00 and 2026-09-29. The private image and extracted text
are not included in the repository. Actual examples from other banks are still
needed to verify their image layouts, fonts and background patterns.
