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
          set({
            session,
            user: adminData.data,
            isAdmin: true,
            loading: false,
          });
        } else {
          const userData = await db.getUser(session.user.id);
          set({
            session,
            user: userData?.data || { user_id: session.user.id, email: session.user.email },
            isAdmin: false,
            loading: false,
          });
        }
      } else {
        set({
          session: null,
          user: null,
          isAdmin: false,
          loading: false,
        });
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

      console.log('Signup successful, user ID:', data.user.id);

      const adminResult = await db.createAdmin(data.user.id, email);
      console.log('Admin creation result:', adminResult);

      if (adminResult.error) {
        console.error('Admin creation error:', adminResult.error);
        throw adminResult.error;
      }

      set({
        session: data.session,
        user: { id: data.user.id, email, user_id: data.user.id },
        isAdmin: true,
        loading: false,
      });

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

      const userResult = await db.createUser(data.user.id, email, fullName, null);
      
      if (userResult.error) {
        throw userResult.error;
      }

      set({
        session: data.session,
        user: { user_id: data.user.id, email, full_name: fullName },
        isAdmin: false,
        loading: false,
      });

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
        set({
          session: data.session,
          user: adminData.data,
          isAdmin: true,
          loading: false,
        });
      } else {
        const userData = await db.getUser(data.user.id);
        set({
          session: data.session,
          user: userData?.data,
          isAdmin: false,
          loading: false,
        });
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
      await supabase.auth.signOut();
      set({
        session: null,
        user: null,
        isAdmin: false,
      });
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
        await supabase
          .from('admins')
          .update(updates)
          .eq('user_id', state.session.user.id);
      } else {
        await supabase
          .from('users')
          .update(updates)
          .eq('user_id', state.session.user.id);
      }

      set({
        user: { ...state.user, ...updates },
        loading: false,
      });

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
    useAuthStore.setState({
      session: null,
      user: null,
      isAdmin: false,
    });
  }
});
