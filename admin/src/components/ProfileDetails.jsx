// A user's profile as the admin needs to check it: identity, professional / role details and evidence.

import { Avatar, Box, Card, CardContent, Chip, Stack, Typography } from '@mui/material';
import { Fields } from './common';
import { EvidenceList } from './Verification';
import { BUYER_TYPES, ROLE_LABELS, STAGES, dateTime, range } from '../labels';

function identityRows(p, user) {
  return [
    ['Full name', p.fullName],
    ['Email', user?.email || p.email],
    user && ['Email verified', user.emailVerified ? 'Yes' : 'No'],
    user && ['Registered', dateTime(user.registeredAt)],
    ['LinkedIn', p.linkedinUrl],
    p.role === 'buyer' && ['City', p.city],
    p.role === 'buyer' && ['Phone', p.phone],
  ];
}

function roleRows(p) {
  const d = p.details || {};
  const categories = (d.interests || []).map(i => i.name).join(', ');
  if (p.role === 'owner') {
    return [
      ['Headline', p.headline],
      ['Bio', p.bio],
      ['Background', d.isStudent == null ? null : d.isStudent ? 'University student' : 'Independent developer'],
      d.isStudent && ['University', d.university],
      d.isStudent && ['Degree program', d.degreeProgram],
      ['Skills', (d.skills || []).join(', ')],
      ['GitHub', d.githubUrl],
      ['Portfolio', d.portfolioUrl],
      ['Website', p.websiteUrl],
    ];
  }
  if (p.role === 'investor') {
    return [
      ['Organization / company', d.organization],
      ['Professional designation', d.designation],
      ['Company website', d.companyWebsite],
      ['Investment interests', d.investmentInterests],
      ['Investment stage', (d.investmentStages || []).map(s => STAGES[s]).join(', ')],
      ['Sector preferences', categories],
      ['Approximate investment range', range(d.minTicket, d.maxTicket)],
    ];
  }
  return [
    ['Buyer type', BUYER_TYPES[d.buyerType]],
    ['Buying as', d.affiliation === 'company' ? 'Company' : d.affiliation === 'university' ? 'University student' : null],
    d.affiliation === 'company' && ['Company name', d.companyName],
    d.affiliation === 'company' && ['Company email', d.companyEmail],
    ['Interested in', categories],
  ];
}

/** `user` (optional) adds account facts: email verified and registration date. */
export default function ProfileDetails({ profile, user }) {
  const investor = profile.role === 'investor';
  const evidenceCount = profile.documents?.length ?? 0;
  return (
    <Stack spacing={2}>
      <Stack direction="row" spacing={2} alignItems="center">
        <Avatar src={profile.avatarUrl || undefined} sx={{ width: 56, height: 56 }}>{profile.fullName?.[0]}</Avatar>
        <Box>
          <Typography variant="h6">{profile.fullName}</Typography>
          <Stack direction="row" spacing={1} alignItems="center">
            <Chip size="small" label={ROLE_LABELS[profile.role]} color="primary" variant="outlined" />
            <Typography variant="body2" color="text.secondary">{user?.email || profile.email}</Typography>
          </Stack>
        </Box>
      </Stack>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>Identity</Typography>
          <Fields rows={identityRows(profile, user)} />
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>
            {investor ? 'Professional information' : 'Profile'}
          </Typography>
          <Fields rows={roleRows(profile)} />
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>
            {investor ? `Supporting evidence (${evidenceCount} submitted)` : 'Verification documents'}
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Click an item to open it. File links expire after one hour; reload the page if one stops working.
          </Typography>
          <EvidenceList items={profile.documents} empty="No documents uploaded." />
        </CardContent>
      </Card>
    </Stack>
  );
}
