// The backend applies the same password rules as the app (length, upper/lower case, number,
// special character, not a common word, not the user's name or email, not the current password).

import { Alert, Button, Card, CardContent, Stack, TextField } from '@mui/material';
import { useState } from 'react';
import { changePassword } from '../api';
import { PageHeader } from '../components/common';

export default function ChangePasswordPage() {
  const [form, setForm] = useState({ current: '', next: '', confirm: '' });
  const [errors, setErrors] = useState({});
  const [message, setMessage] = useState(null);
  const [saving, setSaving] = useState(false);

  const set = key => e => setForm(f => ({ ...f, [key]: e.target.value }));

  const submit = async e => {
    e.preventDefault();
    setMessage(null);
    if (form.next !== form.confirm) {
      setErrors({ confirm: 'Passwords do not match' });
      return;
    }
    setSaving(true);
    setErrors({});
    try {
      await changePassword(form.current, form.next);
      setForm({ current: '', next: '', confirm: '' });
      setMessage('Password changed. Other devices have been logged out.');
    } catch (err) {
      setErrors({ current: err.details?.currentPassword, next: err.details?.newPassword, general: err.details?.currentPassword || err.details?.newPassword ? null : err.message });
    } finally {
      setSaving(false);
    }
  };

  return (
    <>
      <PageHeader title="Change password" subtitle="At least 8 characters with upper and lower case letters, a number and a special character" />
      <Card sx={{ maxWidth: 480 }}>
        <CardContent>
          <Stack component="form" spacing={2} onSubmit={submit}>
            {message && <Alert severity="success">{message}</Alert>}
            {errors.general && <Alert severity="error">{errors.general}</Alert>}
            <TextField type="password" label="Current password" value={form.current} onChange={set('current')} error={Boolean(errors.current)} helperText={errors.current} required />
            <TextField type="password" label="New password" value={form.next} onChange={set('next')} error={Boolean(errors.next)} helperText={errors.next} required />
            <TextField type="password" label="Confirm new password" value={form.confirm} onChange={set('confirm')} error={Boolean(errors.confirm)} helperText={errors.confirm} required />
            <Button type="submit" variant="contained" disabled={saving}>{saving ? 'Saving…' : 'Change password'}</Button>
          </Stack>
        </CardContent>
      </Card>
    </>
  );
}
