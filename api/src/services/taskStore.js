const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Task = require('../models/Task');
const TaskShare = require('../models/TaskShare');
const userStore = require('./userStore');

const tasksFile = path.join(__dirname, '../../data/local_tasks.json');
const sharesFile = path.join(__dirname, '../../data/local_task_shares.json');

const ensureDataDir = () => {
  const dir = path.dirname(tasksFile);
  if (!fs.existsSync(dir)) fs.mkdirSync(dir, { recursive: true });
};

const readTasks = () => {
  ensureDataDir();
  if (!fs.existsSync(tasksFile)) return [];
  try {
    return JSON.parse(fs.readFileSync(tasksFile, 'utf8'));
  } catch (e) {
    return [];
  }
};

const writeTasks = (data) => {
  ensureDataDir();
  fs.writeFileSync(tasksFile, JSON.stringify(data, null, 2), 'utf8');
};

const readShares = () => {
  ensureDataDir();
  if (!fs.existsSync(sharesFile)) return [];
  try {
    return JSON.parse(fs.readFileSync(sharesFile, 'utf8'));
  } catch (e) {
    return [];
  }
};

const writeShares = (data) => {
  ensureDataDir();
  fs.writeFileSync(sharesFile, JSON.stringify(data, null, 2), 'utf8');
};

const isMongooseConnected = () => mongoose.connection.readyState === 1;

// Helper populate cho local store
const populateTask = async (task) => {
  if (!task) return null;
  const copy = { ...task };
  if (copy.createdBy) {
    const u = await userStore.findById(copy.createdBy);
    if (u) copy.createdBy = { _id: u._id, fullName: u.fullName, email: u.email };
  }
  if (copy.primaryAssigneeId) {
    const u = await userStore.findById(copy.primaryAssigneeId);
    if (u) copy.primaryAssigneeId = { _id: u._id, fullName: u.fullName, email: u.email };
  }
  if (Array.isArray(copy.assigneeIds)) {
    const populated = [];
    for (const aId of copy.assigneeIds) {
      const u = await userStore.findById(aId);
      if (u) populated.push({ _id: u._id, fullName: u.fullName, email: u.email });
      else populated.push({ _id: aId });
    }
    copy.assigneeIds = populated;
  }
  return copy;
};

module.exports = {
  // 1. Lấy danh sách công việc
  async getTasks({ userId, type = 'all', status, priority, search, sortBy = 'createdAt' }) {
    const userIdStr = String(userId);
    if (isMongooseConnected()) {
      let filter = {};
      if (type === 'my_tasks') {
        filter.createdBy = userId;
      } else if (type === 'assigned') {
        filter.assigneeIds = userId;
      } else if (type === 'shared') {
        const shares = await TaskShare.find({ userId }).select('taskId');
        const taskIds = shares.map((s) => s.taskId);
        filter._id = { $in: taskIds };
      } else {
        const shares = await TaskShare.find({ userId }).select('taskId');
        const sharedIds = shares.map((s) => s.taskId);
        filter.$or = [
          { createdBy: userId },
          { assigneeIds: userId },
          { _id: { $in: sharedIds } },
        ];
      }

      if (status) filter.status = status;
      if (priority) filter.priority = priority;
      if (search) {
        filter.title = { $regex: search, $options: 'i' };
      }

      let sortOption = { createdAt: -1 };
      if (sortBy === 'dueDate') sortOption = { dueDate: 1 };
      if (sortBy === 'priority') sortOption = { priority: -1 };

      const tasks = await Task.find(filter)
        .populate('createdBy', 'fullName email')
        .populate('assigneeIds', 'fullName email')
        .populate('primaryAssigneeId', 'fullName email')
        .sort(sortOption);

      return tasks;
    }

    // Local fallback
    const allTasks = readTasks();
    const allShares = readShares();
    const myShareTaskIds = allShares
      .filter((s) => String(s.userId) === userIdStr)
      .map((s) => String(s.taskId));

    let filtered = allTasks.filter((t) => {
      const isOwner = String(t.createdBy?._id || t.createdBy) === userIdStr;
      const isAssignee = Array.isArray(t.assigneeIds) &&
        t.assigneeIds.some((a) => String(a?._id || a) === userIdStr);
      const isShared = myShareTaskIds.includes(String(t._id));

      if (type === 'my_tasks' && !isOwner) return false;
      if (type === 'assigned' && !isAssignee) return false;
      if (type === 'shared' && !isShared) return false;
      if (type === 'all' && !isOwner && !isAssignee && !isShared) return false;

      if (status && t.status !== status) return false;
      if (priority && t.priority !== priority) return false;
      if (search && !t.title.toLowerCase().includes(search.toLowerCase())) return false;

      return true;
    });

    filtered.sort((a, b) => new Date(b.createdAt) - new Date(a.createdAt));

    const populatedList = [];
    for (const t of filtered) {
      populatedList.push(await populateTask(t));
    }
    return populatedList;
  },

  // 2. Lấy chi tiết công việc
  async getTaskById(taskId) {
    const idStr = String(taskId);
    if (isMongooseConnected()) {
      return await Task.findById(idStr)
        .populate('createdBy', 'fullName email')
        .populate('assigneeIds', 'fullName email')
        .populate('primaryAssigneeId', 'fullName email');
    }
    const tasks = readTasks();
    const found = tasks.find((t) => String(t._id) === idStr);
    if (!found) return null;
    return await populateTask(found);
  },

  // 3. Tạo công việc mới
  async createTask({ title, description, createdBy, assigneeIds = [], primaryAssigneeId = null, startDate, dueDate, priority, status }) {
    if (isMongooseConnected()) {
      const newTask = await Task.create({
        title,
        description,
        createdBy,
        assigneeIds,
        primaryAssigneeId,
        startDate,
        dueDate,
        priority: priority || 'medium',
        status: status || 'todo',
      });
      return await this.getTaskById(newTask._id);
    }
    const tasks = readTasks();
    const newTask = {
      _id: new mongoose.Types.ObjectId().toString(),
      title,
      description: description || '',
      createdBy: String(createdBy),
      assigneeIds: Array.isArray(assigneeIds) ? assigneeIds.map(String) : [],
      primaryAssigneeId: primaryAssigneeId ? String(primaryAssigneeId) : null,
      startDate: startDate || null,
      dueDate: dueDate || null,
      priority: priority || 'medium',
      status: status || 'todo',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };
    tasks.push(newTask);
    writeTasks(tasks);
    return await populateTask(newTask);
  },

  // 4. Cập nhật công việc
  async updateTask(taskId, updates) {
    const idStr = String(taskId);
    if (isMongooseConnected()) {
      await Task.findByIdAndUpdate(idStr, updates, { new: true, runValidators: true });
      return await this.getTaskById(idStr);
    }
    const tasks = readTasks();
    const idx = tasks.findIndex((t) => String(t._id) === idStr);
    if (idx === -1) return null;
    Object.assign(tasks[idx], updates, { updatedAt: new Date().toISOString() });
    writeTasks(tasks);
    return await populateTask(tasks[idx]);
  },

  // 5. Cập nhật trạng thái công việc
  async updateStatus(taskId, status) {
    return await this.updateTask(taskId, { status });
  },

  // 6. Xóa công việc
  async deleteTask(taskId) {
    const idStr = String(taskId);
    if (isMongooseConnected()) {
      await Task.findByIdAndDelete(idStr);
      await TaskShare.deleteMany({ taskId: idStr });
      return true;
    }
    let tasks = readTasks();
    tasks = tasks.filter((t) => String(t._id) !== idStr);
    writeTasks(tasks);

    let shares = readShares();
    shares = shares.filter((s) => String(s.taskId) !== idStr);
    writeShares(shares);
    return true;
  },

  // 7. Giao việc cho một hoặc nhiều người & chỉ định người phụ trách chính
  async assignTask(taskId, { assigneeIds = [], primaryAssigneeId = null }) {
    const updates = {
      assigneeIds: assigneeIds.map(String),
      primaryAssigneeId: primaryAssigneeId ? String(primaryAssigneeId) : null,
    };
    return await this.updateTask(taskId, updates);
  },

  // 8. Chia sẻ công việc
  async shareTask(taskId, { userId, permission = 'viewer', sharedBy }) {
    const taskIdStr = String(taskId);
    const userIdStr = String(userId);
    if (isMongooseConnected()) {
      const share = await TaskShare.findOneAndUpdate(
        { taskId: taskIdStr, userId: userIdStr },
        { permission, sharedBy },
        { upsert: true, new: true, setDefaultsOnInsert: true }
      ).populate('userId', 'fullName email');
      return share;
    }
    const shares = readShares();
    const idx = shares.findIndex((s) => String(s.taskId) === taskIdStr && String(s.userId) === userIdStr);
    let shareRecord;
    if (idx >= 0) {
      shares[idx].permission = permission;
      shares[idx].sharedBy = String(sharedBy);
      shareRecord = shares[idx];
    } else {
      shareRecord = {
        _id: new mongoose.Types.ObjectId().toString(),
        taskId: taskIdStr,
        userId: userIdStr,
        permission,
        sharedBy: String(sharedBy),
        createdAt: new Date().toISOString(),
      };
      shares.push(shareRecord);
    }
    writeShares(shares);
    const user = await userStore.findById(userIdStr);
    return {
      ...shareRecord,
      userId: user ? { _id: user._id, fullName: user.fullName, email: user.email } : { _id: userIdStr },
    };
  },

  // 9. Thu hồi quyền chia sẻ
  async revokeShare(taskId, userId) {
    const taskIdStr = String(taskId);
    const userIdStr = String(userId);
    if (isMongooseConnected()) {
      await TaskShare.findOneAndDelete({ taskId: taskIdStr, userId: userIdStr });
      return true;
    }
    let shares = readShares();
    shares = shares.filter((s) => !(String(s.taskId) === taskIdStr && String(s.userId) === userIdStr));
    writeShares(shares);
    return true;
  },

  // 10. Lấy danh sách chia sẻ của 1 công việc
  async getTaskShares(taskId) {
    const taskIdStr = String(taskId);
    if (isMongooseConnected()) {
      return await TaskShare.find({ taskId: taskIdStr })
        .populate('userId', 'fullName email')
        .populate('sharedBy', 'fullName email');
    }
    const shares = readShares().filter((s) => String(s.taskId) === taskIdStr);
    const populated = [];
    for (const s of shares) {
      const u = await userStore.findById(s.userId);
      const sb = await userStore.findById(s.sharedBy);
      populated.push({
        ...s,
        userId: u ? { _id: u._id, fullName: u.fullName, email: u.email } : { _id: s.userId },
        sharedBy: sb ? { _id: sb._id, fullName: sb.fullName, email: sb.email } : { _id: s.sharedBy },
      });
    }
    return populated;
  },

  // 11. Kiểm tra quyền của 1 user trên 1 task
  async checkPermission(taskId, userId) {
    const taskIdStr = String(taskId);
    const userIdStr = String(userId);

    const task = await this.getTaskById(taskIdStr);
    if (!task) return null;

    const ownerId = String(task.createdBy?._id || task.createdBy);
    if (ownerId === userIdStr) return 'owner';

    // Kiểm tra share (viewer / editor)
    if (isMongooseConnected()) {
      const share = await TaskShare.findOne({ taskId: taskIdStr, userId: userIdStr });
      if (share) return share.permission;
    } else {
      const shares = readShares();
      const s = shares.find((sh) => String(sh.taskId) === taskIdStr && String(sh.userId) === userIdStr);
      if (s) return s.permission;
    }

    // Kiểm tra assignee
    const isAssignee = Array.isArray(task.assigneeIds) &&
      task.assigneeIds.some((a) => String(a?._id || a) === userIdStr);
    if (isAssignee) return 'assignee';

    return null;
  },
};
