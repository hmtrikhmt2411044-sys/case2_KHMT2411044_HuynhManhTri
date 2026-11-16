const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Lấy / tìm kiếm danh sách thành viên
router.get('/', userController.getUsers);
router.get('/search', userController.getUsers);
router.get('/:id', userController.getUserById);

module.exports = router;
