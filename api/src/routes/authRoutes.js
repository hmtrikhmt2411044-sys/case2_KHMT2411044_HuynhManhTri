const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware');

// Công khai (Public routes)
router.post('/register', authController.register);
router.post('/login', authController.login);

// Riêng tư (Private routes - Yêu cầu Token)
router.get('/me', authMiddleware, authController.getProfile);
router.put('/me', authMiddleware, authController.updateProfile);
router.put('/change-password', authMiddleware, authController.changePassword);

module.exports = router;
