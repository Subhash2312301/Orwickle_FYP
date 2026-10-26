// Queue of accounts waiting for approval. Pick one, check the profile and documents, decide.

import { Alert, Box, Button, Card, CardActionArea, CardContent, Chip, Stack, Tab, Tabs, Typography } from '@mui/material';
import { useState } from 'react';
import { api } from '../api';
import { Loading, PageHeader, ReviewChip, SampleChip, useLoad } from '../components/common';
import ProfileDetails from '../components/ProfileDetails';
import ReviewDialog from '../components/ReviewDialog';
import { ROLE_LABELS, accountChecklist, dateTime } from '../labels';

const QUEUES = [
  ['pending', 'Waiting'],
  ['needs_evidence', 'More info requested'],
  ['rejected', 'Rejected'],
  ['approved', 'Approved'],
];

const DECISIONS = [
  { value: 'approve', label: 'Approve' },
  { value: 'request_more', label: 'Ask for more information' },
  { value: 'reject', label: 'Reject' },
];

export default function AccountReviewsPage() {
  const [queue, setQueue] = useState('pending');
  const [selectedId, setSelectedId] = useState(null);
  const [reviewing, setReviewing] = useState(false);
  const [done, setDone] = useState(null);
  const [data, error, reload] = useLoad(() => api(`/admin/reviews/users?status=${queue}`), [queue]);

  const users = data?.users ?? [];
  const selected = users.find(u => u.id === selectedId) ?? null;

  const decide = async body => {
    await api(`/admin/users/${selected.id}/review`, { method: 'POST', body });
    setReviewing(false);
    setSelectedId(null);
    setDone(`${selected.fullName}: ${DECISIONS.find(d => d.value === body.decision).label.toLowerCase()} — the user has been emailed.`);
    reload();
  };

  return (
    <>
      <PageHeader title="Account reviews" subtitle="Check each profile and its documents before the user can publish, bid or buy" />
      <Tabs value={queue} onChange={(_, v) => { setQueue(v); setSelectedId(null); }} sx={{ mb: 2 }}>
        {QUEUES.map(([value, label]) => <Tab key={value} value={value} label={label} />)}
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
                    <Typography variant="body2" color="text.secondary">{u.email}</Typography>
                    <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                      <Chip size="small" label={ROLE_LABELS[u.role]} />
                      <SampleChip show={u.isSample} />
                    </Stack>
                    <Typography variant="caption" color="text.secondary">Registered {dateTime(u.registeredAt)}</Typography>
                  </CardContent>
                </CardActionArea>
              </Card>
            ))}
          </Stack>
          {selected ? (
            <Stack spacing={2}>
              <Stack direction="row" spacing={2} alignItems="center" justifyContent="space-between">
                <ReviewChip status={selected.reviewStatus} />
                {queue !== 'approved' && (
                  <Button variant="contained" onClick={() => setReviewing(true)}>Review this account</Button>
                )}
              </Stack>
              {selected.reviewNote && <Alert severity="info">Last note to the user: {selected.reviewNote}</Alert>}
              <ProfileDetails profile={selected} />
            </Stack>
          ) : (
            <Typography color="text.secondary">Select an account to see its profile and documents.</Typography>
          )}
        </Box>
      )}
      {reviewing && selected && (
        <ReviewDialog
          open
          title={`Review ${selected.fullName} (${ROLE_LABELS[selected.role]})`}
          checklist={accountChecklist(selected)}
          decisions={DECISIONS}
          onClose={() => setReviewing(false)}
          onSubmit={decide}
        />
      )}
    </>
  );
}
