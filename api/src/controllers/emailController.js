const emailService = require('../services/emailService');
const taskStore = require('../services/taskStore');
const mongoose = require('mongoose');
const EmailLog = require('../models/EmailLog');

// 1. Xem lịch sử gửi email của một công việc
exports.getTaskEmailLogs = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Công việc không tồn tại',
      });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xem nhật ký email của công việc này',
      });
    }

    const logs = await emailService.getEmailLogsByTaskId(id);

    return res.status(200).json({
      success: true,
      count: logs.length,
      data: logs,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy lịch sử email: ' + error.message,
    });
  }
};

// 2. Thử gửi lại email (Retry)
exports.retryEmail = async (req, res) => {
  try {
    const { id } = req.params;
    if (mongoose.connection.readyState === 1) {
      const log = await EmailLog.findById(id);
      if (!log) {
        return res.status(404).json({ success: false, message: 'Bản ghi email không tồn tại' });
      }
      if (log.taskId) {
        const perm = await taskStore.checkPermission(log.taskId, req.user._id);
        if (perm !== 'owner' && perm !== 'editor' && req.user.role !== 'admin') {
          return res.status(403).json({
            success: false,
            message: 'Bạn không có quyền gửi lại email của công việc này',
          });
        }
      }
    }
    const result = await emailService.retryEmail(id);

    return res.status(200).json({
      success: true,
      message: 'Đã thực hiện gửi lại email',
      data: result,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi gửi lại email: ' + error.message,
    });
  }
};
