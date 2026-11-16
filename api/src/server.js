require('dotenv').config();
const app = require('./app');
const connectDB = require('./config/database');
const { startDeadlineReminderScheduler } = require('./services/reminderService');

const PORT = process.env.PORT || 3000;

// Kết nối cơ sở dữ liệu MongoDB
connectDB();

// Khởi động tác vụ nhắc việc trước hạn tự động (mặc định kiểm tra hạn trong 24h)
startDeadlineReminderScheduler();

app.listen(PORT, () => {
  console.log(`[Server] API đang chạy tại http://localhost:${PORT}`);
  console.log(`[Auth] Các endpoint xác thực sẵn sàng tại http://localhost:${PORT}/api/auth`);
});
