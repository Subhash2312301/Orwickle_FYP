// Sends emails through Gmail SMTP (nodemailer).
// Outside production the email is also printed to the console (or only printed, when SMTP is not set),
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
  // development only: the email is also shown in the terminal, which helps when testing on an emulator
  if (!env.isProduction) console.log(`\n[dev email] to: ${to}\nsubject: ${subject}\n${text}\n`);
  if (transport) await transport.sendMail({ from: env.mailFrom, to, subject, text, html });
}

module.exports = { sendMail, outbox };
