// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  // Tailwind v4 ships as a Vite plugin — no tailwind.config.js, no
  // postcss.config.js; theme lives in CSS (@theme in src/styles/global.css).
  vite: {
    plugins: [tailwindcss()],
  },
});
