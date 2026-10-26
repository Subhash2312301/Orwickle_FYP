import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth';
import Layout from './components/Layout';
import AccountReviewsPage from './pages/AccountReviewsPage';
import AuditPage from './pages/AuditPage';
import ListingReviewsPage from './pages/ListingReviewsPage';
import LoginPage from './pages/LoginPage';
import OverviewPage from './pages/OverviewPage';
import UserDetailPage from './pages/UserDetailPage';
import UsersPage from './pages/UsersPage';

export default function App() {
  const { user } = useAuth();
  if (!user) return <LoginPage />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<OverviewPage />} />
        <Route path="reviews/accounts" element={<AccountReviewsPage />} />
        <Route path="reviews/listings" element={<ListingReviewsPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:id" element={<UserDetailPage />} />
        <Route path="audit" element={<AuditPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
