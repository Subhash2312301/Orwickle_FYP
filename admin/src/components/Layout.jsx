// Sidebar navigation and top bar around every page after login.

import {
  AppBar, Box, Button, Drawer, List, ListItemButton, ListItemIcon, ListItemText, Toolbar, Typography,
} from '@mui/material';
import DashboardIcon from '@mui/icons-material/Dashboard';
import HowToRegIcon from '@mui/icons-material/HowToReg';
import FactCheckIcon from '@mui/icons-material/FactCheck';
import PeopleIcon from '@mui/icons-material/People';
import HistoryIcon from '@mui/icons-material/History';
import KeyIcon from '@mui/icons-material/Key';
import LogoutIcon from '@mui/icons-material/Logout';
import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth';

const WIDTH = 240;

const LINKS = [
  { to: '/', label: 'Overview', icon: <DashboardIcon />, end: true },
  { to: '/reviews/accounts', label: 'Account reviews', icon: <HowToRegIcon /> },
  { to: '/reviews/listings', label: 'Listing reviews', icon: <FactCheckIcon /> },
  { to: '/users', label: 'Users', icon: <PeopleIcon /> },
  { to: '/audit', label: 'Audit log', icon: <HistoryIcon /> },
  { to: '/password', label: 'Change password', icon: <KeyIcon /> },
];

export default function Layout() {
  const { user, logout } = useAuth();
  const confirmLogout = () => {
    if (window.confirm('Are you sure you want to log out?')) logout();
  };

  return (
    <Box sx={{ display: 'flex', minHeight: '100vh' }}>
      <AppBar position="fixed" color="inherit" elevation={0} sx={{ zIndex: t => t.zIndex.drawer + 1, borderBottom: 1, borderColor: 'divider' }}>
        <Toolbar>
          <Box component="img" src="/favicon.svg" alt="" sx={{ width: 34, height: 34, mr: 1.5 }} />
          <Typography variant="h6" sx={{ flexGrow: 1, fontWeight: 800 }}>
            Orwickle <Typography component="span" color="text.secondary">Admin</Typography>
          </Typography>
          <Typography variant="body2" color="text.secondary" sx={{ mr: 2, display: { xs: 'none', sm: 'block' } }}>
            {user.email}
          </Typography>
          <Button startIcon={<LogoutIcon />} onClick={confirmLogout}>Log out</Button>
        </Toolbar>
      </AppBar>
      <Drawer variant="permanent" sx={{ width: WIDTH, flexShrink: 0, '& .MuiDrawer-paper': { width: WIDTH, boxSizing: 'border-box' } }}>
        <Toolbar />
        <List>
          {LINKS.map(link => (
            <ListItemButton
              key={link.to}
              component={NavLink}
              to={link.to}
              end={link.end}
              sx={{ mx: 1, borderRadius: 2, '&.active': { bgcolor: 'primary.main', color: '#fff', '& .MuiListItemIcon-root': { color: '#fff' } } }}
            >
              <ListItemIcon>{link.icon}</ListItemIcon>
              <ListItemText primary={link.label} />
            </ListItemButton>
          ))}
        </List>
      </Drawer>
      <Box component="main" sx={{ flexGrow: 1, p: 3, minWidth: 0 }}>
        <Toolbar />
        <Outlet />
      </Box>
    </Box>
  );
}
