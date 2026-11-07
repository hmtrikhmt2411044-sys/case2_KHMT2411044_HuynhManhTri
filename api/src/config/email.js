const nodemailer = require('nodemailer');

// Cấu hình transporter Nodemailer sử dụng thông tin từ biến môi trường
const createTransporter = () => {
  const host = process.env.SMTP_HOST || 'smtp.gmail.com';
  const port = parseInt(process.env.SMTP_PORT, 10) || 587;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASS;

  // Nếu có thông tin đăng nhập SMTP
  if (user && pass && user !== 'your_email@gmail.com' && pass !== 'your_email_app_password') {
    return nodemailer.createTransport({
      host,
      port,
      secure: port === 465,
      auth: { user, pass },
      tls: {
        rejectUnauthorized: false,
      },
    });
  }

  // Chế độ mô phỏng / Development: nếu chưa cấu hình mật khẩu ứng dụng Gmail thực
  return null;
};

module.exports = {
  createTransporter,
};
