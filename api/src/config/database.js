const mongoose = require('mongoose');
const dns = require('dns');

// Thiết lập DNS dự phòng để tránh lỗi SRV resolution trên mạng Việt Nam
try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (e) {
  // Bỏ qua nếu môi trường không cho phép
}

const connectDB = async () => {
  const uri = process.env.MONGODB_URI || 'mongodb://localhost:27017/task_manager_db';
  try {
    await mongoose.connect(uri, {
      serverSelectionTimeoutMS: 8000,
    });
    console.log(`[MongoDB Atlas] Kết nối thành công tới Database đám mây!`);
  } catch (error) {
    console.warn(`[MongoDB Warning] Không thể kết nối MongoDB: ${error.message}`);
    console.warn('[MongoDB Warning] Vui lòng kiểm tra lại MONGODB_URI trong file .env hoặc Network Access trên Atlas.');
  }
};

module.exports = connectDB;
