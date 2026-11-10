// Verification audit trail: every decision with who reviewed it, when, the decision, the reason
// and the evidence that was reviewed. Decisions can never be edited or deleted.

import { Card, Tab, Table, TableBody, TableCell, TableHead, TableRow, Tabs, Typography } from '@mui/material';
import { useState } from 'react';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { Loading, PageHeader, useLoad } from '../components/common';
import { evidenceSummary } from '../components/Verification';
import { DECISION_LABELS, LISTING_DECISION_LABELS, ROLE_LABELS, dateTime } from '../labels';

function Subject({ subject: s }) {
  if (s.type === 'listing') return <>Project: {s.title || '(deleted)'}</>;
  return (
    <>
      <Link to={`/users/${s.id}`}>{s.name || s.email}</Link>
      <Typography variant="caption" color="text.secondary" component="div">{ROLE_LABELS[s.role]}</Typography>
    </>
  );
}

export default function VerificationHistoryPage() {
  const [subject, setSubject] = useState('all');
  const [data, error, reload] = useLoad(() => api(`/admin/reviews/decisions?subject=${subject}`), [subject]);

  return (
    <>
      <PageHeader title="Verification history" subtitle="Who reviewed what, when, the decision, the reason and the evidence reviewed" />
      <Tabs value={subject} onChange={(_, v) => setSubject(v)} sx={{ mb: 2 }}>
        <Tab value="all" label="All" />
        <Tab value="users" label="Accounts" />
        <Tab value="listings" label="Projects" />
      </Tabs>
      {!data ? <Loading error={error} onRetry={reload} /> : (
        <Card>
          <Table size="small">
            <TableHead>
              <TableRow>
                <TableCell>When</TableCell>
                <TableCell>Reviewed</TableCell>
                <TableCell>Decision</TableCell>
                <TableCell>Reason</TableCell>
                <TableCell>Evidence reviewed</TableCell>
                <TableCell>Reviewer</TableCell>
              </TableRow>
            </TableHead>
            <TableBody>
              {data.decisions.length === 0 && (
                <TableRow><TableCell colSpan={6}><Typography color="text.secondary">No decisions yet.</Typography></TableCell></TableRow>
              )}
              {data.decisions.map(d => (
                <TableRow key={d.at + d.subject.id + d.decision}>
                  <TableCell sx={{ whiteSpace: 'nowrap' }}>{dateTime(d.at)}</TableCell>
                  <TableCell><Subject subject={d.subject} /></TableCell>
                  <TableCell>{(d.subject.type === 'listing' ? LISTING_DECISION_LABELS : DECISION_LABELS)[d.decision] || d.decision}</TableCell>
                  <TableCell>{d.reason}</TableCell>
                  <TableCell>{evidenceSummary(d.evidenceReviewed)}</TableCell>
                  <TableCell>{d.reviewer || d.reviewerEmail || '—'}</TableCell>
                </TableRow>
              ))}
            </TableBody>
          </Table>
        </Card>
      )}
    </>
  );
}
