// A user's profile as the admin needs to check it: contact details, role details and documents.

import { Avatar, Box, Card, CardContent, Chip, Stack, Typography } from '@mui/material';
import PictureAsPdfIcon from '@mui/icons-material/PictureAsPdf';
import { Fields } from './common';
import { BUYER_TYPES, DOCUMENT_LABELS, EXPERIENCE, INVESTOR_TYPES, ROLE_LABELS, cnic, pkr } from '../labels';

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
      ['LinkedIn', p.linkedinUrl],
      ['GitHub', d.githubUrl],
      ['Portfolio', d.portfolioUrl],
      ['Website', p.websiteUrl],
    ];
  }
  if (p.role === 'investor') {
    const firm = d.investorType === 'firm';
    return [
      ['City', p.city],
      ['Phone', p.phone],
      ['CNIC number', cnic(d.cnicNumber)],
      ['LinkedIn', p.linkedinUrl],
      ['Website', p.websiteUrl],
      ['Investor type', INVESTOR_TYPES[d.investorType]],
      ['Professional affiliation', d.professionalAffiliation],
      ['Experience', EXPERIENCE[d.investmentExperience]],
      d.investmentExperience !== 'first_time' && ['Investment history', d.investmentHistory],
      ['Investment portfolio', d.portfolioUrl],
      ['Usual investment', d.minTicket == null ? null : `${pkr(d.minTicket)} – ${d.maxTicket == null ? 'and above' : pkr(d.maxTicket)}`],
      ['Interested in', categories],
      firm && ['Company name', d.companyName],
      firm && ['Company website', d.companyWebsite],
      firm && ['Company email', d.companyEmail],
    ];
  }
  return [
    ['City', p.city],
    ['Phone', p.phone],
    ['LinkedIn', p.linkedinUrl],
    ['Buyer type', BUYER_TYPES[d.buyerType]],
    ['Buying as', d.affiliation === 'company' ? 'Company' : d.affiliation === 'university' ? 'University student' : null],
    d.affiliation === 'company' && ['Company name', d.companyName],
    d.affiliation === 'company' && ['Company email', d.companyEmail],
    ['Interested in', categories],
  ];
}

export function Documents({ documents }) {
  if (!documents?.length) return <Typography color="text.secondary">No documents uploaded.</Typography>;
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 2 }}>
      {documents.map(doc => (
        <Box
          key={doc.kind}
          component="a"
          href={doc.url}
          target="_blank"
          rel="noreferrer"
          sx={{ textDecoration: 'none', color: 'inherit', border: 1, borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}
        >
          {doc.contentType === 'application/pdf' ? (
            <Stack alignItems="center" justifyContent="center" sx={{ height: 120, bgcolor: 'grey.100' }}>
              <PictureAsPdfIcon color="error" fontSize="large" />
              <Typography variant="caption">Open PDF</Typography>
            </Stack>
          ) : (
            <Box component="img" src={doc.url} alt={DOCUMENT_LABELS[doc.kind]} sx={{ width: '100%', height: 120, objectFit: 'cover', display: 'block' }} />
          )}
          <Typography variant="body2" sx={{ p: 1 }}>{DOCUMENT_LABELS[doc.kind] || doc.kind}</Typography>
        </Box>
      ))}
    </Box>
  );
}

export default function ProfileDetails({ profile, email }) {
  return (
    <Stack spacing={2}>
      <Stack direction="row" spacing={2} alignItems="center">
        <Avatar src={profile.avatarUrl || undefined} sx={{ width: 56, height: 56 }}>{profile.fullName?.[0]}</Avatar>
        <Box>
          <Typography variant="h6">{profile.fullName}</Typography>
          <Stack direction="row" spacing={1} alignItems="center">
            <Chip size="small" label={ROLE_LABELS[profile.role]} color="primary" variant="outlined" />
            <Typography variant="body2" color="text.secondary">{email || profile.email}</Typography>
          </Stack>
        </Box>
      </Stack>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>Profile</Typography>
          <Fields rows={roleRows(profile)} />
        </CardContent>
      </Card>
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>Verification documents</Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mb: 2 }}>
            Click a document to open it full size. Links expire after one hour; reload the page if one stops working.
          </Typography>
          <Documents documents={profile.documents} />
        </CardContent>
      </Card>
    </Stack>
  );
}
