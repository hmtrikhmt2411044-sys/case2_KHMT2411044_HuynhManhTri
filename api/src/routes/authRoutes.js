const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// 1. Đăng ký tài khoản
router.post('/register', authController.register);

// 2. Đăng nhập bằng email và mật khẩu
router.post('/login', authController.login);

// 3. Xem và cập nhật thông tin cá nhân (Yêu cầu Token)
router.get('/me', authMiddleware, authController.getProfile);
router.put('/me', authMiddleware, authController.updateProfile);

module.exports = router;
