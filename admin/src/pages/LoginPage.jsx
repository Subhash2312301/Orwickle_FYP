import { Alert, Box, Button, Card, CardContent, Stack, TextField, Typography } from '@mui/material';
import { useState } from 'react';
import { useAuth } from '../auth';

export default function LoginPage() {
  const { login, notice } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState(null);
  const [busy, setBusy] = useState(false);

  const submit = async e => {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      await login(email.trim(), password);
    } catch (err) {
      setError(err.message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <Box sx={{ minHeight: '100vh', display: 'grid', placeItems: 'center', p: 2, background: 'linear-gradient(135deg, #111827 0%, #1E1B4B 100%)' }}>
      <Card sx={{ width: '100%', maxWidth: 400 }} variant="elevation" elevation={8}>
        <CardContent sx={{ p: 4 }}>
          <Box component="img" src="/favicon.svg" alt="Orwickle logo" sx={{ width: 56, height: 56, mb: 2 }} />
          <Typography variant="h5">Orwickle <Box component="span" sx={{ color: 'text.secondary', fontWeight: 500 }}>Admin</Box></Typography>
          <Typography color="text.secondary" sx={{ mb: 3 }}>Administrators only · Build · Bid · Grow</Typography>
          <Stack component="form" spacing={2} onSubmit={submit}>
            {notice && <Alert severity="info">{notice}</Alert>}
            {error && <Alert severity="error">{error}</Alert>}
            <TextField label="Email" type="email" value={email} onChange={e => setEmail(e.target.value)} required autoFocus />
            <TextField label="Password" type="password" value={password} onChange={e => setPassword(e.target.value)} required />
            <Button type="submit" variant="contained" size="large" disabled={busy}>{busy ? 'Logging in…' : 'Log in'}</Button>
          </Stack>
        </CardContent>
      </Card>
    </Box>
  );
}
