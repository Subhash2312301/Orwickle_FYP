// Read-only audit log: who did what and when. The table is append-only in the database.

import { Button, Card, MenuItem, Stack, Table, TableBody, TableCell, TableHead, TableRow, TextField, Typography } from '@mui/material';
import { useState } from 'react';
import { api } from '../api';
import { Loading, PageHeader, useLoad } from '../components/common';
import { dateTime } from '../labels';

const GROUPS = {
  '': 'Everything',
  'admin.': 'Admin decisions',
  'auth.': 'Logins and security',
  'profile.': 'Profile changes',
  'listing.': 'Listing changes',
};

export default function AuditPage() {
  const [group, setGroup] = useState('admin.');
  const [data, error, reload] = useLoad(() => api(`/admin/audit?limit=100${group ? `&action=${group}` : ''}`), [group]);

  return (
    <>
      <PageHeader title="Audit log" subtitle="Every important action is recorded and cannot be edited or deleted" action={<Button onClick={reload}>Refresh</Button>} />
      <TextField select label="Show" value={group} onChange={e => setGroup(e.target.value)} sx={{ mb: 2, minWidth: 220 }}>
        {Object.entries(GROUPS).map(([value, label]) => <MenuItem key={value} value={value}>{label}</MenuItem>)}
      </TextField>
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Card>
          <Table size="small">
            <TableHead>
              <TableRow><TableCell>When</TableCell><TableCell>Action</TableCell><TableCell>By</TableCell><TableCell>Details</TableCell></TableRow>
            </TableHead>
            <TableBody>
              {data.entries.length === 0 && (
                <TableRow><TableCell colSpan={4}><Typography color="text.secondary">No entries.</Typography></TableCell></TableRow>
              )}
              {data.entries.map(e => (
                <TableRow key={e.id}>
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>{dateTime(e.at)}</TableCell>
                  <TableCell><code>{e.action}</code></TableCell>
                  <TableCell>{e.actor ? `${e.actor.email} (${e.actor.role})` : 'system'}</TableCell>
                  <TableCell>
                    <Stack spacing={0.5}>
                      {e.details?.reason && <span>Reason: {e.details.reason}</span>}
                      <Typography variant="caption" color="text.secondary">{e.entityType} {e.entityId?.slice(0, 8)}{e.ip ? ` · ${e.ip}` : ''}</Typography>
                    </Stack>
                  </TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}
    </>
  );
}
