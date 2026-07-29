import { useEffect } from 'react';
import { useAuthStore } from '../stores/authStore';
import { config } from '../config';

export default function UserDashboard() {
  const { user, signOut } = useAuthStore();

  useEffect(() => {
    if (user) {}
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
            <h1 className="text-3xl font-bold">{config.appName}</h1>
            <p className="text-gray-400">Welcome, {user.full_name || user.email}</p>
          </div>
          <button onClick={handleLogout} className="px-4 py-2 bg-gray-800 border border-gray-700 hover:bg-gray-700 rounded-none transition">Logout</button>
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
