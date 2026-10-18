import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// Saída estática com nomes fixos (sem hash) para listar no meta.xml do MTA.
// O CEF do MTA serve os arquivos em http://mta/local/. Para evitar qualquer restrição de
// script "module"/crossorigin nesse esquema, o bundle (sem import/export) é carregado como script clássico.
const classicScript = () => ({
  name: 'classic-script',
  transformIndexHtml: (html) => html.replace(' type="module" crossorigin', ' defer').replace(' crossorigin', ''),
})

export default defineConfig({
  plugins: [react(), classicScript()],
  base: './',
  build: {
    modulePreload: false,
    outDir: '../dist',
    emptyOutDir: true,
    assetsDir: 'assets',
    target: 'es2018',
    rollupOptions: {
      output: {
        entryFileNames: 'assets/hub.js',
        chunkFileNames: 'assets/[name].js',
        assetFileNames: 'assets/[name][extname]',
      },
    },
  },
})
