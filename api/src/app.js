const express = require('express');
const cors = require('cors');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// Health check route
app.get('/api', (req, res) => {
  res.json({
    message: 'Welcome to Task Manager API (Case Study 2)',
    author: 'Huynh Manh Tri - KHMT2411044',
    status: 'running'
  });
});

module.exports = app;
