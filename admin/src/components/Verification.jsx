// Evidence and the review history (audit trail) shown wherever an admin verifies something.

import { Box, Stack, Table, TableBody, TableCell, TableHead, TableRow, Typography } from '@mui/material';
import LinkIcon from '@mui/icons-material/Link';
import PictureAsPdfIcon from '@mui/icons-material/PictureAsPdf';
import { DECISION_LABELS, DOCUMENT_LABELS, dateTime } from '../labels';

/** Files open full size; links open the page the user gave. */
export function EvidenceList({ items, empty = 'No evidence submitted.' }) {
  if (!items?.length) return <Typography color="text.secondary">{empty}</Typography>;
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 2 }}>
      {items.map(doc => (
        <Box
          key={doc.id || doc.kind}
          component="a"
          href={doc.url}
          target="_blank"
          rel="noreferrer"
          sx={{ textDecoration: 'none', color: 'inherit', border: 1, borderColor: 'divider', borderRadius: 2, overflow: 'hidden' }}
        >
          {doc.isLink || doc.contentType === 'application/pdf' ? (
            <Stack alignItems="center" justifyContent="center" sx={{ height: 120, bgcolor: 'grey.100', px: 1 }}>
              {doc.isLink ? <LinkIcon color="primary" fontSize="large" /> : <PictureAsPdfIcon color="error" fontSize="large" />}
              <Typography variant="caption" sx={{ wordBreak: 'break-all', textAlign: 'center' }}>
                {doc.isLink ? doc.url.replace(/^https?:\/\//, '').slice(0, 60) : 'Open PDF'}
              </Typography>
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

/** Evidence the reviewer had in front of them, as stored with the decision. */
export const evidenceSummary = items => (items?.length ? items.map(e => DOCUMENT_LABELS[e.kind] || e.kind).join(', ') : '—');

/** Who reviewed, when, the decision, the reason and the evidence reviewed. */
export function DecisionHistory({ decisions, labels = DECISION_LABELS }) {
  if (!decisions?.length) return <Typography color="text.secondary">No decisions yet.</Typography>;
  return (
    <Table size="small">
      <TableHead>
        <TableRow>
          <TableCell>When</TableCell>
          <TableCell>Decision</TableCell>
          <TableCell>Reason</TableCell>
          <TableCell>Evidence reviewed</TableCell>
          <TableCell>By</TableCell>
        </TableRow>
      </TableHead>
      <TableBody>
        {decisions.map(d => (
          <TableRow key={d.at + d.decision}>
            <TableCell sx={{ whiteSpace: 'nowrap' }}>{dateTime(d.at)}</TableCell>
            <TableCell>{labels[d.decision] || d.decision}</TableCell>
            <TableCell>{d.reason}</TableCell>
            <TableCell>{evidenceSummary(d.evidenceReviewed)}</TableCell>
            <TableCell>{d.reviewer || '—'}</TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
