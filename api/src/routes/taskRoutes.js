const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const emailController = require('../controllers/emailController');
const authMiddleware = require('../middleware/authMiddleware');

// Tất cả các route /tasks đều yêu cầu đăng nhập
router.use(authMiddleware);

// CRUD công việc (Nhóm chức năng B)
router.get('/', taskController.getTasks);
router.post('/', taskController.createTask);
router.get('/:id', taskController.getTaskById);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateStatus);
router.delete('/:id', taskController.deleteTask);

// Giao việc & Chia sẻ (Nhóm chức năng C)
router.post('/:id/assign', taskController.assignTask);
router.post('/:id/assignees', taskController.assignTask);
router.post('/:id/share', taskController.shareTask);
router.post('/:id/shares', taskController.shareTask);
router.delete('/:id/share/:targetUserId', taskController.revokeShare);
router.delete('/:id/shares/:targetUserId', taskController.revokeShare);
router.get('/:id/shares', taskController.getTaskShares);

// Lịch sử gửi email của công việc (Nhóm chức năng D)
router.get('/:id/email-logs', emailController.getTaskEmailLogs);

// Lịch sử hoạt động của công việc (Nhóm chức năng E)
router.get('/:id/activities', taskController.getTaskActivities);

module.exports = router;
