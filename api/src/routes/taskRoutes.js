const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
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
router.post('/:id/share', taskController.shareTask);
router.delete('/:id/share/:targetUserId', taskController.revokeShare);
router.get('/:id/shares', taskController.getTaskShares);

module.exports = router;
