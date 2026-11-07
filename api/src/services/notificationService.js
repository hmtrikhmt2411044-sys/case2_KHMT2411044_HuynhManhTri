const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Notification = require('../models/Notification');

const localNotifPath = path.join(__dirname, '../../data/local_notifications.json');

const ensureLocalNotifDir = () => {
  const dir = path.dirname(localNotifPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const readLocalNotifications = () => {
  ensureLocalNotifDir();
  if (!fs.existsSync(localNotifPath)) {
    fs.writeFileSync(localNotifPath, JSON.stringify([], null, 2), 'utf8');
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(localNotifPath, 'utf8'));
  } catch (e) {
    return [];
  }
};

const writeLocalNotifications = (notifs) => {
  ensureLocalNotifDir();
  fs.writeFileSync(localNotifPath, JSON.stringify(notifs, null, 2), 'utf8');
};

const isMongooseConnected = () => mongoose.connection.readyState === 1;

module.exports = {
  // 1. Tạo thông báo mới
  async createNotification({ userId, taskId = null, type = 'general', title, message }) {
    const userIdStr = String(userId);
    const taskIdStr = taskId ? String(taskId) : null;

    if (isMongooseConnected()) {
      try {
        const notif = await Notification.create({
          userId: userIdStr,
          taskId: taskIdStr,
          type,
          title,
          message,
          isRead: false,
        });
        return notif;
      } catch (e) {
        console.warn('[Notification Mongoose Error]', e.message);
      }
    }

    // Local fallback
    const notifs = readLocalNotifications();
    const newNotif = {
      _id: 'notif_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      userId: userIdStr,
      taskId: taskIdStr,
      type,
      title,
      message,
      isRead: false,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    notifs.unshift(newNotif);
    writeLocalNotifications(notifs.slice(0, 300));
    return newNotif;
  },

  // 2. Lấy danh sách thông báo của người dùng
  async getNotifications(userId, { isRead = null, limit = 50 } = {}) {
    const userIdStr = String(userId);

    if (isMongooseConnected()) {
      const filter = { userId: userIdStr };
      if (isRead !== null && isRead !== undefined) {
        filter.isRead = isRead === 'true' || isRead === true;
      }
      return await Notification.find(filter)
        .sort({ createdAt: -1 })
        .limit(parseInt(limit, 10) || 50)
        .populate('taskId', 'title status priority');
    }

    // Local fallback
    const notifs = readLocalNotifications();
    return notifs
      .filter((n) => {
        if (String(n.userId) !== userIdStr) return false;
        if (isRead !== null && isRead !== undefined) {
          const targetBool = isRead === 'true' || isRead === true;
          return n.isRead === targetBool;
        }
        return true;
      })
      .slice(0, parseInt(limit, 10) || 50);
  },

  // 3. Đếm số thông báo chưa đọc
  async getUnreadCount(userId) {
    const userIdStr = String(userId);

    if (isMongooseConnected()) {
      return await Notification.countDocuments({ userId: userIdStr, isRead: false });
    }

    const notifs = readLocalNotifications();
    return notifs.filter((n) => String(n.userId) === userIdStr && !n.isRead).length;
  },

  // 4. Đánh dấu một thông báo đã đọc
  async markAsRead(notificationId, userId) {
    const notifIdStr = String(notificationId);
    const userIdStr = String(userId);

    if (isMongooseConnected()) {
      return await Notification.findOneAndUpdate(
        { _id: notifIdStr, userId: userIdStr },
        { isRead: true },
        { new: true }
      );
    }

    const notifs = readLocalNotifications();
    const idx = notifs.findIndex((n) => String(n._id) === notifIdStr && String(n.userId) === userIdStr);
    if (idx !== -1) {
      notifs[idx].isRead = true;
      notifs[idx].updatedAt = new Date().toISOString();
      writeLocalNotifications(notifs);
      return notifs[idx];
    }
    return null;
  },

  // 5. Đánh dấu tất cả thông báo đã đọc
  async markAllAsRead(userId) {
    const userIdStr = String(userId);

    if (isMongooseConnected()) {
      await Notification.updateMany({ userId: userIdStr, isRead: false }, { isRead: true });
      return true;
    }

    const notifs = readLocalNotifications();
    notifs.forEach((n) => {
      if (String(n.userId) === userIdStr) {
        n.isRead = true;
        n.updatedAt = new Date().toISOString();
      }
    });
    writeLocalNotifications(notifs);
    return true;
  },
};
