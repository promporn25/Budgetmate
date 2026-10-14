> The app now uses bundled on-device Tesseract OCR and local receipt images.
> No Functions deployment, Cloud Vision API, Firebase Storage or Blaze upgrade
> is needed for scanning. The cloud setup below is retained for the old backend.
> See `../flutter_application_1/OFFLINE_RECEIPTS.md` for the current setup.

# Receipt scanner setup

The app sends a selected JPG/PNG (up to 5 MB) to the authenticated `scanReceipt`
callable in `asia-southeast1`. Google Cloud Vision reads Thai/English text; the
app suggests a total, first-line merchant and numeric day/month/year date.
The user checks these, chooses an expense category and confirms the save.
One receipt creates one expense in the currently selected currency; no currency
conversion or line-item splitting is performed. Dates not recognized use today.

## Enable the service

1. In the existing Firebase project, configure billing (Blaze), enable Cloud
   Vision API, and initialize Firebase Storage if it has not been provisioned.
   These cloud services can incur charges.
2. Install Node 22 and Firebase CLI, authenticate to the intended project.
3. From `functions/`, run `npm ci`.
4. From the repository root (not `flutter_application_1/`), run:
   `firebase deploy --only functions:receipts,storage --project budgetmate-app-a94da`
   The configured codebase is `receipts`; to deploy only the scanner backend,
   use `--only functions:receipts`.
5. From `flutter_application_1/`, run `flutter pub get` and rebuild the app.
   For iOS, refresh CocoaPods if the build requests it.

The function uses its runtime service account (Application Default Credentials),
not an API key embedded in Flutter. Ensure the runtime account can consume the
Vision API in this project. The function requires Firebase Authentication.
Max instances limits concurrency, not total spending; configure quotas/budget
alerts for a public release and add App Check enforcement once the app is
registered for App Check.

Storage rules restrict receipt access to its owner at `receipts/{uid}/{id}`.
`receipt_path` stores a private object path. This change does not add a history
image viewer. If image upload succeeds but saving the transaction fails, the
open screen reuses that upload on retry. Leaving the screen after such a failure
can leave an unreferenced private image; production cleanup can remove orphans.

## Verification

Run `flutter test test/receipt_parser_test.dart` in the Flutter folder.
After deployment, test gallery/camera with real Thai and English receipts,
confirm the total/date/category/currency, save and reload transactions. Test a
blurred image, cancellation, denied photo access, lost network and save retry.
Verify a second Firebase user cannot read the first user's receipt path.

References:
- https://docs.cloud.google.com/vision/docs/languages
- https://firebase.google.com/docs/functions/callable

Local validation: all 21 Flutter tests passed (including 5 receipt parser tests),
new Dart files passed analysis, and `node --check index.js` passed. Live OCR,
Storage rules and device camera flows have not yet been exercised. Dependency
metadata was locked, but the backend was not installed or executed locally.
`npm audit` still reports 11 moderate findings in transitive `qs`/`uuid`
dependencies after compatible fixes; review upstream updates before production
release. Do not blindly apply `npm audit fix --force` (it proposes downgrading
Firebase Functions across major versions). Use Node 22 for backend verification;
the local machine currently has Node 26.
