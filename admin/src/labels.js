// Display labels for API values, and the checklist an admin works through for each review.

export const ROLE_LABELS = { owner: 'Project Owner', investor: 'Investor', buyer: 'Buyer' };

// Verification status. "Suspended" comes from the account (or listing) status, not the review.
export const REVIEW_LABELS = {
  unreviewed: 'Not submitted',
  pending: 'Pending',
  under_review: 'Under Review',
  needs_evidence: 'More evidence requested',
  approved: 'Verified',
  rejected: 'Rejected',
  expired: 'Expired',
  suspended: 'Suspended',
};

// Listings use the same statuses; "more evidence" is "changes requested" for a project.
export const LISTING_REVIEW_LABELS = { ...REVIEW_LABELS, needs_evidence: 'Changes requested' };

export const REVIEW_COLORS = {
  unreviewed: 'default',
  pending: 'warning',
  under_review: 'info',
  needs_evidence: 'secondary',
  approved: 'success',
  rejected: 'error',
  expired: 'default',
  suspended: 'error',
};

/** The status an admin should see: a suspended account is "Suspended" whatever its review says. */
export const verificationStatus = (reviewStatus, accountStatus) => (accountStatus === 'suspended' ? 'suspended' : reviewStatus);

export const DECISION_LABELS = {
  approve: 'Verified',
  reject: 'Rejected',
  request_more: 'Requested more evidence',
  suspend: 'Suspended',
  reinstate: 'Reinstated',
};

export const LISTING_DECISION_LABELS = { ...DECISION_LABELS, request_more: 'Requested changes' };

export const DOCUMENT_LABELS = {
  cnic_front: 'CNIC (front)',
  cnic_back: 'CNIC (back)',
  university_id_front: 'University ID (front)',
  university_id_back: 'University ID (back)',
  company_registration: 'Company registration / business profile',
  network_affiliation: 'VC / angel network affiliation',
  accelerator_affiliation: 'Accelerator / incubator affiliation',
  investment_portfolio: 'Public investment portfolio',
  professional_credential: 'Professional credentials',
  ownership_proof: 'Ownership evidence',
  project_evidence: 'Project evidence',
};

export const BUYER_TYPES = { individual: 'Individual', small_business: 'Small business', agency: 'Software agency', other: 'Other' };
export const STAGES = { idea: 'Idea', prototype: 'Prototype', mvp: 'MVP', launched: 'Launched' };
export const LISTING_TYPES = { funding: 'Seeking Funding', sale: 'Available for Purchase' };

/** 1500000 → "PKR 1,500,000" */
export const pkr = n => (n == null ? '—' : `PKR ${Math.round(n).toLocaleString('en-PK')}`);

export const range = (min, max) => (min == null ? null : `${pkr(min)} – ${max == null ? 'and above' : pkr(max)}`);

export const dateTime = iso => (iso ? new Date(iso).toLocaleString('en-PK', { dateStyle: 'medium', timeStyle: 'short' }) : '—');

// ---------- checklists ----------

/** What the admin must confirm before verifying an account; depends on the role and its answers. */
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
      'Identity: the name matches the LinkedIn profile',
      'Organization and designation match LinkedIn',
    );
    if (d.companyWebsite) items.push('Company website works and belongs to the organization');
    items.push(
      'Every piece of evidence opens and is in this person\'s or organization\'s name',
      'The evidence supports the claimed affiliations and portfolio',
      'Investment stages and range are consistent with the evidence',
    );
  } else if (profile.role === 'buyer') {
    items.push('Phone number looks valid', 'LinkedIn profile opens and belongs to this person');
    if (d.affiliation === 'university') items.push('University ID card is clear and the name matches');
    else items.push('Company name and company email match');
  }
  return items;
}

export const LISTING_CHECKLIST = [
  'The owner\'s account is verified and matches the project',
  'Ownership evidence shows the owner made or owns the project',
  'Project evidence shows the project exists as described',
  'Every claim requiring review is backed by the evidence',
  'The public preview contains no confidential information',
  'Title, description, category and photos describe the project honestly',
];

/** The statements in a listing an admin must check against the evidence. */
export function listingClaims(l, c) {
  return [
    ['Stage', `${STAGES[l.projectStage]}${l.projectStage === 'launched' ? ' (should have a live link or users)' : ''}`],
    [l.listingType === 'funding' ? 'Funding needed' : 'Asking price', pkr(l.askingAmount)],
    l.listingType === 'funding' && ['Equity offered', c?.equityOfferedPercent == null ? null : `${c.equityOfferedPercent}%`],
    ['Tech stack', l.techStack.join(', ')],
    ['Financial summary', c?.financialSummary],
    ['Ownership notes', c?.ipOwnershipNotes],
    l.listingType === 'sale' && ['What the buyer receives', c?.transferDetails],
  ];
}
