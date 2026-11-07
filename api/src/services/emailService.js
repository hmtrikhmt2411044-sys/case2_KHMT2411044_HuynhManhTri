const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const { createTransporter } = require('../config/email');
const EmailLog = require('../models/EmailLog');

const localEmailLogPath = path.join(__dirname, '../../data/local_email_logs.json');

const ensureLocalEmailLogDir = () => {
  const dir = path.dirname(localEmailLogPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const readLocalEmailLogs = () => {
  ensureLocalEmailLogDir();
  if (!fs.existsSync(localEmailLogPath)) {
    fs.writeFileSync(localEmailLogPath, JSON.stringify([], null, 2), 'utf8');
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(localEmailLogPath, 'utf8'));
  } catch (e) {
    return [];
  }
};

const writeLocalEmailLogs = (logs) => {
  ensureLocalEmailLogDir();
  fs.writeFileSync(localEmailLogPath, JSON.stringify(logs, null, 2), 'utf8');
};

const isMongooseConnected = () => mongoose.connection.readyState === 1;

// Template HTML email chuẩn giao diện hiện đại, chuyên nghiệp
const buildEmailHtml = ({ title, subtitle, taskTitle, details, callToActionText, accentColor = '#2563EB' }) => {
  const detailsHtml = Object.entries(details)
    .filter(([_, val]) => val !== undefined && val !== null && val !== '')
    .map(
      ([key, val]) => `
      <tr>
        <td style="padding: 10px 14px; font-weight: 600; color: #475569; width: 35%; border-bottom: 1px solid #F1F5F9; font-size: 13px;">${key}</td>
        <td style="padding: 10px 14px; color: #0F172A; font-weight: 500; border-bottom: 1px solid #F1F5F9; font-size: 13px;">${val}</td>
      </tr>
    `
    )
    .join('');

  return `
  <!DOCTYPE html>
  <html>
  <head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
  </head>
  <body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color: #F8FAFC; padding: 30px 12px;">
      <tr>
        <td align="center">
          <table width="600" cellpadding="0" cellspacing="0" style="max-width: 600px; width: 100%; background-color: #FFFFFF; border-radius: 16px; overflow: hidden; box-shadow: 0 4px 20px rgba(0, 0, 0, 0.05); border: 1px solid #E2E8F0;">
            <!-- Header -->
            <tr>
              <td style="background: linear-gradient(135deg, ${accentColor} 0%, #1D4ED8 100%); padding: 32px 28px; text-align: center;">
                <div style="font-size: 28px; margin-bottom: 8px;">📋</div>
                <h1 style="margin: 0; color: #FFFFFF; font-size: 20px; font-weight: 700; letter-spacing: -0.5px;">Task Manager Pro</h1>
                <p style="margin: 6px 0 0; color: rgba(255, 255, 255, 0.9); font-size: 13px;">Quản lý & Giao việc nhóm hiệu quả</p>
              </td>
            </tr>

            <!-- Body -->
            <tr>
              <td style="padding: 32px 28px;">
                <div style="margin-bottom: 24px;">
                  <h2 style="margin: 0 0 8px; color: #0F172A; font-size: 18px; font-weight: 700;">${title}</h2>
                  <p style="margin: 0; color: #64748B; font-size: 14px; line-height: 1.5;">${subtitle}</p>
                </div>

                <!-- Task Card -->
                <div style="background-color: #F8FAFC; border: 1px solid #E2E8F0; border-radius: 12px; padding: 20px; margin-bottom: 24px;">
                  <div style="font-size: 11px; font-weight: 700; color: ${accentColor}; text-transform: uppercase; letter-spacing: 0.5px; margin-bottom: 6px;">Công việc</div>
                  <div style="font-size: 16px; font-weight: 700; color: #0F172A; line-height: 1.4; margin-bottom: 16px;">${taskTitle}</div>
                  
                  <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse: collapse; background-color: #FFFFFF; border-radius: 8px; overflow: hidden; border: 1px solid #E2E8F0;">
                    ${detailsHtml}
                  </table>
                </div>

                <!-- Call to action button -->
                ${
                  callToActionText
                    ? `
                <div style="text-align: center; margin-top: 28px;">
                  <span style="display: inline-block; background-color: ${accentColor}; color: #FFFFFF; font-weight: 600; font-size: 14px; padding: 12px 28px; border-radius: 10px; text-decoration: none; box-shadow: 0 2px 8px rgba(37, 99, 235, 0.25);">
                    ${callToActionText}
                  </span>
                </div>
                `
                    : ''
                }
              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td style="background-color: #F8FAFC; padding: 20px 28px; text-align: center; border-top: 1px solid #E2E8F0;">
                <p style="margin: 0; color: #94A3B8; font-size: 12px;">Email thông báo tự động từ Hệ thống Quản lý Công việc Nhóm.</p>
                <p style="margin: 4px 0 0; color: #94A3B8; font-size: 11px;">Sinh viên: Huỳnh Mạnh Trí - MSSV: KHMT2411044</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
  </html>
  `;
};

// Ghi log email vào Database (hoặc Local File)
const logEmail = async ({ taskId, recipientEmail, eventType, subject, contentPreview, status, errorMessage, sentAt }) => {
  const logData = {
    taskId: taskId ? String(taskId) : null,
    recipientEmail: recipientEmail.toLowerCase().trim(),
    eventType,
    subject,
    contentPreview: contentPreview || '',
    status,
    errorMessage: errorMessage || null,
    sentAt: sentAt || null,
    attempts: 1,
    createdAt: new Date(),
  };

  if (isMongooseConnected()) {
    try {
      return await EmailLog.create(logData);
    } catch (e) {
      console.warn('[Email Log Mongoose Error]', e.message);
    }
  }

  // Local fallback
  const logs = readLocalEmailLogs();
  const localRecord = {
    _id: 'email_log_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
    ...logData,
  };
  logs.unshift(localRecord);
  writeLocalEmailLogs(logs.slice(0, 200));
  return localRecord;
};

// Hàm gửi email lõi
const sendEmail = async ({ toEmail, subject, html, text, taskId = null, eventType = 'general' }) => {
  const from = process.env.EMAIL_FROM || 'Task Manager Pro <noreply@taskmanager.com>';
  const transporter = createTransporter();

  if (transporter) {
    try {
      const info = await transporter.sendMail({
        from,
        to: toEmail,
        subject,
        text: text || subject,
        html,
      });
      console.log(`[Email Sent] Đã gửi email tới ${toEmail} [ID: ${info.messageId}]`);
      return await logEmail({
        taskId,
        recipientEmail: toEmail,
        eventType,
        subject,
        contentPreview: text || subject,
        status: 'sent',
        sentAt: new Date(),
      });
    } catch (error) {
      console.error(`[Email Error] Thất bại khi gửi email tới ${toEmail}:`, error.message);
      return await logEmail({
        taskId,
        recipientEmail: toEmail,
        eventType,
        subject,
        contentPreview: text || subject,
        status: 'failed',
        errorMessage: error.message,
      });
    }
  } else {
    // Chế độ mô phỏng (Simulated Sent) khi chưa thiết lập SMTP thực tế
    console.log(`[Email Simulated] Đã ghi nhận gửi email tới ${toEmail}: "${subject}"`);
    return await logEmail({
      taskId,
      recipientEmail: toEmail,
      eventType,
      subject,
      contentPreview: text || subject,
      status: 'sent',
      sentAt: new Date(),
    });
  }
};

module.exports = {
  // 1. Gửi email khi giao việc mới
  async sendAssignEmail({ toEmail, recipientName, task, assignerName, isPrimary = false }) {
    if (!toEmail) return null;
    const roleText = isPrimary ? 'Người phụ trách chính ⭐' : 'Thành viên thực hiện';
    const subject = `[Giao việc] Bạn vừa được giao công việc: "${task.title}"`;
    const html = buildEmailHtml({
      title: 'Bạn có một công việc mới được giao',
      subtitle: `Xin chào <strong>${recipientName || 'bạn'}</strong>, <strong>${assignerName || 'Một thành viên'}</strong> vừa phân công bạn tham gia công việc.`,
      taskTitle: task.title,
      details: {
        'Vai trò của bạn': roleText,
        'Người giao việc': assignerName || 'Quản lý',
        'Mức độ ưu tiên': task.priority === 'urgent' ? 'Khẩn cấp ⚡' : task.priority === 'high' ? 'Cao' : task.priority === 'medium' ? 'Trung bình' : 'Thấp',
        'Hạn hoàn thành': task.dueDate ? new Date(task.dueDate).toLocaleDateString('vi-VN') : 'Không giới hạn',
        'Mô tả': task.description || 'Không có mô tả chi tiết',
      },
      callToActionText: 'Mở ứng dụng Task Manager để nhận việc',
      accentColor: '#2563EB',
    });

    return await sendEmail({
      toEmail,
      subject,
      html,
      text: `Bạn được giao công việc: ${task.title}. Vai trò: ${roleText}. Người giao: ${assignerName}`,
      taskId: task._id || task.id,
      eventType: 'assigned',
    });
  },

  // 2. Gửi email khi chia sẻ quyền (Viewer / Editor)
  async sendShareEmail({ toEmail, recipientName, task, sharerName, permission }) {
    if (!toEmail) return null;
    const permText = permission === 'editor' ? 'Chỉnh sửa (Editor) ✏️' : 'Chỉ xem (Viewer) 👁️';
    const subject = `[Chia sẻ] Bạn được cấp quyền ${permission === 'editor' ? 'Chỉnh sửa' : 'Xem'} công việc: "${task.title}"`;
    const html = buildEmailHtml({
      title: 'Công việc được chia sẻ với bạn',
      subtitle: `Xin chào <strong>${recipientName || 'bạn'}</strong>, <strong>${sharerName || 'Người tạo'}</strong> vừa chia sẻ công việc với bạn.`,
      taskTitle: task.title,
      details: {
        'Quyền được cấp': permText,
        'Người chia sẻ': sharerName || 'Người tạo',
        'Trạng thái': task.status === 'completed' ? 'Đã hoàn thành' : task.status === 'in_progress' ? 'Đang thực hiện' : 'Cần làm',
        'Mô tả': task.description || 'Không có mô tả chi tiết',
      },
      callToActionText: 'Mở ứng dụng Task Manager để xem công việc',
      accentColor: '#7C3AED',
    });

    return await sendEmail({
      toEmail,
      subject,
      html,
      text: `Công việc "${task.title}" vừa được chia sẻ với bạn. Quyền: ${permText}. Người chia sẻ: ${sharerName}`,
      taskId: task._id || task.id,
      eventType: 'shared',
    });
  },

  // 3. Gửi email khi thay đổi trạng thái / hoàn thành công việc
  async sendStatusUpdateEmail({ toEmail, recipientName, task, updaterName, newStatus }) {
    if (!toEmail) return null;
    const statusLabel = newStatus === 'completed' ? 'Hoàn thành 🎉' : newStatus === 'in_progress' ? 'Đang thực hiện 🚀' : 'Cần làm';
    const isCompleted = newStatus === 'completed';
    const subject = isCompleted
      ? `[Hoàn thành] Công việc "${task.title}" đã được hoàn thành!`
      : `[Cập nhật] Công việc "${task.title}" chuyển sang trạng thái "${statusLabel}"`;

    const html = buildEmailHtml({
      title: isCompleted ? 'Công việc đã được đánh dấu hoàn thành!' : 'Cập nhật tiến độ công việc',
      subtitle: `Xin chào <strong>${recipientName || 'bạn'}</strong>, <strong>${updaterName || 'Thành viên'}</strong> vừa cập nhật trạng thái công việc.`,
      taskTitle: task.title,
      details: {
        'Trạng thái mới': statusLabel,
        'Người cập nhật': updaterName || 'Thành viên',
        'Thời gian': new Date().toLocaleString('vi-VN'),
      },
      callToActionText: 'Mở ứng dụng để kiểm tra tiến độ',
      accentColor: isCompleted ? '#10B981' : '#F59E0B',
    });

    return await sendEmail({
      toEmail,
      subject,
      html,
      text: `Công việc "${task.title}" vừa chuyển sang trạng thái: ${statusLabel} bởi ${updaterName}`,
      taskId: task._id || task.id,
      eventType: isCompleted ? 'completed' : 'status_changed',
    });
  },

  // 4. Lấy danh sách email log theo taskId
  async getEmailLogsByTaskId(taskId) {
    const taskIdStr = String(taskId);
    if (isMongooseConnected()) {
      return await EmailLog.find({ taskId: taskIdStr }).sort({ createdAt: -1 });
    }
    const logs = readLocalEmailLogs();
    return logs.filter((l) => String(l.taskId) === taskIdStr);
  },

  // 5. Thử gửi lại email (Retry)
  async retryEmail(logId) {
    let logRecord = null;
    if (isMongooseConnected()) {
      logRecord = await EmailLog.findById(logId);
    } else {
      const logs = readLocalEmailLogs();
      logRecord = logs.find((l) => String(l._id) === String(logId));
    }

    if (!logRecord) {
      throw new Error('Bản ghi email không tồn tại');
    }

    // Thử gửi lại
    return await sendEmail({
      toEmail: logRecord.recipientEmail,
      subject: logRecord.subject,
      html: `<p>${logRecord.contentPreview}</p>`,
      text: logRecord.contentPreview,
      taskId: logRecord.taskId,
      eventType: logRecord.eventType,
    });
  },
};
