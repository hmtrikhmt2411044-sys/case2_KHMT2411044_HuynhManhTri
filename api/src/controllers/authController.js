const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const User = require('../models/User');

const generateToken = (userId) => {
  const secret = process.env.JWT_SECRET || 'default_jwt_secret_case2_taskmanager_KHMT2411044';
  const expiresIn = process.env.JWT_EXPIRES_IN || '7d';
  return jwt.sign({ id: userId }, secret, { expiresIn });
};

// 1. Đăng ký tài khoản
exports.register = async (req, res) => {
  try {
    const { fullName, email, password } = req.body;

    // Validate dữ liệu đầu vào
    if (!fullName || !fullName.trim()) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập họ và tên' });
    }
    if (!email || !email.trim()) {
      return res.status(400).json({ success: false, message: 'Vui lòng nhập email' });
    }
    if (!password || password.length < 6) {
      return res.status(400).json({ success: false, message: 'Mật khẩu phải có ít nhất 6 ký tự' });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Kiểm tra email trùng lặp
    const existingUser = await User.findOne({ email: cleanEmail });
    if (existingUser) {
      return res.status(400).json({
        success: false,
        message: 'Email này đã được sử dụng. Vui lòng chọn email khác.',
      });
    }

    // Băm mật khẩu bằng bcrypt
    const salt = await bcrypt.genSalt(10);
    const passwordHash = await bcrypt.hash(password, salt);

    // Tạo người dùng mới
    const newUser = await User.create({
      fullName: fullName.trim(),
      email: cleanEmail,
      passwordHash,
    });

    // Tạo JWT token
    const token = generateToken(newUser._id);

    return res.status(201).json({
      success: true,
      message: 'Đăng ký tài khoản thành công',
      data: {
        user: newUser,
        token,
      },
    });
  } catch (error) {
    console.error('Lỗi đăng ký:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi đăng ký: ' + error.message,
    });
  }
};

// 2. Đăng nhập bằng email và mật khẩu
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng nhập đầy đủ email và mật khẩu',
      });
    }

    const cleanEmail = email.trim().toLowerCase();

    // Tìm người dùng theo email
    const user = await User.findOne({ email: cleanEmail });
    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Email hoặc mật khẩu không chính xác',
      });
    }

    // Kiểm tra mật khẩu
    const isMatch = await user.isValidPassword(password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: 'Email hoặc mật khẩu không chính xác',
      });
    }

    // Tạo token
    const token = generateToken(user._id);

    return res.status(200).json({
      success: true,
      message: 'Đăng nhập thành công',
      data: {
        user,
        token,
      },
    });
  } catch (error) {
    console.error('Lỗi đăng nhập:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi đăng nhập: ' + error.message,
    });
  }
};

// 3. Lấy thông tin cá nhân (Profile)
exports.getProfile = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,
      data: req.user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy thông tin cá nhân: ' + error.message,
    });
  }
};

// 4. Cập nhật thông tin cá nhân
exports.updateProfile = async (req, res) => {
  try {
    const { fullName, avatarUrl } = req.body;
    const userId = req.user._id;

    const updates = {};
    if (fullName && fullName.trim()) updates.fullName = fullName.trim();
    if (avatarUrl !== undefined) updates.avatarUrl = avatarUrl;

    const updatedUser = await User.findByIdAndUpdate(userId, updates, {
      new: true,
      runValidators: true,
    });

    return res.status(200).json({
      success: true,
      message: 'Cập nhật thông tin cá nhân thành công',
      data: updatedUser,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi cập nhật thông tin: ' + error.message,
    });
  }
};

// 5. Đổi mật khẩu
exports.changePassword = async (req, res) => {
  try {
    const { currentPassword, newPassword } = req.body;
    const user = await User.findById(req.user._id);

    if (!currentPassword || !newPassword) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng cung cấp mật khẩu hiện tại và mật khẩu mới',
      });
    }

    if (newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu mới phải có ít nhất 6 ký tự',
      });
    }

    // Kiểm tra mật khẩu hiện tại
    const isMatch = await user.isValidPassword(currentPassword);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: 'Mật khẩu hiện tại không đúng',
      });
    }

    // Mã hóa mật khẩu mới
    const salt = await bcrypt.genSalt(10);
    user.passwordHash = await bcrypt.hash(newPassword, salt);
    await user.save();

    return res.status(200).json({
      success: true,
      message: 'Đổi mật khẩu thành công',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi đổi mật khẩu: ' + error.message,
    });
  }
};
