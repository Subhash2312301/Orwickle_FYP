import { createTheme } from '@mui/material/styles';

// Colours from the Orwickle brand sheet (light theme), the same as the mobile app's AppTheme:
// primary is the deeper indigo so white text on buttons stays readable (6.3:1), and the
// status colours are dark enough to be read as text (approved green, pending amber, rejected red).
export const theme = createTheme({
  palette: {
    primary: { main: '#4F46E5', light: '#6366F1' },
    secondary: { main: '#8B5CF6' },
    info: { main: '#0E7490' },
    success: { main: '#15803D' },
    warning: { main: '#B45309' },
    error: { main: '#B91C1C' },
    background: { default: '#F3F4F6', paper: '#FFFFFF' },
    text: { primary: '#111827', secondary: '#6B7280' },
  },
  shape: { borderRadius: 12 },
  typography: {
    fontFamily: '"Inter", "Segoe UI", Roboto, Arial, sans-serif',
    h4: { fontWeight: 800 },
    h5: { fontWeight: 800 },
    h6: { fontWeight: 700 },
  },
  components: {
    MuiButton: { defaultProps: { disableElevation: true }, styleOverrides: { root: { textTransform: 'none', fontWeight: 600 } } },
    MuiCard: { defaultProps: { variant: 'outlined' }, styleOverrides: { root: { borderRadius: 16 } } },
    MuiChip: { styleOverrides: { root: { fontWeight: 600 } } },
  },
});
