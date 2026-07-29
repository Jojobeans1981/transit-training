#!/bin/bash
# FutureEng Complete Auto-Setup
# Run: bash complete-setup.sh

set -e

echo "🚀 FutureEng Complete Setup"
echo "Creating all 19 files..."

# Create directories
mkdir -p src/{stores,components,pages,lib}
mkdir -p api

# 1. src/stores/authStore.js
cat > src/stores/authStore.js << 'ENDFILE'
import { create } from 'zustand';
import { supabase, auth, db } from '../lib/supabase';

export const useAuthStore = create((set) => ({
  session: null,
  user: null,
  isAdmin: false,
  loading: true,

  initAuth: async () => {
    try {
      const session = await auth.getSession();
      if (session) {
        const adminData = await db.getAdmin(session.user.id);
        if (adminData?.data) {
          set({ session, user: adminData.data, isAdmin: true, loading: false });
        } else {
          const userData = await db.getUser(session.user.id);
          set({ session, user: userData?.data || { user_id: session.user.id, email: session.user.email }, isAdmin: false, loading: false });
        }
      } else {
        set({ session: null, user: null, isAdmin: false, loading: false });
      }
    } catch (error) {
      console.error('Auth init error:', error);
      set({ loading: false });
    }
  },

  adminSignUp: async (email, password) => {
    try {
      set({ loading: true });
      const { data, error } = await auth.signUp(email, password);
      if (error) throw error;
      await db.createAdmin(data.user.id, email);
      set({ session: data.session, user: { id: data.user.id, email, user_id: data.user.id }, isAdmin: true, loading: false });
      return { success: true };
    } catch (error) {
      console.error('Admin signup error:', error);
      set({ loading: false });
      return { success: false, error: error.message };
    }
  },

  userSignUp: async (email, password, fullName) => {
    try {
      set({ loading: true });
      const { data, error } = await auth.signUp(email, password);
      if (error) throw error;
      await db.createUser(data.user.id, email, fullName, null);
      set({ session: data.session, user: { user_id: data.user.id, email, full_name: fullName }, isAdmin: false, loading: false });
      return { success: true };
    } catch (error) {
      console.error('User signup error:', error);
      set({ loading: false });
      return { success: false, error: error.message };
    }
  },

  signIn: async (email, password) => {
    try {
      set({ loading: true });
      const { data, error } = await auth.signIn(email, password);
      if (error) throw error;
      const adminData = await db.getAdmin(data.user.id);
      if (adminData?.data) {
        set({ session: data.session, user: adminData.data, isAdmin: true, loading: false });
      } else {
        const userData = await db.getUser(data.user.id);
        set({ session: data.session, user: userData?.data, isAdmin: false, loading: false });
      }
      return { success: true };
    } catch (error) {
      console.error('Sign in error:', error);
      set({ loading: false });
      return { success: false, error: error.message };
    }
  },

  signOut: async () => {
    try {
      await auth.signOut();
      set({ session: null, user: null, isAdmin: false });
      return { success: true };
    } catch (error) {
      return { success: false, error: error.message };
    }
  },

  updateProfile: async (updates) => {
    try {
      set({ loading: true });
      const state = useAuthStore.getState();
      if (state.isAdmin) {
        await supabase.from('admins').update(updates).eq('user_id', state.session.user.id);
      } else {
        await supabase.from('users').update(updates).eq('user_id', state.session.user.id);
      }
      set({ user: { ...state.user, ...updates }, loading: false });
      return { success: true };
    } catch (error) {
      set({ loading: false });
      return { success: false, error: error.message };
    }
  },
}));

supabase.auth.onAuthStateChange((event, session) => {
  if (event === 'SIGNED_IN') {
    useAuthStore.getState().initAuth();
  } else if (event === 'SIGNED_OUT') {
    useAuthStore.setState({ session: null, user: null, isAdmin: false });
  }
});
ENDFILE

echo "✅ authStore.js"

# 2. src/components/ProtectedRoute.jsx
cat > src/components/ProtectedRoute.jsx << 'ENDFILE'
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
ENDFILE

echo "✅ ProtectedRoute.jsx"

# 3. src/App.jsx
cat > src/App.jsx << 'ENDFILE'
import { useEffect } from 'react';
import { BrowserRouter as Router, Routes, Route, Navigate } from 'react-router-dom';
import { useAuthStore } from './stores/authStore';
import { ProtectedRoute } from './components/ProtectedRoute';
import Login from './pages/Login';
import AdminDashboard from './pages/AdminDashboard';
import UserDashboard from './pages/UserDashboard';
import './index.css';

export default function App() {
  const { loading } = useAuthStore();

  useEffect(() => {
    useAuthStore.getState().initAuth();
  }, []);

  if (loading) {
    return <div className="flex items-center justify-center h-screen bg-black text-white">Loading...</div>;
  }

  return (
    <Router>
      <Routes>
        <Route path="/login" element={<Login />} />
        <Route path="/admin/*" element={<ProtectedRoute requiredRole="admin"><AdminDashboard /></ProtectedRoute>} />
        <Route path="/user/*" element={<ProtectedRoute requiredRole="user"><UserDashboard /></ProtectedRoute>} />
        <Route path="*" element={<Navigate to="/login" replace />} />
      </Routes>
    </Router>
  );
}
ENDFILE

echo "✅ App.jsx"

# 4. src/pages/Login.jsx
cat > src/pages/Login.jsx << 'ENDFILE'
import { useState, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuthStore } from '../stores/authStore';

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
        <h1 className="text-3xl font-bold text-white mb-2">FutureEng</h1>
        <p className="text-gray-400 mb-8">Training Platform</p>

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
ENDFILE

echo "✅ Login.jsx"

# 5. src/pages/AdminDashboard.jsx
cat > src/pages/AdminDashboard.jsx << 'ENDFILE'
import { useState, useEffect } from 'react';
import { useAuthStore } from '../stores/authStore';
import { db, supabase } from '../lib/supabase';
import { generateQuiz } from '../lib/claude';

export default function AdminDashboard() {
  const { user, signOut } = useAuthStore();
  const [industries, setIndustries] = useState([]);
  const [selectedIndustry, setSelectedIndustry] = useState(null);
  const [newIndustryName, setNewIndustryName] = useState('');
  const [systemPrompt, setSystemPrompt] = useState('');
  const [trainingFile, setTrainingFile] = useState(null);
  const [materials, setMaterials] = useState([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState('');

  useEffect(() => {
    if (user?.id) {
      loadIndustries();
    }
  }, [user]);

  useEffect(() => {
    if (selectedIndustry) {
      loadMaterials();
    }
  }, [selectedIndustry]);

  const loadIndustries = async () => {
    try {
      const { data, error: err } = await db.getIndustries(user.id);
      if (err) throw err;
      setIndustries(data || []);
    } catch (err) {
      setError(`Failed to load industries: ${err.message}`);
    }
  };

  const loadMaterials = async () => {
    try {
      const { data, error: err } = await db.getTrainingMaterials(selectedIndustry.id);
      if (err) throw err;
      setMaterials(data || []);
    } catch (err) {
      setError(`Failed to load materials: ${err.message}`);
    }
  };

  const handleCreateIndustry = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (!newIndustryName?.trim() || !systemPrompt?.trim()) {
      setError('Please fill in all fields');
      return;
    }

    setLoading(true);
    try {
      const { error: err } = await db.createIndustry(user.id, newIndustryName, systemPrompt);
      if (err) throw err;

      setSuccess('Industry created successfully');
      setNewIndustryName('');
      setSystemPrompt('');
      await loadIndustries();
    } catch (err) {
      setError(`Error creating industry: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleUploadMaterial = async (e) => {
    e.preventDefault();
    setError('');
    setSuccess('');

    if (!trainingFile || !selectedIndustry) {
      setError('Please select a file and industry');
      return;
    }

    setLoading(true);
    try {
      setSuccess('Uploading file...');

      const fileName = `${Date.now()}-${trainingFile.name}`;
      const { data: uploadData, error: uploadError } = await supabase.storage
        .from('training-materials')
        .upload(`${selectedIndustry.id}/${fileName}`, trainingFile);

      if (uploadError) throw uploadError;

      const fileContent = await trainingFile.text();

      const { data: materialData, error: dbError } = await db.uploadTrainingMaterial(
        selectedIndustry.id,
        user.id,
        trainingFile.name,
        uploadData.path,
        trainingFile.size
      );

      if (dbError) throw dbError;

      setSuccess('Generating quiz from training material...');
      const quizData = await generateQuiz(fileContent, selectedIndustry.system_prompt, selectedIndustry.name);

      const { error: quizError } = await db.createGeneratedMaterial(
        materialData.data[0].id,
        'quiz',
        quizData
      );

      if (quizError) throw quizError;

      setSuccess('Material uploaded and quiz generated successfully!');
      setTrainingFile(null);
      await loadMaterials();
    } catch (err) {
      setError(`Upload failed: ${err.message}`);
    } finally {
      setLoading(false);
    }
  };

  const handleLogout = async () => {
    await signOut();
  };

  return (
    <div className="min-h-screen bg-black text-white">
      <div className="border-b border-gray-800 p-6">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold">FutureEng Admin</h1>
            <p className="text-gray-400 text-sm">{user?.email}</p>
          </div>
          <button onClick={handleLogout} className="px-4 py-2 bg-gray-800 border border-gray-700 hover:bg-gray-700 rounded-none transition">
            Logout
          </button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6 p-6">
        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Industries</h2>

          <form onSubmit={handleCreateIndustry} className="space-y-3 mb-6 pb-6 border-b border-gray-800">
            <input
              type="text"
              placeholder="Industry name"
              value={newIndustryName}
              onChange={(e) => setNewIndustryName(e.target.value)}
              className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500 text-sm"
            />
            <textarea
              placeholder="System prompt"
              value={systemPrompt}
              onChange={(e) => setSystemPrompt(e.target.value)}
              className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500 text-sm h-24"
            />
            <button
              type="submit"
              disabled={loading}
              className="w-full py-2 bg-blue-600 hover:bg-blue-700 rounded-none transition disabled:opacity-50 text-sm font-semibold"
            >
              {loading ? 'Creating...' : 'Create Industry'}
            </button>
          </form>

          <div className="space-y-2">
            {industries.length === 0 ? (
              <p className="text-gray-400 text-sm">No industries yet</p>
            ) : (
              industries.map((industry) => (
                <button
                  key={industry.id}
                  onClick={() => setSelectedIndustry(industry)}
                  className={`w-full text-left px-3 py-2 border rounded-none transition text-sm ${
                    selectedIndustry?.id === industry.id
                      ? 'bg-blue-600 border-blue-500'
                      : 'bg-gray-800 border-gray-700 hover:bg-gray-700'
                  }`}
                >
                  {industry.name}
                </button>
              ))
            )}
          </div>
        </div>

        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Upload Materials</h2>

          {selectedIndustry ? (
            <form onSubmit={handleUploadMaterial} className="space-y-3">
              <div className="text-sm text-gray-400 mb-3">
                Selected: <span className="text-blue-400 font-semibold">{selectedIndustry.name}</span>
              </div>
              <input
                type="file"
                onChange={(e) => setTrainingFile(e.target.files?.[0] || null)}
                accept=".txt,.pdf,.md"
                className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white rounded-none text-sm"
              />
              <button
                type="submit"
                disabled={loading || !trainingFile}
                className="w-full py-2 bg-green-600 hover:bg-green-700 rounded-none transition disabled:opacity-50 text-sm font-semibold"
              >
                {loading ? 'Processing...' : 'Upload & Generate'}
              </button>
            </form>
          ) : (
            <p className="text-gray-400 text-sm">Select an industry first</p>
          )}

          <div className="mt-6">
            <h3 className="font-semibold mb-3 text-sm">Recent Materials</h3>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {materials.length === 0 ? (
                <p className="text-gray-400 text-xs">No materials uploaded</p>
              ) : (
                materials.map((material) => (
                  <div key={material.id} className="p-2 bg-gray-800 border border-gray-700 rounded-none text-sm">
                    <p className="font-mono text-xs text-gray-300 truncate">{material.file_name}</p>
                    <p className="text-xs text-gray-500 mt-1">{new Date(material.uploaded_at).toLocaleDateString()}</p>
                  </div>
                ))
              )}
            </div>
          </div>
        </div>

        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Status</h2>
          <div className="space-y-3 text-sm">
            {error && (
              <div className="p-3 bg-red-900 border border-red-700 text-red-200 rounded-none text-xs">
                {error}
              </div>
            )}
            {success && (
              <div className="p-3 bg-green-900 border border-green-700 text-green-200 rounded-none text-xs">
                {success}
              </div>
            )}
            <div className="p-3 bg-gray-800 border border-gray-700 text-gray-300 rounded-none">
              <p className="font-semibold text-blue-400">{user?.email}</p>
              <p className="text-xs text-gray-500 mt-1">✓ Admin account</p>
            </div>
            <div className="text-xs text-gray-500 space-y-1 pt-2 border-t border-gray-700">
              <p>Industries: {industries.length}</p>
              <p>Materials: {materials.length}</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
ENDFILE

echo "✅ AdminDashboard.jsx"

# 6. src/pages/UserDashboard.jsx
cat > src/pages/UserDashboard.jsx << 'ENDFILE'
import { useEffect } from 'react';
import { useAuthStore } from '../stores/authStore';

export default function UserDashboard() {
  const { user, signOut } = useAuthStore();

  useEffect(() => {
    if (user) {
      // Load user-specific data here
    }
  }, [user]);

  const handleLogout = async () => {
    await signOut();
  };

  if (!user) {
    return <div className="min-h-screen bg-black text-white flex items-center justify-center">Loading...</div>;
  }

  return (
    <div className="min-h-screen bg-black text-white">
      <div className="border-b border-gray-800 p-6">
        <div className="flex justify-between items-center">
          <div>
            <h1 className="text-3xl font-bold">FutureEng</h1>
            <p className="text-gray-400">Welcome, {user.full_name || user.email}</p>
          </div>
          <button onClick={handleLogout} className="px-4 py-2 bg-gray-800 border border-gray-700 hover:bg-gray-700 rounded-none transition">
            Logout
          </button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6 p-6">
        <div className="col-span-2 border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-2xl font-bold mb-6">Dashboard</h2>
          
          <div className="grid grid-cols-2 gap-4 mb-8">
            <div className="p-4 border border-gray-700 bg-gray-800 rounded-none">
              <p className="text-gray-400 text-sm mb-2">Quizzes Completed</p>
              <p className="text-3xl font-bold text-blue-400">0</p>
            </div>
            <div className="p-4 border border-gray-700 bg-gray-800 rounded-none">
              <p className="text-gray-400 text-sm mb-2">Average Score</p>
              <p className="text-3xl font-bold text-green-400">--</p>
            </div>
          </div>

          <div className="space-y-3">
            <h3 className="text-lg font-semibold mb-3">Get Started</h3>
            <div className="p-4 border border-gray-700 bg-gray-800 rounded-none hover:bg-gray-750 cursor-pointer transition">
              <p className="font-semibold">Quiz Practice</p>
              <p className="text-sm text-gray-400">Take quizzes and test your knowledge</p>
            </div>
            <div className="p-4 border border-gray-700 bg-gray-800 rounded-none hover:bg-gray-750 cursor-pointer transition">
              <p className="font-semibold">Study Manual</p>
              <p className="text-sm text-gray-400">Read comprehensive study materials</p>
            </div>
            <div className="p-4 border border-gray-700 bg-gray-800 rounded-none hover:bg-gray-750 cursor-pointer transition">
              <p className="font-semibold">AI Tutor</p>
              <p className="text-sm text-gray-400">Chat with AI for personalized help</p>
            </div>
          </div>
        </div>

        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Leaderboard</h2>
          <div className="space-y-2 text-sm text-gray-400">
            <p>No scores yet. Complete quizzes to see rankings!</p>
            <div className="mt-4 p-3 bg-gray-800 border border-gray-700 rounded-none text-center">
              <p className="text-lg font-bold text-yellow-400 mb-1">--</p>
              <p className="text-xs">Your Rank</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
ENDFILE

echo "✅ UserDashboard.jsx"

# 7. src/index.css
cat > src/index.css << 'ENDFILE'
@tailwind base;
@tailwind components;
@tailwind utilities;

* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

body {
  background-color: #000000;
  color: #ffffff;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', 'Roboto', 'Oxygen',
    'Ubuntu', 'Cantarell', 'Fira Sans', 'Droid Sans', 'Helvetica Neue',
    sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
}

input:focus,
textarea:focus,
select:focus,
button:focus {
  outline: none;
}

button {
  cursor: pointer;
  border-radius: 0 !important;
  transition: all 0.2s ease;
}

input,
textarea,
select {
  border-radius: 0 !important;
}
ENDFILE

echo "✅ index.css"

# 8. src/main.jsx
cat > src/main.jsx << 'ENDFILE'
import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App.jsx'

ReactDOM.createRoot(document.getElementById('root')).render(
  <React.StrictMode>
    <App />
  </React.StrictMode>,
)
ENDFILE

echo "✅ main.jsx"

# 9. index.html
cat > index.html << 'ENDFILE'
<!doctype html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <link rel="icon" type="image/svg+xml" href="/vite.svg" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>FutureEng - Training Platform</title>
  </head>
  <body>
    <div id="root"></div>
    <script type="module" src="/src/main.jsx"></script>
  </body>
</html>
ENDFILE

echo "✅ index.html"

# 10. vite.config.js
cat > vite.config.js << 'ENDFILE'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    host: true,
  },
})
ENDFILE

echo "✅ vite.config.js"

# 11. tailwind.config.js
cat > tailwind.config.js << 'ENDFILE'
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,jsx}",
  ],
  theme: {
    extend: {
      borderRadius: {
        'none': '0px',
      },
    },
  },
  plugins: [],
}
ENDFILE

echo "✅ tailwind.config.js"

# 12. postcss.config.js
cat > postcss.config.js << 'ENDFILE'
export default {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
ENDFILE

echo "✅ postcss.config.js"

# 13. vercel.json
cat > vercel.json << 'ENDFILE'
{
  "functions": {
    "api/**/*.js": {
      "runtime": "nodejs20.x"
    }
  },
  "buildCommand": "npm run build",
  "outputDirectory": "dist",
  "env": {
    "CLAUDE_API_KEY": "@claude_api_key"
  }
}
ENDFILE

echo "✅ vercel.json"

# 14. .env.example
cat > .env.example << 'ENDFILE'
VITE_SUPABASE_URL=https://your-project.supabase.co
VITE_SUPABASE_ANON_KEY=your-anon-key-here
CLAUDE_API_KEY=sk-ant-...
VITE_APP_NAME=FutureEng
ENDFILE

echo "✅ .env.example"

# 15. .gitignore
cat > .gitignore << 'ENDFILE'
node_modules/
.pnp
.pnp.js
dist/
build/
.env
.env.local
.env.*.local
coverage/
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store
Thumbs.db
npm-debug.log*
yarn-debug.log*
yarn-error.log*
lerna-debug.log*
ENDFILE

echo "✅ .gitignore"

# 16. api/generate-material.js
cat > api/generate-material.js << 'ENDFILE'
import Anthropic from '@anthropic-ai/sdk';

const client = new Anthropic({
  apiKey: process.env.CLAUDE_API_KEY,
});

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    return res.status(405).json({ error: 'Method not allowed' });
  }

  const { trainingContent, systemPrompt, industryName, type } = req.body;

  if (!trainingContent || !systemPrompt || !industryName || !type) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  if (!['quiz', 'study_guide', 'scenario'].includes(type)) {
    return res.status(400).json({ error: 'Invalid material type' });
  }

  try {
    let prompt;

    if (type === 'quiz') {
      prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, generate a quiz with 5 multiple-choice questions.
Training Material:
${trainingContent}
Return ONLY a JSON object:
{
  "quiz": [
    {"id": 1, "question": "...", "options": ["A", "B", "C", "D"], "correct_answer": "A", "explanation": "..."}
  ]
}`;
    } else if (type === 'study_guide') {
      prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, create a comprehensive study guide.
Training Material:
${trainingContent}
Return ONLY a JSON object:
{
  "guide": {
    "title": "Study Guide: ${industryName}",
    "sections": [{"heading": "...", "content": "..."}],
    "key_takeaways": ["..."]
  }
}`;
    } else {
      prompt = `You are an expert training material generator for the ${industryName} industry.
System context: ${systemPrompt}
Based on the following training material, create a realistic scenario-based training exercise.
Training Material:
${trainingContent}
Return ONLY a JSON object:
{
  "scenario": {
    "title": "...",
    "description": "...",
    "situation": "...",
    "questions": [{"id": 1, "prompt": "...", "expected_response": "..."}]
  }
}`;
    }

    const message = await client.messages.create({
      model: 'claude-opus-4-1',
      max_tokens: 2048,
      messages: [
        {
          role: 'user',
          content: prompt,
        },
      ],
    });

    const content = message.content[0].text;
    let jsonData;
    
    try {
      jsonData = JSON.parse(content);
    } catch (parseError) {
      const jsonMatch = content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        jsonData = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Could not parse Claude response as JSON');
      }
    }

    return res.status(200).json(jsonData);
  } catch (error) {
    console.error('Claude API error:', error);
    return res.status(500).json({
      error: error.message || 'Failed to generate material',
    });
  }
}
ENDFILE

echo "✅ generate-material.js"

# 17. src/lib/claude.js (copy updated version)
cat > src/lib/claude.js << 'ENDFILE'
const API_BASE = import.meta.env.MODE === 'development' 
  ? 'http://localhost:3000' 
  : '';

export const generateQuiz = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'quiz'
  });
};

export const generateStudyGuide = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'study_guide'
  });
};

export const generateScenario = async (trainingContent, systemPrompt, industryName) => {
  return await callBackend({
    trainingContent,
    systemPrompt,
    industryName,
    type: 'scenario'
  });
};

async function callBackend(payload) {
  try {
    const endpoint = `${API_BASE}/api/generate-material`;
    
    const response = await fetch(endpoint, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(payload)
    });

    if (!response.ok) {
      const errorData = await response.json();
      throw new Error(errorData.error || `Backend error: ${response.statusText}`);
    }

    const data = await response.json();
    return data;
  } catch (error) {
    console.error('Backend error:', error);
    throw error;
  }
}
ENDFILE

echo "✅ claude.js"

# 18. package.json
cat > package.json << 'ENDFILE'
{
  "name": "futureeng",
  "private": true,
  "version": "0.1.0",
  "type": "module",
  "scripts": {
    "dev": "vercel dev",
    "build": "vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "react": "^18.2.0",
    "react-dom": "^18.2.0",
    "@supabase/supabase-js": "^2.38.0",
    "@anthropic-ai/sdk": "^0.20.0",
    "react-router-dom": "^6.18.0",
    "zustand": "^4.4.0",
    "@tanstack/react-query": "^5.28.0",
    "framer-motion": "^10.16.4",
    "react-hook-form": "^7.48.0",
    "@hookform/resolvers": "^3.3.4",
    "zod": "^3.22.4",
    "recharts": "^2.10.2",
    "lucide-react": "^0.292.0",
    "clsx": "^2.0.0",
    "tailwind-merge": "^2.2.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.1.0",
    "vite": "^5.0.0",
    "tailwindcss": "^3.3.0",
    "postcss": "^8.4.31",
    "autoprefixer": "^10.4.16",
    "typescript": "^5.2.2",
    "@types/react": "^18.2.37",
    "@types/react-dom": "^18.2.15",
    "@types/node": "^20.9.0"
  }
}
ENDFILE

echo "✅ package.json"

# 19. Create .env.local (they need to fill this in)
cat > .env.local << 'ENDFILE'
VITE_SUPABASE_URL=YOUR_SUPABASE_URL_HERE
VITE_SUPABASE_ANON_KEY=YOUR_SUPABASE_ANON_KEY_HERE
CLAUDE_API_KEY=YOUR_CLAUDE_API_KEY_HERE
VITE_APP_NAME=FutureEng
ENDFILE

echo "✅ .env.local (FILL IN YOUR KEYS)"

# Install dependencies
echo ""
echo "📦 Installing dependencies..."
npm install

echo ""
echo "============================================"
echo "✅ SETUP COMPLETE!"
echo "============================================"
echo ""
echo "🔧 Next steps:"
echo ""
echo "1. Update .env.local with your actual keys:"
echo "   VITE_SUPABASE_URL=https://xxx.supabase.co"
echo "   VITE_SUPABASE_ANON_KEY=eyJ..."
echo "   CLAUDE_API_KEY=sk-ant-..."
echo ""
echo "2. Run database migration (Supabase SQL Editor):"
echo "   - Paste: futureeng_migrate_v1_to_v2.sql"
echo "   - Run"
echo ""
echo "3. Start dev server:"
echo "   vercel dev"
echo ""
echo "4. Test: http://localhost:3000"
echo ""
echo "📁 Project structure: $(pwd)"
echo ""
ENDFILE

echo "✅ setup script created"

chmod +x setup.sh
