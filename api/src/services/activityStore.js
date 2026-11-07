const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const TaskActivity = require('../models/TaskActivity');
const userStore = require('./userStore');

const localActivityPath = path.join(__dirname, '../../data/local_activities.json');

const ensureLocalActivityDir = () => {
  const dir = path.dirname(localActivityPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
};

const readLocalActivities = () => {
  ensureLocalActivityDir();
  if (!fs.existsSync(localActivityPath)) {
    fs.writeFileSync(localActivityPath, JSON.stringify([], null, 2), 'utf8');
    return [];
  }
  try {
    return JSON.parse(fs.readFileSync(localActivityPath, 'utf8'));
  } catch (e) {
    return [];
  }
};

const writeLocalActivities = (activities) => {
  ensureLocalActivityDir();
  fs.writeFileSync(localActivityPath, JSON.stringify(activities, null, 2), 'utf8');
};

const isMongooseConnected = () => mongoose.connection.readyState === 1;

module.exports = {
  // 1. Ghi nhận một hành động vào lịch sử
  async logActivity({ taskId, userId, action, details = {} }) {
    const taskIdStr = String(taskId);
    const userIdStr = String(userId);

    if (isMongooseConnected()) {
      try {
        return await TaskActivity.create({
          taskId: taskIdStr,
          userId: userIdStr,
          action,
          details,
        });
      } catch (e) {
        console.warn('[TaskActivity Mongoose Error]', e.message);
      }
    }

    // Local fallback
    const activities = readLocalActivities();
    const newAct = {
      _id: 'act_' + Date.now() + '_' + Math.random().toString(36).substring(2, 7),
      taskId: taskIdStr,
      userId: userIdStr,
      action,
      details,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    activities.unshift(newAct);
    writeLocalActivities(activities.slice(0, 500));
    return newAct;
  },

  // 2. Lấy danh sách lịch sử hoạt động của một công việc
  async getActivitiesByTaskId(taskId) {
    const taskIdStr = String(taskId);

    if (isMongooseConnected()) {
      return await TaskActivity.find({ taskId: taskIdStr })
        .sort({ createdAt: -1 })
        .populate('userId', 'fullName email avatarUrl');
    }

    // Local fallback
    const activities = readLocalActivities();
    const filtered = activities.filter((a) => String(a.taskId) === taskIdStr);

    // Populate user
    const users = await userStore.searchUsers();
    return filtered.map((act) => {
      const user = users.find((u) => String(u._id) === String(act.userId)) || {
        _id: act.userId,
        fullName: 'Người dùng',
        email: '',
      };
      return {
        ...act,
        userId: user,
      };
    });
  },
};
