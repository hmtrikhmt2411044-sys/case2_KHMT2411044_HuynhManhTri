const mongoose = require('mongoose');
const Task = require('../models/Task');
const Notification = require('../models/Notification');
const userStore = require('./userStore');
const notificationService = require('./notificationService');
const emailService = require('./emailService');

/**
 * Kiểm tra các công việc sắp đến hạn trong khoảng cấu hình (mặc định 24 giờ)
 * và tự động gửi thông báo trong ứng dụng + email nhắc nhở.
 */
async function checkUpcomingDeadlines() {
  if (mongoose.connection.readyState !== 1) return 0;

  const hoursBefore = parseInt(process.env.REMINDER_HOURS_BEFORE_DUE || '24', 10);
  const now = new Date();
  const windowEnd = new Date(now.getTime() + hoursBefore * 60 * 60 * 1000);
  const recentCutoff = new Date(now.getTime() - hoursBefore * 60 * 60 * 1000);

  const upcomingTasks = await Task.find({
    status: { $ne: 'completed' },
    dueDate: { $gt: now, $lte: windowEnd },
  });

  let sentCount = 0;

  for (const task of upcomingTasks) {
    const recipientIds = new Set([String(task.createdBy)]);
    if (Array.isArray(task.assigneeIds)) {
      task.assigneeIds.forEach((id) => recipientIds.add(String(id)));
    }

    const hoursLeft = (new Date(task.dueDate).getTime() - now.getTime()) / (1000 * 60 * 60);

    for (const userId of recipientIds) {
      // Tránh gửi trùng lặp nếu đã nhắc trong vòng hoursBefore giờ qua
      const alreadyReminded = await Notification.findOne({
        userId,
        taskId: task._id,
        type: 'deadline_approaching',
        createdAt: { $gte: recentCutoff },
      });
      if (alreadyReminded) continue;

      const user = await userStore.findById(userId);
      if (!user) continue;

      await notificationService.createNotification({
        userId,
        taskId: task._id,
        type: 'deadline_approaching',
        title: 'Nhắc việc sắp đến hạn ⏰',
        message: `Công việc "${task.title}" còn khoảng ${Math.max(1, Math.round(hoursLeft))} giờ nữa là đến hạn.`,
      });

      if (user.email) {
        await emailService.sendDeadlineReminderEmail({
          toEmail: user.email,
          recipientName: user.fullName,
          task,
          hoursLeft,
        });
      }
      sentCount++;
    }
  }

  return sentCount;
}

function startDeadlineReminderScheduler() {
  const intervalMs = parseInt(process.env.REMINDER_INTERVAL_MS || String(60 * 60 * 1000), 10);
  // Chạy kiểm tra lần đầu sau 10 giây khi DB đã sẵn sàng, sau đó lặp lại định kỳ
  setTimeout(() => {
    checkUpcomingDeadlines().catch((err) => {
      console.warn('[Reminder Scheduler Error]', err.message);
    });
  }, 10000).unref();

  const timer = setInterval(() => {
    checkUpcomingDeadlines().catch((err) => {
      console.warn('[Reminder Scheduler Error]', err.message);
    });
  }, intervalMs);
  timer.unref();
}

module.exports = {
  checkUpcomingDeadlines,
  startDeadlineReminderScheduler,
};
