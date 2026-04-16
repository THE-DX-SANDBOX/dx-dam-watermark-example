import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import path from 'path'

export default defineConfig({
  plugins: [react()],
  base: './',
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
  build: {
    outDir: 'dist',
    assetsDir: 'assets',
    sourcemap: false,
    target: 'es2015',
    cssCodeSplit: false,
    rollupOptions: {
      output: {
        manualChunks: undefined,
        inlineDynamicImports: true,
      }
    }
  },
  server: {
    port: 5173,
    strictPort: false,
    host: true,
    proxy: {
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
      '/projects': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
      '/specifications': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
      '/layers': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
      '/assets': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
      '/templates': {
        target: 'http://localhost:3000',
        changeOrigin: true,
        secure: false,
      },
    }
  }
})
