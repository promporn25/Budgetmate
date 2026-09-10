(function () {
  const params = new URLSearchParams(window.location.search);
  const mode = params.get('mode');
  const oobCode = params.get('oobCode');
  const apiKey = params.get('apiKey');
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
      errGeneric: 'Something went wrong. Please try again.',
      errBadLink: 'This link is invalid or has expired.',
    },
  };
  Object.assign(dict.th, {
    passwordHint: 'อย่างน้อย 6 ตัวอักษร และควรใช้รหัสที่ไม่ซ้ำกับบัญชีอื่น',
    networkTitle: 'ยังเชื่อมต่อไม่ได้', securityLabel: 'พื้นที่ส่วนตัวของคุณ', retry: 'ลองอีกครั้ง',
    errNetwork: 'ยังเชื่อมต่อไม่ได้ ตรวจอินเทอร์เน็ตแล้วลองอีกครั้ง',
    errPolicy: 'รหัสผ่านยังไม่ตรงตามเงื่อนไขของบัญชี ลองใช้รหัสที่ยาวขึ้นและผสมตัวอักษร ตัวเลข และสัญลักษณ์',
    showPassword: 'แสดงรหัสผ่าน', hidePassword: 'ซ่อนรหัสผ่าน',
    passwordMatch: 'รหัสผ่านตรงกันแล้ว',
  });
  Object.assign(dict.en, {
    passwordHint: 'At least 6 characters. Use a password you do not use elsewhere.',
    networkTitle: 'Unable to connect', securityLabel: 'Your personal space', retry: 'Try again',
    errNetwork: 'Unable to connect. Check your internet connection and try again.',
    errPolicy: 'This password does not meet your account policy. Try a longer password with letters, numbers and symbols.',
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

  [newPw, confirmPw].forEach(input => input.addEventListener('input', () => {
    clearError();
    if (confirmPw.value && newPw.value === confirmPw.value) matchHint.textContent = T.passwordMatch;
  }));
  let saving = false;
  form.addEventListener('submit', async function (e) {
    e.preventDefault();
    if (saving) return;
    clearError();

    const pw1 = newPw.value;
    const pw2 = confirmPw.value;

    if (pw1.length < 6) {
      wrapNew.classList.add('has-error');
      showError(T.errTooShort);
      newPw.focus();
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
