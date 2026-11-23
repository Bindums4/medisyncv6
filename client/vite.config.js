import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";
// host: true lets other devices on the same Wi-Fi open the site at http://<laptop-ip>:5173
export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5173,
    proxy: { "/api": "http://localhost:5000", "/socket.io": { target: "http://localhost:5000", ws: true } },
  },
});
