// Decision dialog for an account or listing review. Approving needs every checklist item ticked;
// any other decision needs a reason, which is emailed to the user. The ticked checklist is stored
// with the decision.

import {
  Alert, Button, Checkbox, Dialog, DialogActions, DialogContent, DialogTitle, FormControlLabel,
  FormGroup, Stack, TextField, ToggleButton, ToggleButtonGroup, Typography,
} from '@mui/material';
import { useState } from 'react';

export default function ReviewDialog({ open, title, checklist, decisions, onClose, onSubmit }) {
  const [decision, setDecision] = useState('approve');
  const [checked, setChecked] = useState({});
  const [reason, setReason] = useState('');
  const [error, setError] = useState(null);
  const [saving, setSaving] = useState(false);

  const allChecked = checklist.every(item => checked[item]);
  const approving = decision === 'approve';
  const canSubmit = approving ? allChecked : reason.trim().length > 0;

  const submit = async () => {
    setSaving(true);
    setError(null);
    try {
      await onSubmit({
        decision,
        reason: reason.trim() || undefined,
        checklist: Object.fromEntries(checklist.map(item => [item, Boolean(checked[item])])),
      });
    } catch (err) {
      setError(err.details?.reason || err.message);
    } finally {
      setSaving(false);
    }
  };

  return (
    <Dialog open={open} onClose={saving ? undefined : onClose} fullWidth maxWidth="sm">
      <DialogTitle>{title}</DialogTitle>
      <DialogContent>
        <Stack spacing={2} sx={{ pt: 1 }}>
          <Typography variant="subtitle2">Checklist</Typography>
          <FormGroup>
            {checklist.map(item => (
              <FormControlLabel
                key={item}
                control={<Checkbox checked={Boolean(checked[item])} onChange={e => setChecked(c => ({ ...c, [item]: e.target.checked }))} />}
                label={item}
              />
            ))}
          </FormGroup>
          <Typography variant="subtitle2">Decision</Typography>
          <ToggleButtonGroup exclusive value={decision} onChange={(_, v) => v && setDecision(v)} size="small" color="primary">
            {decisions.map(d => <ToggleButton key={d.value} value={d.value}>{d.label}</ToggleButton>)}
          </ToggleButtonGroup>
          <TextField
            label={approving ? 'Note (optional)' : 'Reason (sent to the user)'}
            multiline
            minRows={3}
            value={reason}
            onChange={e => setReason(e.target.value)}
            required={!approving}
            helperText={approving ? '' : 'Tell the user exactly what to change, e.g. "Upload a clearer photo of the CNIC back".'}
          />
          {approving && !allChecked && <Alert severity="info">Tick every checklist item to approve.</Alert>}
          {error && <Alert severity="error">{error}</Alert>}
        </Stack>
      </DialogContent>
      <DialogActions>
        <Button onClick={onClose} disabled={saving}>Cancel</Button>
        <Button variant="contained" color={approving ? 'success' : 'error'} onClick={submit} disabled={!canSubmit || saving}>
          {saving ? 'Saving…' : decisions.find(d => d.value === decision)?.label}
        </Button>
      </DialogActions>
    </Dialog>
  );
}
