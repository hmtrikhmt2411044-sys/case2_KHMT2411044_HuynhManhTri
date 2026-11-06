const express = require('express');
const router = express.Router();
const taskController = require('../controllers/taskController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Tạo công việc mới
router.post('/', taskController.createTask);

module.exports = router;
