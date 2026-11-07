const express = require('express');
const router = express.Router();
const notificationController = require('../controllers/notificationController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Lấy danh sách thông báo
router.get('/', notificationController.getNotifications);

// Đếm số thông báo chưa đọc
router.get('/unread-count', notificationController.getUnreadCount);

// Đánh dấu tất cả đã đọc
router.patch('/read-all', notificationController.markAllAsRead);

// Đánh dấu 1 thông báo đã đọc
router.patch('/:id/read', notificationController.markAsRead);

module.exports = router;
