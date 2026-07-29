import { createClient } from '@supabase/supabase-js';

const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_ANON_KEY;

export const supabase = createClient(supabaseUrl, supabaseAnonKey);

export const auth = {
  signUp: async (email, password) => {
    return await supabase.auth.signUp({ email, password });
  },

  signIn: async (email, password) => {
    return await supabase.auth.signInWithPassword({ email, password });
  },

  signOut: async () => {
    return await supabase.auth.signOut();
  },

  getSession: async () => {
    const { data } = await supabase.auth.getSession();
    return data.session;
  },
};

export const db = {
  createAdmin: async (userId, email) => {
    return await supabase.from('admins').insert([{ user_id: userId, email }]).select();
  },

  getAdmin: async (userId) => {
    return await supabase.from('admins').select('*').eq('user_id', userId).single();
  },

  createUser: async (userId, email, fullName, industryId) => {
    return await supabase.from('users').insert([{ user_id: userId, email, full_name: fullName, industry_id: industryId }]).select();
  },

  getUser: async (userId) => {
    return await supabase.from('users').select('*').eq('user_id', userId).single();
  },

  createIndustry: async (adminId, name, systemPrompt) => {
    return await supabase.from('industries').insert([{ admin_id: adminId, name, system_prompt: systemPrompt }]).select();
  },

  getIndustries: async (adminId) => {
    return await supabase.from('industries').select('*').eq('admin_id', adminId);
  },

  uploadTrainingMaterial: async (industryId, adminId, fileName, filePath, fileSize) => {
    return await supabase.from('training_materials').insert([{ industry_id: industryId, admin_id: adminId, file_name: fileName, file_path: filePath, file_size: fileSize }]).select();
  },

  getTrainingMaterials: async (industryId) => {
    return await supabase.from('training_materials').select('*').eq('industry_id', industryId);
  },

  createGeneratedMaterial: async (trainingMaterialId, materialType, content) => {
    return await supabase.from('generated_materials').insert([{ training_material_id: trainingMaterialId, material_type: materialType, content }]).select();
  },

  getGeneratedMaterials: async (trainingMaterialId) => {
    return await supabase.from('generated_materials').select('*').eq('training_material_id', trainingMaterialId);
  },

  getLeaderboard: async (industryId) => {
    return await supabase.from('leaderboard').select('*').eq('industry_id', industryId).order('total_score', { ascending: false });
  },
};
