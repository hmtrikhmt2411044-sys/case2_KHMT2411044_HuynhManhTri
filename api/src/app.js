const express = require('express');
const cors = require('cors');

const authRoutes = require('./routes/authRoutes');

const app = express();

// Middleware toàn cục
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Route kiểm tra trạng thái API
app.get('/api', (req, res) => {
  res.json({
    message: 'Welcome to Task Manager API (Case Study 2)',
    author: 'Huynh Manh Tri - KHMT2411044',
    status: 'online',
  });
});

// Gắn các route nghiệp vụ
app.use('/api/auth', authRoutes);

// Xử lý route không tồn tại (404)
app.use((req, res) => {
  res.status(404).json({
    success: false,
    message: 'Endpoint không tồn tại',
  });
});

module.exports = app;
