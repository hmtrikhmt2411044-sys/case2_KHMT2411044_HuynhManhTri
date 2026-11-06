const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Lấy danh sách và chi tiết công việc
router.get('/', taskController.getTasks);
router.get('/:id', taskController.getTaskById);

// Tạo công việc mới
router.post('/', taskController.createTask);

module.exports = router;
