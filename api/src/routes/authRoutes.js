const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// 1. Đăng ký tài khoản
router.post('/register', authController.register);

// 2. Đăng nhập bằng email và mật khẩu
router.post('/login', authController.login);

module.exports = router;
