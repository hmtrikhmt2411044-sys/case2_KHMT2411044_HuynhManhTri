const notificationService = require('../services/notificationService');

// 1. Lấy danh sách thông báo của người dùng
exports.getNotifications = async (req, res) => {
  try {
    const userId = req.user._id;
    const { isRead, limit } = req.query;

    const notifications = await notificationService.getNotifications(userId, { isRead, limit });

    return res.status(200).json({
      success: true,
      data: notifications,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy danh sách thông báo: ' + error.message,
    });
  }
};

// 2. Lấy số lượng thông báo chưa đọc
exports.getUnreadCount = async (req, res) => {
  try {
    const userId = req.user._id;
    const count = await notificationService.getUnreadCount(userId);

    return res.status(200).json({
      success: true,
      unreadCount: count,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy số thông báo chưa đọc: ' + error.message,
    });
  }
};

// 3. Đánh dấu một thông báo đã đọc
exports.markAsRead = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const notif = await notificationService.markAsRead(id, userId);
    if (!notif) {
      return res.status(404).json({
        success: false,
        message: 'Thông báo không tồn tại hoặc bạn không có quyền',
      });
    }

    return res.status(200).json({
      success: true,
      message: 'Đã đánh dấu thông báo là đã đọc',
      data: notif,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi cập nhật thông báo: ' + error.message,
    });
  }
};

// 4. Đánh dấu tất cả thông báo là đã đọc
exports.markAllAsRead = async (req, res) => {
  try {
    const userId = req.user._id;
    await notificationService.markAllAsRead(userId);

    return res.status(200).json({
      success: true,
      message: 'Đã đánh dấu tất cả thông báo là đã đọc',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi cập nhật tất cả thông báo: ' + error.message,
    });
  }
};
