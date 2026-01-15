import axios from 'axios';

// 使用相对路径，由服务器端代理转发到后端
const client = axios.create({
  baseURL: '/api/v1',
  timeout: 30000,
  headers: {
    'Content-Type': 'application/json'
  }
});

export default client;
