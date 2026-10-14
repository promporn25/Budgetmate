(function () {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode');
  const oobCode = params.get('oobCode');
  const apiKey = params.get('apiKey');
  // Firebase shares this URL across email templates. Preserve its standard
  // handler for verification, recovery and other non-password-reset actions.
  if (mode && mode !== 'resetPassword') {
    const fallback = new URL('https://budgetmate-app-a94da.firebaseapp.com/__/auth/action');
    fallback.search = params.toString();
    window.location.replace(fallback.href);
    return;
  }

  let continueLang;
  try { continueLang = new URL(params.get('continueUrl')).searchParams.get('lang'); } catch (_) {}
  const lang = (continueLang || params.get('lang') || 'th').toLowerCase();

  const isEN = lang.startsWith('en');
  const dict = {
    th: {
      verifying: 'กำลังตรวจสอบลิงก์...',
      invalidTitle: 'ลิงก์นี้ใช้ไม่ได้แล้ว',
      invalidDesc: 'ลิงก์รีเซ็ตรหัสผ่านนี้หมดอายุหรือถูกใช้ไปแล้ว กรุณากลับไปที่แอปแล้วขอลิงก์ใหม่อีกครั้ง',
      formTitle: 'ตั้งรหัสผ่านใหม่',
      formDescPrefix: 'กำลังตั้งรหัสผ่านใหม่ให้บัญชี',
      newPasswordLabel: 'รหัสผ่านใหม่',
      newPasswordPh: 'อย่างน้อย 6 ตัวอักษร',
      confirmPasswordLabel: 'ยืนยันรหัสผ่านใหม่',
      confirmPasswordPh: 'กรอกรหัสผ่านใหม่อีกครั้ง',
      submitBtn: 'บันทึกรหัสผ่านใหม่',
      submitBtnLoading: 'กำลังบันทึก...',
      successTitle: 'ตั้งรหัสผ่านใหม่สำเร็จ',
      successDesc: 'กลับไปที่แอป BUDGETMATE แล้วเข้าสู่ระบบด้วยรหัสผ่านใหม่ได้เลย',
      footerNote: 'หากคุณไม่ได้เป็นผู้ขอรีเซ็ตรหัสผ่านนี้ สามารถปิดหน้านี้ได้เลย บัญชีของคุณยังปลอดภัย',
      errTooShort: 'รหัสผ่านต้องมีอย่างน้อย 6 ตัวอักษร',
      errMismatch: 'รหัสผ่านไม่ตรงกัน',
      errTooLong: 'รหัสผ่านยาวเกิน 128 ตัวอักษร',
      errCommon: 'รหัสผ่านนี้เดาง่าย กรุณาเลือกวลีอื่น',
      errConfirm: 'กรุณากรอกยืนยันรหัสผ่าน',
      policyValid: 'รหัสผ่านผ่านเงื่อนไขแล้ว',
      errGeneric: 'เกิดข้อผิดพลาด กรุณาลองใหม่อีกครั้ง',
      errBadLink: 'ลิงก์นี้ไม่ถูกต้องหรือหมดอายุแล้ว',
    },
    en: {
      verifying: 'Verifying your link...',
      invalidTitle: 'This link is no longer valid',
      invalidDesc: 'This password reset link has expired or already been used. Go back to the app and request a new one.',
      formTitle: 'Set a new password',
      formDescPrefix: 'Setting a new password for',
      newPasswordLabel: 'New password',
      newPasswordPh: 'At least 6 characters',
      confirmPasswordLabel: 'Confirm new password',
      confirmPasswordPh: 'Re-enter your new password',
      submitBtn: 'Save new password',
      submitBtnLoading: 'Saving...',
      successTitle: 'Password reset successful',
      successDesc: 'Go back to BUDGETMATE and log in with your new password.',
      footerNote: "If you didn't request this, you can safely close this page. Your account is still secure.",
      errTooShort: 'Password must be at least 6 characters',
      errMismatch: 'Passwords do not match',
      errTooLong: 'Password exceeds the 128-character limit',
      errCommon: 'This password is too common. Choose another passphrase.',
      errConfirm: 'Please confirm your password',
      policyValid: 'Password meets the requirements',
      errGeneric: 'Something went wrong. Please try again.',
      errBadLink: 'This link is invalid or has expired.',
    },
  };
  Object.assign(dict.th, {
    passwordHint: 'ใช้ 6 ตัวอักษรขึ้นไป มี a–z, A–Z, ตัวเลข และสัญลักษณ์ อย่างน้อยประเภทละ 1 ตัว',
    networkTitle: 'ยังเชื่อมต่อไม่ได้', securityLabel: 'พื้นที่ส่วนตัวของคุณ', retry: 'ลองอีกครั้ง',
    errNetwork: 'ยังเชื่อมต่อไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
    errPolicy: 'รหัสผ่านยังไม่ตรงตามเงื่อนไขของบัญชี กรุณาเลือกวลีอื่นที่ยาวอย่างน้อย 6 ตัวอักษร',
    showPassword: 'แสดงรหัสผ่าน', hidePassword: 'ซ่อนรหัสผ่าน',
    passwordMatch: 'รหัสผ่านตรงกันแล้ว',
  });
  Object.assign(dict.en, {
    passwordHint: 'Use at least 6 characters with at least 1 lowercase letter, uppercase letter, number and symbol.',
    networkTitle: 'Unable to connect', securityLabel: 'Your personal space', retry: 'Try again',
    errNetwork: 'Unable to connect. Check your internet connection and try again.',
    errPolicy: 'This password does not meet your account policy. Choose a different passphrase of at least 6 characters.',
    showPassword: 'Show password', hidePassword: 'Hide password',
    passwordMatch: 'Passwords match',
  });
  const T = isEN ? dict.en : dict.th;
  document.title = 'BUDGETMATE · ' + T.formTitle;
  if (isEN) document.documentElement.lang = 'en';

  document.querySelectorAll('[data-i18n]').forEach((el) => {
    const key = el.getAttribute('data-i18n');
    if (T[key]) el.textContent = T[key];
  });
  document.querySelectorAll('[data-i18n-placeholder]').forEach((el) => {
    const key = el.getAttribute('data-i18n-placeholder');
    if (T[key]) el.placeholder = T[key];
  });

  const show = (id) => {
    ['state-loading', 'state-invalid', 'state-form', 'state-success'].forEach((s) => {
      document.getElementById(s).classList.toggle('hidden', s !== id);
    });
  };

  function apiUrl(path) {
    return 'https://identitytoolkit.googleapis.com/v1/accounts:' + path + '?key=' + encodeURIComponent(apiKey);
  }

  if (mode !== 'resetPassword' || !oobCode || !apiKey) {
    show('state-invalid');
    return;
  }

  async function requestReset(body) {
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 15000);
    try {
      const res = await fetch(apiUrl('resetPassword'), {
        method: 'POST', headers: {'Content-Type': 'application/json'},
        body: JSON.stringify(body), signal: controller.signal,
      });
      const data = await res.json();
      return {ok: res.ok, data};
    } finally { clearTimeout(timeout); }
  }

  const retryBtn = document.getElementById('retry-btn');
  const invalidDescription = document.getElementById('invalid-description');
  function invalidLink(retryable) {
    document.getElementById('invalid-title').textContent = retryable ? T.networkTitle : T.invalidTitle;
    invalidDescription.textContent = retryable ? T.errNetwork : T.invalidDesc;
    retryBtn.classList.toggle('hidden', !retryable);
    show('state-invalid');
  }
  async function verify() {
    show('state-loading');
    try {
      const {ok, data} = await requestReset({oobCode});
      if (!ok || !data.email) {
        const code = data.error?.message || '';
        invalidLink(!/EXPIRED_OOB_CODE|INVALID_OOB_CODE|USER_DISABLED|USER_NOT_FOUND/.test(code));
        return;
      }
      document.getElementById('account-email').textContent = data.email;
      show('state-form');
    } catch (_) { invalidLink(true); }
  }
  retryBtn.addEventListener('click', verify);
  verify();

  // ---- ฟอร์มตั้งรหัสผ่านใหม่ ----
  const form = document.getElementById('reset-form');
  const newPw = document.getElementById('new-password');
  const confirmPw = document.getElementById('confirm-password');
  const wrapNew = document.getElementById('wrap-new');
  const wrapConfirm = document.getElementById('wrap-confirm');
  const matchHint = document.getElementById('match-hint');
  const submitBtn = document.getElementById('submit-btn');
  const errorBanner = document.getElementById('form-error');
  const errorText = document.getElementById('form-error-text');

  document.querySelectorAll('.eye-btn').forEach((btn) => {
    btn.setAttribute('aria-label', T.showPassword);
    btn.setAttribute('aria-pressed', 'false');
    btn.addEventListener('click', () => {
      const input = document.getElementById(btn.getAttribute('data-target'));
      input.type = input.type === 'password' ? 'text' : 'password';
      btn.setAttribute('aria-label', input.type === 'text' ? T.hidePassword : T.showPassword);
      btn.setAttribute('aria-pressed', String(input.type === 'text'));
    });
  });

  function clearError() {
    errorBanner.classList.add('hidden');
    wrapNew.classList.remove('has-error');
    wrapConfirm.classList.remove('has-error');
    matchHint.textContent = '';
  }

  function showError(msg) {
    errorText.textContent = msg;
    errorBanner.classList.remove('hidden');
  }

  const policyMessages = {
    password_lowercase: isEN ? 'At least 1 lowercase letter (a–z)' : 'ตัวพิมพ์เล็ก a–z อย่างน้อย 1 ตัว',
    password_uppercase: isEN ? 'At least 1 uppercase letter (A–Z)' : 'ตัวพิมพ์ใหญ่ A–Z อย่างน้อย 1 ตัว',
    password_digit: isEN ? 'At least 1 number (0–9)' : 'ตัวเลข 0–9 อย่างน้อย 1 ตัว',
    password_symbol: isEN ? 'At least 1 symbol, such as ! @ #' : 'สัญลักษณ์ เช่น ! @ # อย่างน้อย 1 ตัว',
 password_min_length: T.errTooShort, password_max_length: T.errTooLong, password_common: T.errCommon };
  function passwordError(value) {
    const key = window.BudgetmatePasswordPolicy.validate(value);
    return key ? policyMessages[key] : null;
  }
  [newPw, confirmPw].forEach(input => input.addEventListener('input', () => {
    clearError();
    document.getElementById('policy-status').textContent = newPw.value ? (passwordError(newPw.value) || T.policyValid) : '';
    if (confirmPw.value && newPw.value === confirmPw.value) matchHint.textContent = T.passwordMatch;
  }));
  let saving = false;
  form.addEventListener('submit', async function (e) {
    e.preventDefault();
    if (saving) return;
    clearError();

    const pw1 = newPw.value;
    const pw2 = confirmPw.value;

    const invalid = passwordError(pw1);
    if (invalid) {
      wrapNew.classList.add('has-error');
      showError(invalid);
      newPw.focus();
      return;
    }
    if (!pw2) {
      wrapConfirm.classList.add('has-error');
      showError(T.errConfirm);
      confirmPw.focus();
      return;
    }
    if (pw1 !== pw2) {
      wrapConfirm.classList.add('has-error');
      showError(T.errMismatch);
      confirmPw.focus();
      return;
    }

    saving = true;
    submitBtn.disabled = true;
    newPw.disabled = confirmPw.disabled = true;
    submitBtn.textContent = T.submitBtnLoading;
    form.setAttribute('aria-busy', 'true');
    try {
      const {ok, data} = await requestReset({oobCode, newPassword: pw1});
      if (!ok) {
        const code = data.error?.message || '';
        if (/EXPIRED_OOB_CODE|INVALID_OOB_CODE/.test(code)) {
          invalidLink(false);
          return;
        }
        showError(/WEAK_PASSWORD|PASSWORD_DOES_NOT_MEET_REQUIREMENTS/.test(code) ? T.errPolicy : T.errGeneric);
        return;
      }
      newPw.value = confirmPw.value = '';
      show('state-success');
    } catch (_) { showError(T.errNetwork); }
    finally {
      saving = false;
      submitBtn.disabled = false;
      newPw.disabled = confirmPw.disabled = false;
      submitBtn.textContent = T.submitBtn;
      form.setAttribute('aria-busy', 'false');
    }
  });
})();
