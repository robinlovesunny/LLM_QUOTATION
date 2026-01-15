/**
 * LLM_QUOTATION 前端生产服务器
 * 功能：服务静态文件 + API 代理
 */
const express = require('express');
const path = require('path');
const { createProxyMiddleware } = require('http-proxy-middleware');

const app = express();
const PORT = process.env.PORT || 3000;
const API_TARGET = process.env.API_TARGET || 'http://127.0.0.1:8000';

// API 代理配置 - 转发到后端
app.use('/api', createProxyMiddleware({
  target: API_TARGET,
  changeOrigin: true,
  pathRewrite: (path, req) => '/api' + path,  // 补回 /api 前缀
  logLevel: 'warn',
  onError: (err, req, res) => {
    console.error('[Proxy Error]', err.message);
    res.status(502).json({ error: 'Backend service unavailable' });
  }
}));

// 静态文件服务
app.use(express.static(path.join(__dirname, 'dist')));

// SPA 路由回退
app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`[${new Date().toISOString()}] Frontend server running on http://0.0.0.0:${PORT}`);
  console.log(`[${new Date().toISOString()}] API proxy target: ${API_TARGET}`);
});
