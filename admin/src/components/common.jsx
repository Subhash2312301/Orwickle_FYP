// Small shared pieces: page header, loading/error states, status chips, label/value rows.

import { Alert, Box, Button, Chip, CircularProgress, Stack, Typography } from '@mui/material';
import { useCallback, useEffect, useState } from 'react';
import { REVIEW_COLORS, REVIEW_LABELS } from '../labels';

export function PageHeader({ title, subtitle, action }) {
  return (
    <Stack direction="row" alignItems="flex-start" justifyContent="space-between" spacing={2} sx={{ mb: 3 }}>
      <Box>
        <Typography variant="h5">{title}</Typography>
        {subtitle && <Typography color="text.secondary">{subtitle}</Typography>}
      </Box>
      {action}
    </Stack>
  );
}

/** Loads data with `load()`; returns [data, error, reload]. */
export function useLoad(load, deps) {
  const [state, setState] = useState({ data: null, error: null });
  // eslint-disable-next-line react-hooks/exhaustive-deps
  const run = useCallback(load, deps);
  const reload = useCallback(() => {
    run()
      .then(data => setState({ data, error: null }))
      .catch(error => setState(s => ({ data: s.data, error })));
  }, [run]);
  useEffect(reload, [reload]);
  return [state.data, state.error, reload];
}

export function Loading({ error, onRetry }) {
  if (error) {
    return (
      <Alert severity="error" action={onRetry && <Button onClick={onRetry}>Try again</Button>}>
        {error.message}
      </Alert>
    );
  }
  return (
    <Box sx={{ display: 'flex', justifyContent: 'center', p: 6 }}>
      <CircularProgress />
    </Box>
  );
}

export const ReviewChip = ({ status }) => (
  <Chip size="small" label={REVIEW_LABELS[status] || status} color={REVIEW_COLORS[status] || 'default'} />
);

export const AccountChip = ({ status }) =>
  status === 'suspended' ? <Chip size="small" label="Suspended" color="error" variant="outlined" /> : null;

export const SampleChip = ({ show }) => (show ? <Chip size="small" label="Sample" variant="outlined" /> : null);

/** Label / value pairs; empty values are shown as a dash, links are clickable. */
export function Fields({ rows }) {
  return (
    <Box sx={{ display: 'grid', gridTemplateColumns: { xs: '1fr', sm: '200px 1fr' }, rowGap: 1, columnGap: 2 }}>
      {rows.filter(Boolean).map(([label, value]) => (
        <Box key={label} sx={{ display: 'contents' }}>
          <Typography color="text.secondary" variant="body2">{label}</Typography>
          <Typography variant="body2" sx={{ wordBreak: 'break-word', whiteSpace: 'pre-wrap' }}>
            {typeof value === 'string' && /^https?:\/\//.test(value)
              ? <a href={value} target="_blank" rel="noreferrer">{value}</a>
              : (value ?? '—') || '—'}
          </Typography>
        </Box>
      ))}
    </Box>
  );
}
