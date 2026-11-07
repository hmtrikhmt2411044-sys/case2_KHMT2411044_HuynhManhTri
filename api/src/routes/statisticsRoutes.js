const express = require('express');
const router = express.Router();
const statisticsController = require('../controllers/statisticsController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Thống kê theo trạng thái
router.get('/tasks', statisticsController.getTaskStatistics);

// Thống kê theo phân công
router.get('/assignments', statisticsController.getAssignmentStatistics);

// Thống kê theo thời hạn
router.get('/deadlines', statisticsController.getDeadlineStatistics);

// Tổng quan thống kê (Dashboard Overview)
router.get('/overview', statisticsController.getOverview);

module.exports = router;
