// Verification queue for accounts: role="investor" is the investor verification queue,
// role="others" the owners and buyers. Pick one, check identity, details and evidence, then decide.
// Starting a review moves a pending account to "Under Review".

import { Alert, Box, Button, Card, CardActionArea, CardContent, Chip, Stack, Tab, Tabs, Typography } from '@mui/material';
import { useState } from 'react';
import { api } from '../api';
import { Loading, PageHeader, ReviewChip, useLoad } from '../components/common';
import ProfileDetails from '../components/ProfileDetails';
import ReviewDialog from '../components/ReviewDialog';
import { DecisionHistory } from '../components/Verification';
import { REVIEW_LABELS, ROLE_LABELS, accountChecklist, dateTime } from '../labels';

const QUEUES = ['pending', 'under_review', 'needs_evidence', 'expired', 'rejected', 'approved'];
const DECIDABLE = ['pending', 'under_review'];

const DECISIONS = [
  { value: 'approve', label: 'Approve' },
  { value: 'request_more', label: 'Request more evidence' },
  { value: 'reject', label: 'Reject' },
];

const PAGES = {
  investor: {
    title: 'Investor verification',
    subtitle: 'Check identity, professional information and supporting evidence. A verified investor shows "Profile Verified", not a guarantee.',
  },
  others: {
    title: 'Owner & buyer verification',
    subtitle: 'Check each profile and its documents before the user can publish or buy',
  },
};

export default function AccountReviewsPage({ role = 'others' }) {
  const [queue, setQueue] = useState('pending');
  const [selectedId, setSelectedId] = useState(null);
  const [reviewing, setReviewing] = useState(false);
  const [done, setDone] = useState(null);
  const [data, error, reload] = useLoad(() => api(`/admin/reviews/users?status=${queue}&role=${role}`), [queue, role]);

  const users = data?.users ?? [];
  const selected = users.find(u => u.id === selectedId) ?? null;
  const page = PAGES[role] ?? PAGES.others;

  const startReview = async () => {
    if (selected.reviewStatus === 'pending') await api(`/admin/users/${selected.id}/review/start`, { method: 'POST' });
    setReviewing(true);
  };

  const decide = async body => {
    await api(`/admin/users/${selected.id}/review`, { method: 'POST', body });
    setReviewing(false);
    setSelectedId(null);
    setDone(`${selected.fullName}: ${DECISIONS.find(d => d.value === body.decision).label.toLowerCase()} — the user has been emailed.`);
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
      <PageHeader title={page.title} subtitle={page.subtitle} />
      <Tabs value={queue} onChange={(_, v) => { setQueue(v); setSelectedId(null); }} variant="scrollable" sx={{ mb: 2 }}>
        {QUEUES.map(value => <Tab key={value} value={value} label={REVIEW_LABELS[value]} />)}
      </Tabs>
      {done && <Alert severity="success" onClose={() => setDone(null)} sx={{ mb: 2 }}>{done}</Alert>}
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '320px 1fr' }, gap: 3, alignItems: 'start' }}>
          <Stack spacing={1}>
            {users.length === 0 && <Typography color="text.secondary">Nothing here.</Typography>}
            {users.map(u => (
              <Card key={u.id} sx={{ borderColor: u.id === selectedId ? 'primary.main' : undefined }}>
                <CardActionArea onClick={() => setSelectedId(u.id)}>
                  <CardContent>
                    <Typography fontWeight={600}>{u.fullName}</Typography>
                    {u.role === 'investor' && u.details?.organization && (
                      <Typography variant="body2">{u.details.organization}</Typography>
                    )}
                    <Typography variant="body2" color="text.secondary">{u.email}</Typography>
                    <Stack direction="row" spacing={1} sx={{ mt: 1, flexWrap: 'wrap' }}>
                      <Chip size="small" label={ROLE_LABELS[u.role]} />
                      {u.role === 'investor' && <Chip size="small" variant="outlined" label={`Evidence: ${u.documents.length}`} />}
                    </Stack>
                    <Typography variant="caption" color="text.secondary" component="div">Registered {dateTime(u.registeredAt)}</Typography>
                    {u.reviewStartedBy && (
                      <Typography variant="caption" color="text.secondary">Being reviewed by {u.reviewStartedBy}</Typography>
                    )}
                  </CardContent>
                </CardActionArea>
              </Card>
            ))}
          </Stack>
          {selected ? (
            <Stack spacing={2}>
              <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
                <ReviewChip status={selected.reviewStatus} />
                {DECIDABLE.includes(queue) && (
                  <Button variant="contained" onClick={startReview}>
                    {selected.reviewStatus === 'pending' ? 'Start review' : 'Continue review'}
                  </Button>
                )}
              </Stack>
              {selected.reviewNote && <Alert severity="info">Last note to the user: {selected.reviewNote}</Alert>}
              <ProfileDetails profile={selected} user={selected} />
              <Card>
                <CardContent>
                  <Typography variant="subtitle1" fontWeight={600} gutterBottom>Review history</Typography>
                  <DecisionHistory decisions={selected.decisions} />
                </CardContent>
              </Card>
            </Stack>
          ) : (
            <Typography color="text.secondary">Select an account to see its details and evidence.</Typography>
          )}
        </Box>
      )}
      {reviewing && selected && (
        <ReviewDialog
          open
          title={`Review ${selected.fullName} (${ROLE_LABELS[selected.role]})`}
          checklist={accountChecklist(selected)}
          decisions={DECISIONS}
          evidence={selected.documents}
          onClose={closeDialog}
          onSubmit={decide}
        />
      )}
    </>
  );
}
