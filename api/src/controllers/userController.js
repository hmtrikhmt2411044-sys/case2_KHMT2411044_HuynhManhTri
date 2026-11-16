const userStore = require('../services/userStore');

// Tìm kiếm danh sách thành viên trong hệ thống (để giao việc / chia sẻ)
exports.getUsers = async (req, res) => {
  try {
    const query = req.query.search || req.query.q;
    const currentUserId = req.user ? req.user._id : null;

    const users = await userStore.searchUsers(query, currentUserId);

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

// Xem thông tin công khai của 1 người dùng (GET /users/:id)
exports.getUserById = async (req, res) => {
  try {
    const user = await userStore.findById(req.params.id);
    if (!user) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy người dùng',
      });
    }
    const clean = user.toJSON ? user.toJSON() : {
      _id: user._id,
      fullName: user.fullName,
      email: user.email,
      avatarUrl: user.avatarUrl || '',
    };
    return res.status(200).json({
      success: true,
      data: clean,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy thông tin người dùng: ' + error.message,
    });
  }
};
