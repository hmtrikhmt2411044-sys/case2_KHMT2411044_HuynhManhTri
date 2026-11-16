const mongoose = require('mongoose');
const jwt = require('jsonwebtoken');
const userStore = require('../services/userStore');

const waitForAtlasIfConnecting = async () => {
  if (!process.env.MONGODB_URI || mongoose.connection.readyState === 1) return;
  if (mongoose.connection.readyState === 2) {
    await new Promise((resolve) => {
      const timer = setTimeout(resolve, 5000);
      const onDone = () => {
        clearTimeout(timer);
        resolve();
      };
      mongoose.connection.once('connected', onDone);
      mongoose.connection.once('error', onDone);
    });
  }
};

const authMiddleware = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        success: false,
        message: 'Không tìm thấy token xác thực hoặc sai định dạng',
      });
    }

    const token = authHeader.split(' ')[1];
    const secret = process.env.JWT_SECRET || 'default_jwt_secret_case2_taskmanager_KHMT2411044';

    let decoded;
    try {
      decoded = jwt.verify(token, secret);
    } catch (jwtErr) {
      return res.status(401).json({
        success: false,
        message: 'Token hết hạn hoặc không hợp lệ: ' + jwtErr.message,
      });
    }

    await waitForAtlasIfConnecting();

    // Không trả 401 khi Atlas tạm thời gián đoạn để tránh đăng xuất nhầm người dùng
    if (process.env.MONGODB_URI && mongoose.connection.readyState !== 1) {
      return res.status(503).json({
        success: false,
        message: 'Máy chủ đang kết nối cơ sở dữ liệu, vui lòng thử lại sau giây lát',
      });
    }

    let user;
    try {
      user = await userStore.findById(decoded.id);
    } catch (dbErr) {
      console.error('[Auth DB Error]', dbErr.message);
      return res.status(503).json({
        success: false,
        message: 'Lỗi kết nối cơ sở dữ liệu khi xác thực: ' + dbErr.message,
      });
    }

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'Tài khoản không tồn tại hoặc token không hợp lệ',
      });
    }

    req.user = user;
    next();
  } catch (error) {
    console.error('[Auth Unexpected Error]', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi máy chủ khi xác thực: ' + error.message,
    });
  }
};

module.exports = authMiddleware;
