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

// Result of an admin review of an account or a listing.
const REVIEW_TEXT = {
  account: {
    approve: { subject: 'Your Orwickle account is approved', line: 'Good news — your account has been approved. You now have full access to Orwickle.' },
    reject: { subject: 'Your Orwickle account was not approved', line: 'Your account was not approved. Please update your profile and it will be reviewed again.' },
    request_more: { subject: 'More information needed for your Orwickle account', line: 'An administrator needs more information before approving your account. Please update your profile.' },
    suspend: { subject: 'Your Orwickle account has been suspended', line: 'Your account has been suspended by an administrator. You cannot log in until it is reinstated.' },
    reinstate: { subject: 'Your Orwickle account is active again', line: 'Your account has been reinstated. You can log in again.' },
  },
  listing: {
    approve: { subject: 'Your listing is live on Orwickle', line: 'Your listing has been approved and is now visible to investors and buyers.' },
    reject: { subject: 'Your listing needs changes', line: 'Your listing was not approved and has been moved back to draft. Please update it and publish again.' },
  },
};

function reviewEmail({ kind, decision, name, reason, title }) {
  const { subject, line } = REVIEW_TEXT[kind][decision];
  const about = title ? `\n\nListing: ${title}` : '';
  const why = reason ? `\n\nNote from the reviewer: ${reason}` : '';
  const text = `Hi ${name},\n\n${line}${about}${why}\n\n— Orwickle`;
  const html = `
    <div style="font-family:Arial,sans-serif;max-width:480px;margin:auto;color:#1b1b1f">
      <h2 style="color:#1F4E79">Orwickle</h2>
      <p>Hi ${escapeHtml(name)},</p>
      <p>${line}</p>
      ${title ? `<p><b>Listing:</b> ${escapeHtml(title)}</p>` : ''}
      ${reason ? `<p style="background:#f2f4f7;padding:12px;border-radius:8px"><b>Note from the reviewer:</b> ${escapeHtml(reason)}</p>` : ''}
    </div>`;
  return { subject, text, html };
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, ch =>
    ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[ch]);
}

module.exports = { otpEmail, reviewEmail };
