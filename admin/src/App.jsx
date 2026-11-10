import { Navigate, Route, Routes } from 'react-router-dom';
import { useAuth } from './auth';
import Layout from './components/Layout';
import AccountReviewsPage from './pages/AccountReviewsPage';
import AuditPage from './pages/AuditPage';
import ChangePasswordPage from './pages/ChangePasswordPage';
import ListingReviewsPage from './pages/ListingReviewsPage';
import LoginPage from './pages/LoginPage';
import OverviewPage from './pages/OverviewPage';
import UserDetailPage from './pages/UserDetailPage';
import UsersPage from './pages/UsersPage';
import VerificationHistoryPage from './pages/VerificationHistoryPage';

export default function App() {
  const { user } = useAuth();
  if (!user) return <LoginPage />;
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<OverviewPage />} />
        <Route path="reviews/investors" element={<AccountReviewsPage key="investor" role="investor" />} />
        <Route path="reviews/accounts" element={<AccountReviewsPage key="others" role="others" />} />
        <Route path="reviews/listings" element={<ListingReviewsPage />} />
        <Route path="reviews/history" element={<VerificationHistoryPage />} />
        <Route path="users" element={<UsersPage />} />
        <Route path="users/:id" element={<UserDetailPage />} />
        <Route path="audit" element={<AuditPage />} />
        <Route path="password" element={<ChangePasswordPage />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
