export const config = {
  appName: import.meta.env.VITE_APP_NAME || 'FutureEng',
  appDescription: import.meta.env.VITE_APP_DESCRIPTION || 'Training Platform',
  theme: {
    primary: import.meta.env.VITE_THEME_PRIMARY || 'blue',
    headerBg: import.meta.env.VITE_THEME_HEADER_BG || 'black',
  },
  features: {
    enableTutor: true,
    enableLeaderboard: true,
    enableBadges: true,
    enableStudyManual: true,
  },
};
