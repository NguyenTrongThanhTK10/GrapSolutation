import { defineConfig } from 'vite';
import vue from '@vitejs/plugin-vue';
export default defineConfig({ plugins: [vue()], server: { port: 5173, proxy: { '/api': 'http://127.0.0.1:5080', '/hubs': { target: 'http://127.0.0.1:5080', ws: true } } }, build: { chunkSizeWarningLimit: 800 } });
