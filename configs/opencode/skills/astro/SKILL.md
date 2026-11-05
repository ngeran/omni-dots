---
name: astro
description: Astro 5 sites with Tailwind v4, content collections, i18n. Load for .astro files, astro.config, content collections, or Astro build errors.
---

## Rules
- Check the Astro 5 API via Context7 before using content collections, i18n
  routing, or actions.
- Content collections use the `loader`-based config in
  `src/content.config.ts`.
- Tailwind v4: CSS-first config (`@import "tailwindcss"` and `@theme`), no
  `tailwind.config.js`.
- Verify with `astro check` and `astro build`. Both must pass.
- Default to zero client JS; add islands only where interactivity is needed.
