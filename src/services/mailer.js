// Transactional email via Brevo's HTTP API (https://api.brevo.com/v3/smtp/email).
//
// This deliberately uses a plain fetch() call rather than an SMTP client
// (nodemailer et al). The backend runs on Vercel as a serverless function:
// every invocation is a fresh, short-lived process, so there's no good way
// to keep a pooled SMTP connection alive between requests, and some Vercel
// plans/regions block outbound SMTP ports (25/465/587) entirely. A single
// stateless HTTPS request has none of those problems and needs zero extra
// npm dependencies (Node 18+ ships a global fetch).
//
// BREVO_API_KEY / BREVO_SENDER_EMAIL / BREVO_SENDER_NAME are read from the
// environment (see .env.example). Until BREVO_API_KEY is set, sends fall
// back to logging the code to the server console instead of throwing — so
// forgot-password and email-verification both work end-to-end in local
// dev, and start actually emailing the moment a real key is added, with no
// code change needed.

const BREVO_ENDPOINT = 'https://api.brevo.com/v3/smtp/email';

function getSender() {
  return {
    email: process.env.BREVO_SENDER_EMAIL || 'no-reply@example.com',
    name: process.env.BREVO_SENDER_NAME || 'EBN',
  };
}

/**
 * Low-level send. Never throws — a failed send (or missing API key) is
 * logged and swallowed by the caller-specific wrappers below, since
 * callers like /forgot-password must always respond the same way whether
 * or not the email actually goes out (avoids leaking account existence /
 * breaking the UX on a transient provider error).
 */
async function sendViaBrevo({ to, toName, subject, text, html }) {
  const apiKey = process.env.BREVO_API_KEY;
  if (!apiKey) {
    return { delivered: false, reason: 'not_configured' };
  }

  try {
    const res = await fetch(BREVO_ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
        'api-key': apiKey,
      },
      body: JSON.stringify({
        sender: getSender(),
        to: [{ email: to, name: toName || undefined }],
        subject,
        textContent: text,
        htmlContent: html,
      }),
    });

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      console.error(`[mailer] Brevo send failed (${res.status})`, body);
      return { delivered: false, reason: 'send_failed' };
    }

    return { delivered: true };
  } catch (err) {
    console.error('[mailer] Brevo request threw', err);
    return { delivered: false, reason: 'request_error' };
  }
}

/** Sends the password-reset code to `to`. */
async function sendPasswordResetEmail({ to, fullName, resetCode }) {
  const subject = 'Reset your EBN password';
  const text =
    `Hi ${fullName || 'there'},\n\n` +
    `We received a request to reset your EBN password. Use this code in the app:\n\n` +
    `  ${resetCode}\n\n` +
    `This code expires in 30 minutes. If you didn't request this, you can ignore this email.\n`;
  const html =
    `<p>Hi ${fullName || 'there'},</p>` +
    `<p>We received a request to reset your EBN password. Use this code in the app:</p>` +
    `<p style="font-size:24px;font-weight:700;letter-spacing:4px;">${resetCode}</p>` +
    `<p>This code expires in 30 minutes. If you didn't request this, you can ignore this email.</p>`;

  const result = await sendViaBrevo({ to, toName: fullName, subject, text, html });
  if (!result.delivered) {
    console.log(`[mailer] password reset code for ${to}: ${resetCode}`);
  }
  return result;
}

/** Sends the "verify your email" code to `to` after signup. */
async function sendVerificationEmail({ to, fullName, verifyCode }) {
  const subject = 'Verify your EBN email address';
  const text =
    `Hi ${fullName || 'there'},\n\n` +
    `Welcome to EBN! Use this code in the app to verify your email address:\n\n` +
    `  ${verifyCode}\n\n` +
    `This code expires in 30 minutes. If you didn't create an EBN account, you can ignore this email.\n`;
  const html =
    `<p>Hi ${fullName || 'there'},</p>` +
    `<p>Welcome to EBN! Use this code in the app to verify your email address:</p>` +
    `<p style="font-size:24px;font-weight:700;letter-spacing:4px;">${verifyCode}</p>` +
    `<p>This code expires in 30 minutes. If you didn't create an EBN account, you can ignore this email.</p>`;

  const result = await sendViaBrevo({ to, toName: fullName, subject, text, html });
  if (!result.delivered) {
    console.log(`[mailer] email verification code for ${to}: ${verifyCode}`);
  }
  return result;
}

module.exports = { sendPasswordResetEmail, sendVerificationEmail };
