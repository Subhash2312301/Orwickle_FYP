import { Box, Button, Card, CardContent, Typography } from '@mui/material';
import { Link } from 'react-router-dom';
import { api } from '../api';
import { Loading, PageHeader, useLoad } from '../components/common';

function Stat({ label, value, color = 'text.primary', to }) {
  const content = (
    <CardContent>
      <Typography variant="body2" color="text.secondary">{label}</Typography>
      <Typography variant="h4" color={color}>{value}</Typography>
    </CardContent>
  );
  return (
    <Card sx={to ? { transition: 'border-color .15s, box-shadow .15s', '&:hover': { borderColor: 'primary.main', boxShadow: '0 4px 14px rgba(79,70,229,.12)' } } : undefined}>
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
        <Stat label="Investors waiting for verification" value={u.investorsPending} color="warning.main" to="/reviews/investors" />
        <Stat label="Projects waiting for verification" value={l.pending} color="warning.main" to="/reviews/listings" />
        <Stat label="Owners & buyers waiting" value={u.pending - u.investorsPending} color="warning.main" to="/reviews/accounts" />
        <Stat label="Locked (wrong passwords)" value={u.locked} color="error.main" />
      </Box>

      <Typography variant="h6" gutterBottom>Account verification status</Typography>
      <Box sx={grid}>
        <Stat label="Pending" value={u.pending} color="warning.main" to="/users?review=pending" />
        <Stat label="Under Review" value={u.underReview} color="info.main" to="/users?review=under_review" />
        <Stat label="More evidence requested" value={u.needsEvidence} to="/users?review=needs_evidence" />
        <Stat label="Verified" value={u.approved} color="success.main" to="/users?review=approved" />
        <Stat label="Rejected" value={u.rejected} color="error.main" to="/users?review=rejected" />
        <Stat label="Suspended" value={u.suspended} color="error.main" to="/users?status=suspended" />
        <Stat label="Expired" value={u.expired} to="/users?review=expired" />
      </Box>

      <Typography variant="h6" gutterBottom>Users</Typography>
      <Box sx={grid}>
        <Stat label="Project owners" value={u.owners} to="/users?role=owner" />
        <Stat label="Investors" value={u.investors} to="/users?role=investor" />
        <Stat label="Buyers" value={u.buyers} to="/users?role=buyer" />
        <Stat label="Email not verified" value={u.unverifiedEmail} />
        <Stat label="Registered today" value={u.newToday} color="primary.main" />
      </Box>

      <Typography variant="h6" gutterBottom>Listings</Typography>
      <Box sx={grid}>
        <Stat label="Live" value={l.live} color="success.main" />
        <Stat label="Under Review" value={l.underReview} color="info.main" to="/reviews/listings" />
        <Stat label="Changes requested" value={l.needsChanges} />
        <Stat label="Drafts" value={l.drafts} />
        <Stat label="Closed" value={l.closed} />
        <Stat label="Seeking funding" value={l.funding} />
        <Stat label="For sale" value={l.sale} />
      </Box>
    </>
  );
}
