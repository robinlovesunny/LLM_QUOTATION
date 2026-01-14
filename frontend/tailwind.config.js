/** @type {import('tailwindcss').Config} */
export default {
  content: [
    "./index.html",
    "./src/**/*.{js,ts,jsx,tsx}",
  ],
  theme: {
    extend: {
      colors: {
        primary: '#0071E3',
        secondary: '#F5F5F7',
        text: {
          primary: '#1D1D1F',
          secondary: '#86868B'
        },
        border: '#D2D2D7'
      },
      fontFamily: {
        sans: ['-apple-system', 'BlinkMacSystemFont', 'Segoe UI', 'PingFang SC', 'Hiragino Sans GB', 'Microsoft YaHei', 'sans-serif']
      }
    },
  },
  plugins: [],
}
