import { createTheme } from '@mui/material/styles';

// Colours from the Orwickle brand sheet (light theme).
export const theme = createTheme({
  palette: {
    primary: { main: '#6366F1' },
    secondary: { main: '#8B5CF6' },
    info: { main: '#06B6D4' },
    warning: { main: '#F59E0B' },
    background: { default: '#F3F4F6', paper: '#FFFFFF' },
    text: { primary: '#111827' },
  },
  shape: { borderRadius: 10 },
  typography: {
    fontFamily: '"Inter", "Segoe UI", Roboto, Arial, sans-serif',
    h5: { fontWeight: 700 },
    h6: { fontWeight: 600 },
  },
  components: {
    MuiButton: { defaultProps: { disableElevation: true }, styleOverrides: { root: { textTransform: 'none', fontWeight: 600 } } },
    MuiCard: { defaultProps: { variant: 'outlined' } },
  },
});
