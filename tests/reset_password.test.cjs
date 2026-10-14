const {test} = require('node:test');
const assert = require('node:assert/strict');
const {readFileSync} = require('node:fs');
const vm = require('node:vm');
const script = readFileSync('public/password_policy.js', 'utf8') + '\n' + readFileSync('public/reset_password.js', 'utf8');
function setup(replies, search = '?mode=resetPassword&oobCode=test-code&apiKey=test-key&lang=th') {
  const nodes = new Map();
  function element(id) {
    if (nodes.has(id)) return nodes.get(id);
    const classes = new Set(id.startsWith('state-') && id !== 'state-loading' ? ['hidden'] : []);
    const el = {value:'', textContent:'', type:'password', disabled:false, attrs:{}, handlers:{},
      classList:{add:c=>classes.add(c),remove:c=>classes.delete(c),contains:c=>classes.has(c),toggle(c,on){on ? classes.add(c) : classes.delete(c);}},
      addEventListener(name, fn){this.handlers[name]=fn;},setAttribute(k,v){this.attrs[k]=v;},getAttribute(k){return this.attrs[k];},focus(){this.focused=true;}};
    nodes.set(id,el);return el;
  }
  const calls=[];
  let redirected;
  vm.runInNewContext(script, {URL,URLSearchParams,AbortController,setTimeout,clearTimeout,
    window:{location:{search,replace:url=>{redirected=url;}}},document:{documentElement:{lang:'th'},getElementById:element,querySelectorAll:()=>[]},
    fetch:async (url,options)=>{calls.push({url,body:JSON.parse(options.body)});const next=replies.shift();if(next instanceof Error)throw next;return {ok:next.ok ?? true,json:async()=>next.data ?? next};}});
  return {element,calls,get redirected(){return redirected;},flush:()=>new Promise(resolve=>setImmediate(resolve)),
    submit:()=>element('reset-form').handlers.submit({preventDefault(){}})};
}
test('missing reset code shows invalid state without requests',()=>{
  const s=setup([], '');assert.equal(s.element('state-invalid').classList.contains('hidden'),false);assert.equal(s.calls.length,0);
});
test('verified account opens form and mismatched passwords never submit',async()=>{
  const s=setup([{email:'sample@example.com'}]);await s.flush();
  assert.equal(s.element('state-form').classList.contains('hidden'),false);
  s.element('new-password').value='Violet-river-cloud-29';s.element('confirm-password').value='different-123';await s.submit();
  assert.equal(s.calls.length,1);assert.equal(s.element('confirm-password').focused,true);
});
test('successful reset submits once and clears both password fields',async()=>{
  const s=setup([{email:'sample@example.com'},{email:'sample@example.com'}]);await s.flush();
  s.element('new-password').value=s.element('confirm-password').value='Violet-river-cloud-29';
  const first=s.submit();await s.submit();await first;
  assert.equal(s.calls.length,2);assert.deepEqual(s.calls[1].body,{oobCode:'test-code',newPassword:'Violet-river-cloud-29'});
  assert.equal(s.element('state-success').classList.contains('hidden'),false);
  assert.equal(s.element('new-password').value,'');assert.equal(s.element('confirm-password').value,'');
});
test('network verification failure offers retry, then opens form',async()=>{
  const s=setup([new Error('offline'),{email:'sample@example.com'}]);await s.flush();
  assert.equal(s.element('retry-btn').classList.contains('hidden'),false);
  await s.element('retry-btn').handlers.click();assert.equal(s.element('state-form').classList.contains('hidden'),false);
});
test('expired link does not offer network retry',async()=>{
  const s=setup([{ok:false,data:{error:{message:'EXPIRED_OOB_CODE'}}}]);await s.flush();
  assert.equal(s.element('state-invalid').classList.contains('hidden'),false);assert.equal(s.element('retry-btn').classList.contains('hidden'),true);
});
test('backend password policy error retains fields and enables retry',async()=>{
  const s=setup([{email:'sample@example.com'},{ok:false,data:{error:{message:'PASSWORD_DOES_NOT_MEET_REQUIREMENTS'}}}]);await s.flush();
  s.element('new-password').value=s.element('confirm-password').value='Violet-river-cloud-29';await s.submit();
  assert.equal(s.element('submit-btn').disabled,false);assert.equal(s.element('new-password').value,'Violet-river-cloud-29');assert.match(s.element('form-error-text').textContent,/เงื่อนไข/);
});

test('other email actions retain the trusted Firebase default handler',()=>{
  const s=setup([], '?mode=verifyEmail&oobCode=test-code&apiKey=test-key');
  const target=new URL(s.redirected);
  assert.equal(target.origin,'https://budgetmate-app-a94da.firebaseapp.com');
  assert.equal(target.pathname,'/__/auth/action');
  assert.equal(target.searchParams.get('mode'),'verifyEmail');
  assert.equal(target.searchParams.get('oobCode'),'test-code');
  assert.equal(s.calls.length,0);
});

test('numeric-only passwords never submit a reset request', async () => {
  const s = setup([{email:'sample@example.com'}]); await s.flush();
  s.element('new-password').value = s.element('confirm-password').value = '123456789012345';
  await s.submit();
  assert.equal(s.calls.length, 1);
  assert.match(s.element('form-error-text').textContent, /เดาง่าย/);
});

test('valid password preserves leading and trailing spaces', async () => {
  const s = setup([{email:'sample@example.com'}, {}]); await s.flush();
  s.element('new-password').value = s.element('confirm-password').value = '  Violet river cloud 29!  ';
  await s.submit();
  assert.equal(s.calls[1].body.newPassword, '  Violet river cloud 29!  ');
});
test('unicode code points and maximum length are validated without requests', async () => {
  for (const password of ['🌻'.repeat(14), 'x'.repeat(129)]) {
    const s = setup([{email:'sample@example.com'}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit(); assert.equal(s.calls.length, 1);
  }
});
test('empty confirmation produces a specific message', async () => {
  const s = setup([{email:'sample@example.com'}]); await s.flush();
  s.element('new-password').value = 'Violet river cloud 29!'; await s.submit();
  assert.equal(s.calls.length, 1);
  assert.match(s.element('form-error-text').textContent, /กรุณากรอกยืนยัน/);
});

test('missing character classes never submit a reset request', async () => {
  for (const password of ['VIOLET RIVER 29!', 'violet river 29!', 'Violet river abc!', 'Violet river 290']) {
    const s = setup([{email:'user@example.com'}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit();
    assert.equal(s.calls.length, 1);
  }
});

test('six-character mixed password is accepted, five characters are rejected', async () => {
  for (const [password, expectedCalls] of [['Aa1!x', 1], ['Aa1!xy', 2]]) {
    const s = setup([{email: 'user@example.com'}, {}]); await s.flush();
    s.element('new-password').value = s.element('confirm-password').value = password;
    await s.submit();
    assert.equal(s.calls.length, expectedCalls);
  }
});
