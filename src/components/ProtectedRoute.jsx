import { Navigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';

export function ProtectedRoute({ children, requiredRole = null }) {
  const { session, isAdmin, loading } = useAuthStore();

  if (loading) {
    return <div className="flex items-center justify-center h-screen bg-black text-white">Loading...</div>;
  }

  if (!session) {
    return <Navigate to="/login" replace />;
  }

  if (requiredRole === 'admin' && !isAdmin) {
    return <Navigate to="/user" replace />;
  }

  if (requiredRole === 'user' && isAdmin) {
    return <Navigate to="/admin" replace />;
  }

  return children;
}
