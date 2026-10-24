require('dotenv').config();
const app = require('./app');
const connectDB = require('./config/database');

const PORT = process.env.PORT || 3000;

// Kết nối cơ sở dữ liệu MongoDB
connectDB();

app.listen(PORT, () => {
  console.log(`[Server] API đang chạy tại http://localhost:${PORT}`);
  console.log(`[Auth] Các endpoint xác thực sẵn sàng tại http://localhost:${PORT}/api/auth`);
});
