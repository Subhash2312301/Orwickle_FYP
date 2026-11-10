// Project verification queue. For each listing the admin sees the owner, the ownership and project
// evidence, the claims that need checking, the public preview and the confidential details.
// Published listings stay hidden until verified; rejected and changes-requested ones go back to draft.

import {
  Alert, Box, Button, Card, CardActionArea, CardContent, Chip, Stack, Tab, Tabs, Typography,
} from '@mui/material';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { AccountChip, Fields, Loading, PageHeader, ReviewChip, useLoad } from '../components/common';
import ReviewDialog from '../components/ReviewDialog';
import { DecisionHistory, EvidenceList } from '../components/Verification';
import {
  LISTING_CHECKLIST, LISTING_DECISION_LABELS, LISTING_REVIEW_LABELS, LISTING_TYPES, STAGES, dateTime, listingClaims, pkr,
} from '../labels';

const QUEUES = ['pending', 'under_review', 'needs_evidence', 'expired', 'rejected', 'approved'];
const DECIDABLE = ['pending', 'under_review'];

const DECISIONS = [
  { value: 'approve', label: 'Approve' },
  { value: 'request_more', label: 'Request changes' },
  { value: 'reject', label: 'Reject' },
];

const DONE_TEXT = { approve: 'is now live', request_more: 'was sent back for changes', reject: 'was rejected and moved to draft' };

function Section({ title, children, sx }) {
  return (
    <Card sx={sx}>
      <CardContent>
        <Typography variant="subtitle1" fontWeight={600} gutterBottom>{title}</Typography>
        {children}
      </CardContent>
    </Card>
  );
}

function OwnerInformation({ owner }) {
  const d = owner.details || {};
  return (
    <Section title="Owner information">
      <Stack direction="row" spacing={1} sx={{ mb: 1.5 }}>
        <ReviewChip status={owner.reviewStatus} />
        <AccountChip status={owner.accountStatus} />
      </Stack>
      <Fields rows={[
        ['Name', owner.fullName],
        ['Email', owner.email],
        ['Background', d.isStudent == null ? null : d.isStudent ? `Student · ${d.university || ''}` : 'Independent developer'],
        ['LinkedIn', owner.linkedinUrl],
        ['GitHub', d.githubUrl],
        ['Portfolio', d.portfolioUrl],
      ]} />
      <Button component={Link} to={`/users/${owner.id}`} size="small" sx={{ mt: 1 }}>Open owner's account</Button>
    </Section>
  );
}

function ListingDetails({ listing: l, confidential: c, evidence, owner }) {
  const images = [l.coverUrl, ...(l.photos || []).map(p => p.url)].filter(Boolean);
  const ownership = (evidence || []).filter(e => e.kind === 'ownership_proof');
  const project = (evidence || []).filter(e => e.kind === 'project_evidence');
  return (
    <Stack spacing={2}>
      <OwnerInformation owner={owner} />
      <Section title={`Ownership evidence (${ownership.length})`}>
        <EvidenceList items={ownership} empty="No ownership evidence." />
      </Section>
      <Section title={`Project evidence (${project.length})`}>
        <EvidenceList items={project} empty="No project evidence." />
      </Section>
      <Section title="Claims requiring review" sx={{ bgcolor: '#FFFBEB' }}>
        <Typography variant="body2" color="text.secondary" sx={{ mb: 1.5 }}>
          Check each statement against the evidence above before approving.
        </Typography>
        <Fields rows={listingClaims(l, c)} />
      </Section>
      {images.length > 0 && (
        <Box sx={{ display: 'flex', gap: 1, overflowX: 'auto' }}>
          {images.map(src => (
            <Box key={src} component="a" href={src} target="_blank" rel="noreferrer">
              <Box component="img" src={src} alt="" sx={{ height: 140, borderRadius: 2, display: 'block' }} />
            </Box>
          ))}
        </Box>
      )}
      <Section title="Public preview (everyone sees this)">
        <Fields rows={[
          ['Title', l.title],
          ['Type', LISTING_TYPES[l.listingType]],
          ['Category', l.category.name],
          ['Stage', STAGES[l.projectStage]],
          [l.listingType === 'funding' ? 'Funding needed' : 'Asking price', pkr(l.askingAmount)],
          ['Short description', l.shortDescription],
          ['Tech stack', l.techStack.join(', ')],
          ['Published', dateTime(l.publishedAt)],
        ]} />
      </Section>
      {c && (
        <Section title="Confidential details (owner and admins only)" sx={{ bgcolor: '#F5F3FF' }}>
          <Fields rows={[
            ['Full description', c.fullDescription],
            ['Problem statement', c.problemStatement],
            ['Business model', c.businessModel],
          ]} />
        </Section>
      )}
    </Stack>
  );
}

export default function ListingReviewsPage() {
  const [queue, setQueue] = useState('pending');
  const [selectedId, setSelectedId] = useState(null);
  const [reviewing, setReviewing] = useState(false);
  const [done, setDone] = useState(null);
  const [data, error, reload] = useLoad(() => api(`/admin/reviews/listings?status=${queue}`), [queue]);

  const items = data?.listings ?? [];
  const selected = items.find(i => i.listing.id === selectedId) ?? null;

  const startReview = async () => {
    if (selected.listing.reviewStatus === 'pending') {
      await api(`/admin/listings/${selected.listing.id}/review/start`, { method: 'POST' });
    }
    setReviewing(true);
  };

  const decide = async body => {
    await api(`/admin/listings/${selected.listing.id}/review`, { method: 'POST', body });
    setReviewing(false);
    setSelectedId(null);
    setDone(`"${selected.listing.title}" ${DONE_TEXT[body.decision]} — the owner has been emailed.`);
    reload();
  };

  // a started review stays open in the "Under Review" tab
  const closeDialog = () => {
    setReviewing(false);
    if (queue === 'pending') setQueue('under_review');
    else reload();
  };

  return (
    <>
      <PageHeader title="Project verification" subtitle="Check the owner, the evidence and every claim before a listing goes live" />
      <Tabs value={queue} onChange={(_, v) => { setQueue(v); setSelectedId(null); }} variant="scrollable" sx={{ mb: 2 }}>
        {QUEUES.map(value => <Tab key={value} value={value} label={LISTING_REVIEW_LABELS[value]} />)}
      </Tabs>
      {done && <Alert severity="success" onClose={() => setDone(null)} sx={{ mb: 2 }}>{done}</Alert>}
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '320px 1fr' }, gap: 3, alignItems: 'start' }}>
          <Stack spacing={1}>
            {items.length === 0 && <Typography color="text.secondary">Nothing here.</Typography>}
            {items.map(({ listing: l, evidence, reviewStartedBy }) => (
              <Card key={l.id} sx={{ borderColor: l.id === selectedId ? 'primary.main' : undefined }}>
                <CardActionArea onClick={() => setSelectedId(l.id)}>
                  <CardContent>
                    <Typography fontWeight={600}>{l.title}</Typography>
                    <Typography variant="body2" color="text.secondary">{l.owner.fullName} · {pkr(l.askingAmount)}</Typography>
                    <Stack direction="row" spacing={1} sx={{ mt: 1, flexWrap: 'wrap' }}>
                      <Chip size="small" label={LISTING_TYPES[l.listingType]} color="primary" variant="outlined" />
                      <Chip size="small" variant="outlined" label={`Evidence: ${evidence?.length ?? 0}`} />
                    </Stack>
                    {reviewStartedBy && (
                      <Typography variant="caption" color="text.secondary">Being reviewed by {reviewStartedBy}</Typography>
                    )}
                  </CardContent>
                </CardActionArea>
              </Card>
            ))}
          </Stack>
          {selected ? (
            <Stack spacing={2}>
              <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
                <ReviewChip status={selected.listing.reviewStatus} labels={LISTING_REVIEW_LABELS} />
                {DECIDABLE.includes(queue) && (
                  <Button variant="contained" onClick={startReview}>
                    {selected.listing.reviewStatus === 'pending' ? 'Start review' : 'Continue review'}
                  </Button>
                )}
              </Stack>
              {selected.listing.reviewNote && <Alert severity="info">Last note to the owner: {selected.listing.reviewNote}</Alert>}
              <ListingDetails {...selected} />
              <Section title="Review history">
                <DecisionHistory decisions={selected.decisions} labels={LISTING_DECISION_LABELS} />
              </Section>
            </Stack>
          ) : (
            <Typography color="text.secondary">Select a listing to see the owner, evidence and claims.</Typography>
          )}
        </Box>
      )}
      {reviewing && selected && (
        <ReviewDialog
          open
          title={`Review "${selected.listing.title}"`}
          checklist={LISTING_CHECKLIST}
          decisions={DECISIONS}
          evidence={selected.evidence}
          onClose={closeDialog}
          onSubmit={decide}
        />
      )}
    </>
  );
}
