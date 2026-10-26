// Published listings waiting for approval. Admins see the public preview and the confidential
// details; approved listings become visible to investors or buyers.

import {
  Alert, Box, Button, Card, CardActionArea, CardContent, Chip, Stack, Tab, Tabs, Typography,
} from '@mui/material';
import { useState } from 'react';
import { api } from '../api';
import { Fields, Loading, PageHeader, SampleChip, useLoad } from '../components/common';
import ReviewDialog from '../components/ReviewDialog';
import { LISTING_CHECKLIST, LISTING_TYPES, STAGES, dateTime, pkr } from '../labels';

const DECISIONS = [
  { value: 'approve', label: 'Approve' },
  { value: 'reject', label: 'Reject (back to draft)' },
];

function ListingDetails({ listing: l, confidential: c }) {
  const images = [l.coverUrl, ...(l.photos || []).map(p => p.url)].filter(Boolean);
  return (
    <Stack spacing={2}>
      {images.length > 0 && (
        <Box sx={{ display: 'flex', gap: 1, overflowX: 'auto' }}>
          {images.map(src => (
            <Box key={src} component="a" href={src} target="_blank" rel="noreferrer">
              <Box component="img" src={src} alt="" sx={{ height: 140, borderRadius: 2, display: 'block' }} />
            </Box>
          ))}
        </Box>
      )}
      <Card>
        <CardContent>
          <Typography variant="subtitle1" fontWeight={600} gutterBottom>Public preview (everyone sees this)</Typography>
          <Fields rows={[
            ['Title', l.title],
            ['Type', LISTING_TYPES[l.listingType]],
            ['Category', l.category.name],
            ['Stage', STAGES[l.projectStage]],
            [l.listingType === 'funding' ? 'Funding needed' : 'Asking price', pkr(l.askingAmount)],
            ['Short description', l.shortDescription],
            ['Tech stack', l.techStack.join(', ')],
            ['Owner', l.owner.fullName],
            ['Published', dateTime(l.publishedAt)],
          ]} />
        </CardContent>
      </Card>
      {c && (
        <Card sx={{ bgcolor: '#F5F3FF' }}>
          <CardContent>
            <Typography variant="subtitle1" fontWeight={600} gutterBottom>Confidential details (owner and admins only)</Typography>
            <Fields rows={[
              l.listingType === 'funding' && ['Equity offered', c.equityOfferedPercent == null ? null : `${c.equityOfferedPercent}%`],
              ['Full description', c.fullDescription],
              ['Problem statement', c.problemStatement],
              ['Business model', c.businessModel],
              ['Financial summary', c.financialSummary],
              ['Ownership notes', c.ipOwnershipNotes],
              l.listingType === 'sale' && ['What the buyer receives', c.transferDetails],
            ]} />
          </CardContent>
        </Card>
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

  const decide = async body => {
    await api(`/admin/listings/${selected.listing.id}/review`, { method: 'POST', body });
    setReviewing(false);
    setSelectedId(null);
    setDone(`"${selected.listing.title}" ${body.decision === 'approve' ? 'is now live' : 'was sent back to draft'} — the owner has been emailed.`);
    reload();
  };

  return (
    <>
      <PageHeader title="Listing reviews" subtitle="Published listings stay hidden until you approve them" />
      <Tabs value={queue} onChange={(_, v) => { setQueue(v); setSelectedId(null); }} sx={{ mb: 2 }}>
        <Tab value="pending" label="Waiting" />
        <Tab value="approved" label="Live" />
      </Tabs>
      {done && <Alert severity="success" onClose={() => setDone(null)} sx={{ mb: 2 }}>{done}</Alert>}
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', md: '320px 1fr' }, gap: 3, alignItems: 'start' }}>
          <Stack spacing={1}>
            {items.length === 0 && <Typography color="text.secondary">Nothing here.</Typography>}
            {items.map(({ listing: l }) => (
              <Card key={l.id} sx={{ borderColor: l.id === selectedId ? 'primary.main' : undefined }}>
                <CardActionArea onClick={() => setSelectedId(l.id)}>
                  <CardContent>
                    <Typography fontWeight={600}>{l.title}</Typography>
                    <Typography variant="body2" color="text.secondary">{l.owner.fullName} · {pkr(l.askingAmount)}</Typography>
                    <Stack direction="row" spacing={1} sx={{ mt: 1 }}>
                      <Chip size="small" label={LISTING_TYPES[l.listingType]} color="primary" variant="outlined" />
                      <SampleChip show={l.isSample} />
                    </Stack>
                  </CardContent>
                </CardActionArea>
              </Card>
            ))}
          </Stack>
          {selected ? (
            <Stack spacing={2}>
              {queue === 'pending' && (
                <Box sx={{ display: 'flex', justifyContent: 'flex-end' }}>
                  <Button variant="contained" onClick={() => setReviewing(true)}>Review this listing</Button>
                </Box>
              )}
              <ListingDetails {...selected} />
            </Stack>
          ) : (
            <Typography color="text.secondary">Select a listing to see its preview and confidential details.</Typography>
          )}
        </Box>
      )}
      {reviewing && selected && (
        <ReviewDialog
          open
          title={`Review "${selected.listing.title}"`}
          checklist={LISTING_CHECKLIST}
          decisions={DECISIONS}
          onClose={() => setReviewing(false)}
          onSubmit={decide}
        />
      )}
    </>
  );
}
