import type { Config } from 'tailwindcss';

export default {
  content: [
    './src/**/*.{html,js,svelte,ts}',
    './node_modules/flowbite-svelte/**/*.{js,svelte,ts}',   // <- vigtigt for Flowbite Svelte
  ],

  safelist: [
    "bg-green-100",
    "text-green-800",

    "bg-red-100",
    "text-red-700",

    "bg-yellow-100",
    "text-yellow-700",

    "bg-slate-100",
    "text-slate-700",
  ],

  theme: {
    extend: {
  colors: {
    darkblue: "var(--darkblue)",
    primary: {
      50: "var(--color-primary-50)",
      100: "var(--color-primary-100)",
      500: "var(--color-primary-500)",
      900: "var(--color-primary-900)",
    }
  }
},
  },
  plugins: [], // ingen ekstra plugins
} as Config;
