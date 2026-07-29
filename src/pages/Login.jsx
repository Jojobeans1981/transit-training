import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';
import { config } from '../config';

export default function Login() {
  const navigate = useNavigate();
  const { session, isAdmin } = useAuthStore();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [isSignUp, setIsSignUp] = useState(false);
  const [fullName, setFullName] = useState('');
  const [signUpAsAdmin, setSignUpAsAdmin] = useState(false);
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    if (session) {
      navigate(isAdmin ? '/admin' : '/user');
    }
  }, [session, isAdmin, navigate]);

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      const authStore = useAuthStore.getState();
      let result;

      if (isSignUp) {
        if (signUpAsAdmin) {
          result = await authStore.adminSignUp(email, password);
        } else {
          if (!fullName.trim()) {
            throw new Error('Full name required');
          }
          result = await authStore.userSignUp(email, password, fullName);
        }
      } else {
        result = await authStore.signIn(email, password);
      }

      if (!result.success) {
        throw new Error(result.error);
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-black flex items-center justify-center p-4">
      <div className="w-full max-w-md border border-gray-800 bg-gray-900 p-8 rounded-none">
        <h1 className="text-3xl font-bold text-white mb-2">{config.appName}</h1>
        <p className="text-gray-400 mb-8">{config.appDescription}</p>

        <form onSubmit={handleSubmit} className="space-y-4">
          {error && (
            <div className="p-3 bg-red-900 border border-red-700 text-red-200 text-sm rounded-none">
              {error}
            </div>
          )}

          {isSignUp && !signUpAsAdmin && (
            <input
              type="text"
              placeholder="Full name"
              value={fullName}
              onChange={(e) => setFullName(e.target.value)}
              className="w-full px-4 py-3 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500"
              required
            />
          )}

          <input
            type="email"
            placeholder="Email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            className="w-full px-4 py-3 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500"
            required
          />

          <input
            type="password"
            placeholder="Password (min 8 chars)"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            className="w-full px-4 py-3 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500"
            required
            minLength={8}
          />

          {isSignUp && (
            <label className="flex items-center space-x-2 text-gray-300 text-sm">
              <input
                type="checkbox"
                checked={signUpAsAdmin}
                onChange={(e) => setSignUpAsAdmin(e.target.checked)}
                className="w-4 h-4 bg-gray-800 border border-gray-700 rounded-none cursor-pointer"
              />
              <span>Sign up as admin</span>
            </label>
          )}

          <button
            type="submit"
            disabled={loading}
            className="w-full py-3 bg-blue-600 text-white font-semibold rounded-none hover:bg-blue-700 disabled:opacity-50 transition"
          >
            {loading ? 'Loading...' : isSignUp ? 'Sign Up' : 'Sign In'}
          </button>
        </form>

        <button
          onClick={() => { setIsSignUp(!isSignUp); setError(''); setFullName(''); setSignUpAsAdmin(false); }}
          className="w-full mt-4 text-gray-400 hover:text-gray-200 text-sm transition"
        >
          {isSignUp ? 'Already have an account? Sign in' : "Don't have an account? Sign up"}
        </button>
      </div>
    </div>
  );
}
