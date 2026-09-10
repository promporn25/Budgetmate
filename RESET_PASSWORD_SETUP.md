# Budgetmate password reset page

The responsive reset page is `public/reset_password.html`, with local Mali fonts,
a matching pastel app palette, Thai/English copy, password visibility controls,
validation, loading/success/expired-link states and a retry for network errors.
Passwords are sent only to Firebase Authentication and are not stored locally.

## Publish and connect the email link

1. Reauthenticate if needed: `firebase login --reauth`.
2. From this repository root run:
   `firebase deploy --only hosting --project budgetmate-app-a94da`
3. Open Firebase Console → Authentication → Templates → Password reset →
   Customize action URL, and set:
   `https://budgetmate-app-a94da.web.app/reset_password.html`
4. Request a fresh password reset email from the app and follow its link.

`ActionCodeSettings.url` in the Flutter app is a **continue URL**, not the email
handler URL. Setting only that value does not replace Firebase's default page.
The app also sets Firebase's email language before requesting the email.

Opening the page directly without `mode`, `oobCode`, and `apiKey` deliberately
shows the invalid-link state. The form is available only after Firebase verifies
the reset code. Do not add a public preview flag that bypasses this check.

Custom action URL configuration can affect other authentication email actions;
this page currently implements password reset only. If the project also uses
email verification or email recovery, retain their existing handlers or add and
test those modes before pointing a shared action handler at this page.

Validation: `node --test tests/reset_password.test.cjs` (mock Firebase responses).
No real account password was changed during development.

Official reference: https://firebase.google.com/docs/auth/custom-email-handler
