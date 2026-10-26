// One account: profile and documents, listings, review history, and suspend / reinstate.

import {
  Alert, Button, Card, CardContent, Chip, Dialog, DialogActions, DialogContent, DialogTitle, Stack,
  Table, TableBody, TableCell, TableHead, TableRow, TextField, Typography,
} from '@mui/material';
import ArrowBackIcon from '@mui/icons-material/ArrowBack';
import { useState } from 'react';
import { Link, useParams } from 'react-router-dom';
import { api } from '../api';
import { AccountChip, Loading, PageHeader, ReviewChip, useLoad } from '../components/common';
import ProfileDetails from '../components/ProfileDetails';
import { DECISION_LABELS, LISTING_TYPES, dateTime, pkr } from '../labels';

function StatusDialog({ user, onClose, onDone }) {
  const suspend = user.status !== 'suspended';
  const [reason, setReason] = useState('');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  const submit = async () => {
    setSaving(true);
    setError(null);
    try {
      await api(`/admin/users/${user.id}/${suspend ? 'suspend' : 'reinstate'}`, { method: 'POST', body: { reason: reason.trim() } });
      onDone(suspend ? 'Account suspended. The user is logged out and has been emailed.' : 'Account reinstated. The user can log in again.');
    } catch (err) {
      setError(err.details?.reason || err.message);
      setSaving(false);
    }
  };

  return (
    <Dialog open onClose={saving ? undefined : onClose} fullWidth maxWidth="sm">
      <DialogTitle>{suspend ? 'Suspend this account?' : 'Reinstate this account?'}</DialogTitle>
      <DialogContent>
        <Typography sx={{ mb: 2 }} color="text.secondary">
          {suspend
            ? 'The user is logged out on every device within about 2 minutes and cannot log in until you reinstate the account.'
            : 'The user will be able to log in again.'}
        </Typography>
        <TextField label="Reason (emailed to the user and kept in the history)" multiline minRows={3} fullWidth value={reason} onChange={e => setReason(e.target.value)} />
        {error && <Alert severity="error" sx={{ mt: 2 }}>{error}</Alert>}
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>Cancel</Button>
        <Button variant="contained" color={suspend ? 'error' : 'success'} onClick={submit} disabled={saving || reason.trim().length < 3}>
          {suspend ? 'Suspend' : 'Reinstate'}
        </Button>
      </DialogActions>
    </Dialog>
  );
}

export default function UserDetailPage() {
  const { id } = useParams();
  const [data, error, reload] = useLoad(() => api(`/admin/users/${id}`), [id]);
  const [changing, setChanging] = useState(false);
  const [done, setDone] = useState(null);

  if (!data) return <Loading error={error} onRetry={reload} />;
  const { user, profile, listings, decisions } = data;

  return (
    <>
      <Button component={Link} to="/users" startIcon={<ArrowBackIcon />} sx={{ mb: 1 }}>All users</Button>
      <PageHeader
        title={profile.fullName}
        subtitle={`Registered ${dateTime(user.registeredAt)}${user.emailVerified ? '' : ' · email not verified'}`}
        action={
          <Button variant="outlined" color={user.status === 'suspended' ? 'success' : 'error'} onClick={() => setChanging(true)}>
            {user.status === 'suspended' ? 'Reinstate account' : 'Suspend account'}
          </Button>
        }
      />
      <Stack direction="row" spacing={1} sx={{ mb: 2 }}>
        <ReviewChip status={profile.reviewStatus} />
        <AccountChip status={user.status} />
        {user.locked && <Chip size="small" label="Locked after wrong passwords" color="warning" variant="outlined" />}
      </Stack>
      {done && <Alert severity="success" onClose={() => setDone(null)} sx={{ mb: 2 }}>{done}</Alert>}
      {profile.reviewNote && <Alert severity="info" sx={{ mb: 2 }}>Note sent to the user: {profile.reviewNote}</Alert>}

      <Stack spacing={2}>
        <ProfileDetails profile={profile} email={user.email} />

        {user.role === 'owner' && (
          <Card>
            <CardContent>
              <Typography variant="subtitle1" fontWeight={600} gutterBottom>Listings</Typography>
              {listings.length === 0 ? <Typography color="text.secondary">No listings yet.</Typography> : (
                <Table size="small">
                  <TableHead><TableRow><TableCell>Title</TableCell><TableCell>Type</TableCell><TableCell>Amount</TableCell><TableCell>Status</TableCell></TableRow></TableHead>
                  <TableBody>
                    {listings.map(l => (
                      <TableRow key={l.id}>
                        <TableCell>{l.title}</TableCell>
                        <TableCell>{LISTING_TYPES[l.listingType]}</TableCell>
                        <TableCell>{pkr(l.askingAmount)}</TableCell>
                        <TableCell>{l.status}{l.status === 'published' && ` · ${l.reviewStatus}`}</TableCell>
                      </TableRow>
                    ))}
                  </TableBody>
                </Table>
              )}
            </CardContent>
          </Card>
        )}

        <Card>
          <CardContent>
            <Typography variant="subtitle1" fontWeight={600} gutterBottom>Review history</Typography>
            {decisions.length === 0 ? <Typography color="text.secondary">No decisions yet.</Typography> : (
              <Table size="small">
                <TableHead><TableRow><TableCell>When</TableCell><TableCell>Decision</TableCell><TableCell>Reason</TableCell><TableCell>By</TableCell></TableRow></TableHead>
                <TableBody>
                  {decisions.map(d => (
                    <TableRow key={d.at + d.decision}>
                      <TableCell>{dateTime(d.at)}</TableCell>
                      <TableCell>{DECISION_LABELS[d.decision] || d.decision}</TableCell>
                      <TableCell>{d.reason}</TableCell>
                      <TableCell>{d.reviewer || '—'}</TableCell>
                    </TableRow>
                  ))}
                </TableBody>
              </Table>
            )}
          </CardContent>
        </Card>
      </Stack>

      {changing && (
        <StatusDialog
          user={user}
          onClose={() => setChanging(false)}
          onDone={message => { setChanging(false); setDone(message); reload(); }}
        />
      )}
    </>
  );
}
