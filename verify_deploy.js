const https = require('https');

const data = JSON.stringify({ email: 'test@gmail.com', password: 'password' });

const options = {
  hostname: 'mlmpropertyebn.vercel.app',
  port: 443,
  path: '/api/auth/signin',
  method: 'POST',
  headers: { 'Content-Type': 'application/json', 'Content-Length': data.length }
};

const req = https.request(options, (res) => {
  let body = '';
  res.on('data', d => body += d);
  res.on('end', () => {
    const json = JSON.parse(body);
    console.log(`Status: ${res.statusCode}`);
    console.log(`accountStatus: ${json.accountStatus}`);
    console.log(`pendingRole: ${json.pendingRole}`);
    console.log(`error: ${json.error}`);
    if (res.statusCode === 403 && json.accountStatus === 'pending_payment') {
      console.log('\n✅ BACKEND IS CORRECT - returns 403 for pending users');
    } else if (res.statusCode === 200) {
      console.log('\n❌ BACKEND STILL OLD - returns 200, deploy not live yet');
    }
  });
});
req.on('error', e => console.error(e));
req.write(data);
req.end();
