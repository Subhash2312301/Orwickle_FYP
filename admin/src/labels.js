// Display labels for API values, and the checklist an admin works through for each review.

export const ROLE_LABELS = { owner: 'Project Owner', investor: 'Investor', buyer: 'Buyer' };

export const REVIEW_LABELS = {
  unreviewed: 'Profile not submitted',
  pending: 'Waiting for review',
  approved: 'Approved',
  rejected: 'Rejected',
  needs_evidence: 'More information requested',
};

export const REVIEW_COLORS = {
  unreviewed: 'default',
  pending: 'warning',
  approved: 'success',
  rejected: 'error',
  needs_evidence: 'info',
};

export const DECISION_LABELS = {
  approve: 'Approved',
  reject: 'Rejected',
  request_more: 'Asked for more information',
  suspend: 'Suspended',
  reinstate: 'Reinstated',
};

export const DOCUMENT_LABELS = {
  cnic_front: 'CNIC (front)',
  cnic_back: 'CNIC (back)',
  university_id_front: 'University ID (front)',
  university_id_back: 'University ID (back)',
  company_certificate: 'Company registration certificate',
  funds_proof: 'Proof of funds',
  investment_proof: 'Proof of a past investment',
};

export const INVESTOR_TYPES = { individual: 'Individual investor', angel: 'Angel investor', firm: 'Investment firm / VC', other: 'Other' };
export const BUYER_TYPES = { individual: 'Individual', small_business: 'Small business', agency: 'Software agency', other: 'Other' };
export const EXPERIENCE = { first_time: 'First investment', '1_3': '1–3 startups', '4_10': '4–10 startups', '10_plus': 'More than 10 startups' };
export const STAGES = { idea: 'Idea', prototype: 'Prototype', mvp: 'MVP', launched: 'Launched' };
export const LISTING_TYPES = { funding: 'Seeking Funding', sale: 'Available for Purchase' };

/** 1500000 → "PKR 1,500,000" */
export const pkr = n => (n == null ? '—' : `PKR ${Math.round(n).toLocaleString('en-PK')}`);

export const dateTime = iso => (iso ? new Date(iso).toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' }) : '—');

/** 4210112345671 → 42101-1234567-1 (admins see the full number to compare with the photo) */
export const cnic = v => (v && v.length === 13 ? `${v.slice(0, 5)}-${v.slice(5, 12)}-${v.slice(12)}` : v || '—');

// ---------- checklists ----------

/** What the admin must confirm before approving an account; depends on the role and its answers. */
export function accountChecklist(profile) {
  const d = profile.details || {};
  const items = [];
  if (profile.role === 'owner') {
    if (d.isStudent) {
      items.push('University ID card is clear and the name matches', 'University and degree look genuine');
    } else {
      items.push('CNIC photos are clear and the name matches');
    }
    items.push('LinkedIn profile opens and belongs to this person', 'GitHub profile shows real work', 'Portfolio link works');
  } else if (profile.role === 'investor') {
    items.push(
      'CNIC photos are clear and the name matches',
      'CNIC number matches the CNIC photo',
      'LinkedIn profile opens and belongs to this person',
      'Professional affiliation looks genuine',
    );
    if (d.investorType === 'firm') {
      items.push('Company certificate matches the company name', 'Company website works and matches the company email');
    } else {
      items.push('Proof of funds is recent, in this name and fits the chosen range');
    }
    if (d.investmentExperience && d.investmentExperience !== 'first_time') {
      items.push('Past investment proof matches the investment history');
    }
  } else if (profile.role === 'buyer') {
    items.push('Phone number looks valid', 'LinkedIn profile opens and belongs to this person');
    if (d.affiliation === 'university') items.push('University ID card is clear and the name matches');
    else items.push('Company name and company email match');
  }
  return items;
}

export const LISTING_CHECKLIST = [
  'The public preview contains no confidential information',
  'Title, description and category describe the project honestly',
  'Photos are appropriate and show this project',
  'Amount and equity look reasonable',
  'Confidential details are complete',
  'Ownership notes are believable',
];
