const https = require('https');

// Test 1: New agent signup
function testSignup() {
  const data = JSON.stringify({
    fullName: 'Test Agent',
    email: `testagent_${Date.now()}@gmail.com`,
    password: 'password123',
    role: 'user',
    requestedRole: 'agent',
    phone: '0912345678',
    agencyOrLicense: 'Test Agency'
  });

  const options = {
    hostname: 'mlmpropertyebn.vercel.app',
    port: 443,
    path: '/api/auth/signup',
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
  };

  const req = https.request(options, (res) => {
    let body = '';
    res.on('data', d => body += d);
    res.on('end', () => {
      const json = JSON.parse(body);
      console.log('=== SIGNUP RESPONSE ===');
      console.log(`HTTP Status: ${res.statusCode}`);
      console.log(`isPendingPayment: ${json.isPendingPayment}`);
      console.log(`user.role: ${json.user?.role}`);
      console.log(`user.accountStatus: ${json.user?.accountStatus}`);
      console.log(`user.pendingRole: ${json.user?.pendingRole}`);
      if (json.isPendingPayment) {
        console.log('\n✅ SIGNUP CORRECT - returns isPendingPayment:true');
      } else {
        console.log('\n❌ SIGNUP WRONG - user goes straight to dashboard');
      }
    });
  });
  req.on('error', e => console.error(e));
  req.write(data);
  req.end();
}

testSignup();
