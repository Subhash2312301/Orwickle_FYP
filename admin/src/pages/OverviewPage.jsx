import { Box, Button, Card, CardContent, Stack, Typography } from '@mui/material';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { Loading, PageHeader, useLoad } from '../components/common';

function Stat({ label, value, color = 'text.primary', to }) {
  const content = (
    <CardContent>
      <Typography variant="body2" color="text.secondary">{label}</Typography>
      <Typography variant="h4" fontWeight={700} color={color}>{value}</Typography>
    </CardContent>
  );
  return (
    <Card sx={to ? { '&:hover': { borderColor: 'primary.main' } } : undefined}>
      {to ? <Box component={Link} to={to} sx={{ textDecoration: 'none', color: 'inherit' }}>{content}</Box> : content}
    </Card>
  );
}

const grid = { display: 'grid', gridTemplateColumns: 'repeat(auto-fill, minmax(180px, 1fr))', gap: 2, mb: 4 };

export default function OverviewPage() {
  const [stats, error, reload] = useLoad(() => api('/admin/stats'), []);
  if (!stats) return <Loading error={error} onRetry={reload} />;
  const { users: u, listings: l } = stats;

  return (
    <>
      <PageHeader title="Overview" subtitle="Accounts and listings at a glance" action={<Button onClick={reload}>Refresh</Button>} />

      <Typography variant="h6" gutterBottom>Needs your attention</Typography>
      <Box sx={grid}>
        <Stat label="Accounts waiting for review" value={u.pending} color="warning.main" to="/reviews/accounts" />
        <Stat label="Listings waiting for review" value={l.pending} color="warning.main" to="/reviews/listings" />
        <Stat label="Locked (wrong passwords)" value={u.locked} color="error.main" />
        <Stat label="Suspended accounts" value={u.suspended} color="error.main" to="/users?status=suspended" />
      </Box>

      <Typography variant="h6" gutterBottom>Users</Typography>
      <Box sx={grid}>
        <Stat label="Project owners" value={u.owners} to="/users?role=owner" />
        <Stat label="Investors" value={u.investors} to="/users?role=investor" />
        <Stat label="Buyers" value={u.buyers} to="/users?role=buyer" />
        <Stat label="Approved" value={u.approved} color="success.main" />
        <Stat label="Not approved yet" value={u.notApproved} />
        <Stat label="Email not verified" value={u.unverifiedEmail} />
        <Stat label="Registered today" value={u.newToday} color="primary.main" />
      </Box>

      <Typography variant="h6" gutterBottom>Listings</Typography>
      <Box sx={grid}>
        <Stat label="Live" value={l.live} color="success.main" />
        <Stat label="Drafts" value={l.drafts} />
        <Stat label="Closed" value={l.closed} />
        <Stat label="Seeking funding" value={l.funding} />
        <Stat label="For sale" value={l.sale} />
      </Box>

      {u.samples > 0 && (
        <Stack direction="row" spacing={1}>
          <Typography variant="body2" color="text.secondary">
            Includes {u.samples} sample (demo) accounts, shown with a "Sample" badge.
          </Typography>
        </Stack>
      )}
    </>
  );
}
