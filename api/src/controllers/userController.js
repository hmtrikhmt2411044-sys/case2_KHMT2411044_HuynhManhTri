const userStore = require('../services/userStore');

// Tìm kiếm danh sách thành viên trong hệ thống (để giao việc / chia sẻ)
exports.getUsers = async (req, res) => {
  try {
    const { search } = req.query;
    const currentUserId = req.user ? req.user._id : null;

    const users = await userStore.searchUsers(search, currentUserId);

    return res.status(200).json({
      success: true,
      count: users.length,
      data: users,
    });
  } catch (error) {
    console.error('Lỗi tìm kiếm thành viên:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi tìm kiếm thành viên: ' + error.message,
    });
  }
};
