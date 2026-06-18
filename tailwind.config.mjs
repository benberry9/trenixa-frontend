/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./src/pages/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/components/**/*.{js,ts,jsx,tsx,mdx}",
    "./src/app/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: "#0DBABA",
      },
      fontFamily: {
        lemmon: ['lemmon_milk', 'sans-serif'],
        avenir: ['AvenirLTStd', 'sans-serif'],
        lemmonbold: ['lemmon_milk_bold', 'sans-serif'],
      }
    },
  },
  plugins: [],
};
