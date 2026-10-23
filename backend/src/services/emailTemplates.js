// Email content for OTP messages. Plain text plus a simple HTML version.

const PURPOSE = {
  email_verify: {
    subject: 'Verify your Orwickle account',
    intro: 'Use this code to verify your email address:',
  },
  password_reset: {
    subject: 'Reset your Orwickle password',
    intro: 'Use this code to reset your password:',
  },
};

function otpEmail({ type, name, code, validMinutes }) {
  const { subject, intro } = PURPOSE[type];
  const text =
    `Hi ${name},\n\n${intro}\n\n${code}\n\n` +
    `This code expires in ${validMinutes} minutes. If you did not request it, you can ignore this email.\n\n` +
    '— Orwickle';
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#1b1b1f">
      <h2 style="color:#1F4E79">Orwickle</h2>
      <p>Hi ${escapeHtml(name)},</p>
      <p>${intro}</p>
      <p style="font-size:32px;font-weight:bold;letter-spacing:8px;color:#1F4E79">${code}</p>
      <p style="color:#555">This code expires in ${validMinutes} minutes.
         If you did not request it, you can ignore this email.</p>
    </div>`;
  return { subject, text, html };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, ch =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
}

module.exports = { otpEmail };
