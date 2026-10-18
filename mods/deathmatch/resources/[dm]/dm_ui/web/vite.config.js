import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import { readdirSync, statSync, writeFileSync, readFileSync } from 'node:fs'
import { join, relative } from 'node:path'

// Build para o CEF do MTA (http://mta/local/dist/...):
//  - nomes com hash: o cache do navegador interno nunca reaproveita um bundle antigo
//  - script clássico (sem type="module") e caminhos relativos
//  - gera ../meta.xml (lista de arquivos) e ../client/c_build.lua (versão) a cada build
const BUILD = new Date().toISOString().replace(/[-:T]/g, '').slice(0, 12)

const classicScript = () => ({
  name: 'classic-script',
  transformIndexHtml: (html) => html.replace(' type="module" crossorigin', ' defer').replace(' crossorigin', ''),
})

const walk = (dir) => readdirSync(dir).flatMap((f) => { const p = join(dir, f); return statSync(p).isDirectory() ? walk(p) : [p] })

const mtaFiles = () => ({
  name: 'mta-meta',
  closeBundle() {
    const dist = join(__dirname, '..', 'dist')
    const files = walk(dist).map((p) => 'dist/' + relative(dist, p).split('\\').join('/')).sort()
    const tpl = readFileSync(join(__dirname, 'meta.template.xml'), 'utf8')
    const list = files.map((f) => `    <file src="${f}" />`).join('\n')
    writeFileSync(join(__dirname, '..', 'meta.xml'), tpl.replace('<!-- FILES -->', list))
    writeFileSync(join(__dirname, '..', 'client', 'c_build.lua'), `-- gerado pelo build (npm run build) — não edite\nUI_BUILD = "${BUILD}"\n`)
  },
})

export default defineConfig({
  plugins: [react(), classicScript(), mtaFiles()],
  base: './',
  define: { __BUILD__: JSON.stringify(BUILD) },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    assetsDir: 'assets',
    target: 'es2018',
    modulePreload: false,
    rollupOptions: {
      output: {
        // IIFE em modo estrito: nenhuma variável do bundle vira global da página (o CEF do MTA injeta/altera
        // globais e isso quebrava o script clássico com escopo global)
        format: 'iife',
        strict: true,
        inlineDynamicImports: true,
        entryFileNames: 'assets/hub-[hash].js',
        chunkFileNames: 'assets/[name]-[hash].js',
        assetFileNames: 'assets/[name]-[hash][extname]',
      },
    },
  },
})
