const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// CRUD công việc (Nhóm B)
router.get('/', taskController.getTasks);
router.post('/', taskController.createTask);
router.get('/:id', taskController.getTaskById);
router.put('/:id', taskController.updateTask);
router.patch('/:id/status', taskController.updateStatus);
router.delete('/:id', taskController.deleteTask);

// Giao việc cho thành viên & chỉ định người phụ trách chính (Nhóm C)
router.post('/:id/assign', taskController.assignTask);

// Chia sẻ công việc với quyền viewer/editor & lấy danh sách chia sẻ (Nhóm C)
router.post('/:id/share', taskController.shareTask);
router.get('/:id/shares', taskController.getTaskShares);

// Thu hồi quyền chia sẻ (Nhóm C)
router.delete('/:id/share/:targetUserId', taskController.revokeShare);

module.exports = router;
