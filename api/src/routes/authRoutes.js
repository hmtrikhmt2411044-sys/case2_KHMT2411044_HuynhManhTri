const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// 1. Đăng ký tài khoản
router.post('/register', authController.register);

module.exports = router;
