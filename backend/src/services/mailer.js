// Sends emails through Gmail SMTP (nodemailer).
// Without SMTP settings (development) the email is printed to the console instead,
// and in tests it is kept in `outbox` so tests can read the OTP.

const nodemailer = require('nodemailer');
const env = require('../config/env');

const transport = env.smtp.configured
  ? nodemailer.createTransport({
      host: env.smtp.host,
      port: env.smtp.port,
      secure: env.smtp.port === 465,
      auth: { user: env.smtp.user, pass: env.smtp.pass },
    })
  : null;

const outbox = [];   // test mode only

async function sendMail({ to, subject, text, html }) {
  if (env.isTest) {
    outbox.push({ to, subject, text });
    return;
  }
  if (!transport) {
    console.log(`\n[dev email] to: ${to}\nsubject: ${subject}\n${text}\n`);
    return;
  }
  await transport.sendMail({ from: env.mailFrom, to, subject, text, html });
}

module.exports = { sendMail, outbox };
