// All non-admin accounts with search and filters. Filters live in the URL so the overview cards
// can link straight to e.g. /users?role=investor.

import {
  Card, Chip, MenuItem, Stack, Table, TableBody, TableCell, TableHead, TableRow, TextField, Typography,
} from '@mui/material';
import { useEffect, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { api } from '../api';
import { AccountChip, Loading, PageHeader, ReviewChip, SampleChip, useLoad } from '../components/common';
import { REVIEW_LABELS, ROLE_LABELS, dateTime } from '../labels';

const FILTERS = [
  ['role', 'Role', ROLE_LABELS],
  ['review', 'Review status', REVIEW_LABELS],
  ['status', 'Account', { active: 'Active', suspended: 'Suspended' }],
];

export default function UsersPage() {
  const [params, setParams] = useSearchParams();
  const navigate = useNavigate();
  const [search, setSearch] = useState(params.get('search') ?? '');
  const query = params.toString();
  const [data, error, reload] = useLoad(() => api(`/admin/users?${query}`), [query]);

  // search as you type, without a request per key press
  useEffect(() => {
    const timer = setTimeout(() => setFilter('search', search.trim()), 400);
    return () => clearTimeout(timer);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [search]);

  function setFilter(key, value) {
    setParams(p => {
      const next = new URLSearchParams(p);
      if (value) next.set(key, value);
      else next.delete(key);
      return next;
    }, { replace: true });
  }

  return (
    <>
      <PageHeader title="Users" subtitle="Search accounts, open one to see everything about it, suspend or reinstate" />
      <Stack direction={{ xs: 'column', md: 'row' }} spacing={2} sx={{ mb: 2 }}>
        <TextField label="Search name or email" value={search} onChange={e => setSearch(e.target.value)} sx={{ minWidth: 260 }} />
        {FILTERS.map(([key, label, options]) => (
          <TextField key={key} select label={label} value={params.get(key) ?? ''} onChange={e => setFilter(key, e.target.value)} sx={{ minWidth: 180 }}>
            <MenuItem value="">All</MenuItem>
            {Object.entries(options).map(([value, text]) => <MenuItem key={value} value={value}>{text}</MenuItem>)}
          </TextField>
        ))}
      </Stack>
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Card>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>Name</TableCell>
                <TableCell>Role</TableCell>
                <TableCell>Review</TableCell>
                <TableCell>Email</TableCell>
                <TableCell>Registered</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.users.length === 0 && (
                <TableRow><TableCell colSpan={5}><Typography color="text.secondary">No users match.</Typography></TableCell></TableRow>
              )}
              {data.users.map(u => (
                <TableRow key={u.id} hover sx={{ cursor: 'pointer' }} onClick={() => navigate(`/users/${u.id}`)}>
                  <TableCell>
                    <Stack direction="row" spacing={1} alignItems="center">
                      <span>{u.fullName}</span>
                      <AccountChip status={u.status} />
                      {u.locked && <Chip size="small" label="Locked" color="warning" variant="outlined" />}
                      <SampleChip show={u.isSample} />
                    </Stack>
                  </TableCell>
                  <TableCell>{ROLE_LABELS[u.role]}</TableCell>
                  <TableCell><ReviewChip status={u.reviewStatus} /></TableCell>
                  <TableCell>
                    {u.email}
                    {!u.emailVerified && <Typography variant="caption" color="warning.main" display="block">email not verified</Typography>}
                  </TableCell>
                  <TableCell>{dateTime(u.registeredAt)}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}
      <Typography variant="caption" color="text.secondary" sx={{ display: 'block', mt: 1 }}>Showing the newest 200 matches.</Typography>
    </>
  );
}
