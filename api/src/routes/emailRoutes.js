const express = require('express');
const router = express.Router();
const emailController = require('../controllers/emailController');
const authMiddleware = require('../middleware/authMiddleware');

router.use(authMiddleware);

// Thử gửi lại email
router.post('/:id/retry', emailController.retryEmail);

module.exports = router;
