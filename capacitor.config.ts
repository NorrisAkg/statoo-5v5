// capacitor.config.ts
import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.elnor.statoo5v5',
  appName: 'Statoo 5v5',
  webDir: '.output/public',
  bundledWebRuntime: false,
  plugins: {
    StatusBar: {
      overlaysWebView: true,
    },
  },
};

export default config;
