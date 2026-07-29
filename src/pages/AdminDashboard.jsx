import { useState, useEffect } from 'react';
import { useAuthStore } from '../stores/authStore';
import { db, supabase } from '../lib/supabase';
import { generateQuiz } from '../lib/claude';
import { config } from '../config';

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
    if (user?.id) loadIndustries();
  }, [user]);

  useEffect(() => {
    if (selectedIndustry) loadMaterials();
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
      const { data: uploadData, error: uploadError } = await supabase.storage.from('training-materials').upload(`${selectedIndustry.id}/${fileName}`, trainingFile);
      if (uploadError) throw uploadError;
      const fileContent = await trainingFile.text();
      const { data: materialData, error: dbError } = await db.uploadTrainingMaterial(selectedIndustry.id, user.id, trainingFile.name, uploadData.path, trainingFile.size);
      if (dbError) throw dbError;
      setSuccess('Generating quiz from training material...');
      const quizData = await generateQuiz(fileContent, selectedIndustry.system_prompt, selectedIndustry.name);
      const { error: quizError } = await db.createGeneratedMaterial(materialData[0].id, 'quiz', quizData);
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
            <h1 className="text-3xl font-bold">{config.appName} Admin</h1>
            <p className="text-gray-400 text-sm">{user?.email}</p>
          </div>
          <button onClick={handleLogout} className="px-4 py-2 bg-gray-800 border border-gray-700 hover:bg-gray-700 rounded-none transition">Logout</button>
        </div>
      </div>

      <div className="grid grid-cols-3 gap-6 p-6">
        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Industries</h2>
          <form onSubmit={handleCreateIndustry} className="space-y-3 mb-6 pb-6 border-b border-gray-800">
            <input type="text" placeholder="Industry name" value={newIndustryName} onChange={(e) => setNewIndustryName(e.target.value)} className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500 text-sm" />
            <textarea placeholder="System prompt" value={systemPrompt} onChange={(e) => setSystemPrompt(e.target.value)} className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white placeholder-gray-500 rounded-none focus:outline-none focus:border-blue-500 text-sm h-24" />
            <button type="submit" disabled={loading} className="w-full py-2 bg-blue-600 hover:bg-blue-700 rounded-none transition disabled:opacity-50 text-sm font-semibold">{loading ? 'Creating...' : 'Create Industry'}</button>
          </form>
          <div className="space-y-2">
            {industries.length === 0 ? <p className="text-gray-400 text-sm">No industries yet</p> : industries.map((industry) => (
              <button key={industry.id} onClick={() => setSelectedIndustry(industry)} className={`w-full text-left px-3 py-2 border rounded-none transition text-sm ${selectedIndustry?.id === industry.id ? 'bg-blue-600 border-blue-500' : 'bg-gray-800 border-gray-700 hover:bg-gray-700'}`}>{industry.name}</button>
            ))}
          </div>
        </div>

        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Upload Materials</h2>
          {selectedIndustry ? (
            <form onSubmit={handleUploadMaterial} className="space-y-3">
              <div className="text-sm text-gray-400 mb-3">Selected: <span className="text-blue-400 font-semibold">{selectedIndustry.name}</span></div>
              <input type="file" onChange={(e) => setTrainingFile(e.target.files?.[0] || null)} accept=".txt,.pdf,.md" className="w-full px-3 py-2 bg-gray-800 border border-gray-700 text-white rounded-none text-sm" />
              <button type="submit" disabled={loading || !trainingFile} className="w-full py-2 bg-green-600 hover:bg-green-700 rounded-none transition disabled:opacity-50 text-sm font-semibold">{loading ? 'Processing...' : 'Upload & Generate'}</button>
            </form>
          ) : (
            <p className="text-gray-400 text-sm">Select an industry first</p>
          )}
          <div className="mt-6">
            <h3 className="font-semibold mb-3 text-sm">Recent Materials</h3>
            <div className="space-y-2 max-h-96 overflow-y-auto">
              {materials.length === 0 ? <p className="text-gray-400 text-xs">No materials uploaded</p> : materials.map((material) => (
                <div key={material.id} className="p-2 bg-gray-800 border border-gray-700 rounded-none text-sm">
                  <p className="font-mono text-xs text-gray-300 truncate">{material.file_name}</p>
                  <p className="text-xs text-gray-500 mt-1">{new Date(material.uploaded_at).toLocaleDateString()}</p>
                </div>
              ))}
            </div>
          </div>
        </div>

        <div className="border border-gray-800 bg-gray-900 p-6 rounded-none">
          <h2 className="text-xl font-bold mb-4">Status</h2>
          <div className="space-y-3 text-sm">
            {error && <div className="p-3 bg-red-900 border border-red-700 text-red-200 rounded-none text-xs">{error}</div>}
            {success && <div className="p-3 bg-green-900 border border-green-700 text-green-200 rounded-none text-xs">{success}</div>}
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
