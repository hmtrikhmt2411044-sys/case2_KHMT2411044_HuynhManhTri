const fs = require('fs');
const path = require('path');
const mongoose = require('mongoose');
const Task = require('../models/Task');
const userStore = require('./userStore');

const tasksFile = path.join(__dirname, '../../data/local_tasks.json');

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

const isMongooseConnected = () => mongoose.connection.readyState === 1;

// Helper populate cho local store
const populateTask = async (task) => {
  if (!task) return null;
  const copy = { ...task };
  if (copy.createdBy) {
    const u = await userStore.findById(copy.createdBy);
    if (u) copy.createdBy = { _id: u._id, fullName: u.fullName, email: u.email };
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
      } else {
        filter.$or = [{ createdBy: userId }, { assigneeIds: userId }];
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
        .sort(sortOption);

      return tasks;
    }

    // Local fallback
    const allTasks = readTasks();
    let filtered = allTasks.filter((t) => {
      const isOwner = String(t.createdBy?._id || t.createdBy) === userIdStr;
      if (type === 'my_tasks' && !isOwner) return false;

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
      return await Task.findById(idStr).populate('createdBy', 'fullName email');
    }
    const tasks = readTasks();
    const found = tasks.find((t) => String(t._id) === idStr);
    if (!found) return null;
    return await populateTask(found);
  },

  // 3. Tạo công việc mới
  async createTask({ title, description, createdBy, startDate, dueDate, priority, status }) {
    if (isMongooseConnected()) {
      const newTask = await Task.create({
        title,
        description,
        createdBy,
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
      assigneeIds: [],
      primaryAssigneeId: null,
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
      return true;
    }
    let tasks = readTasks();
    tasks = tasks.filter((t) => String(t._id) !== idStr);
    writeTasks(tasks);
    return true;
  },

  // Kiểm tra quyền (cơ bản cho Mục B)
  async checkPermission(taskId, userId) {
    const idStr = String(taskId);
    const userIdStr = String(userId);
    const task = await this.getTaskById(idStr);
    if (!task) return null;
    const ownerId = String(task.createdBy?._id || task.createdBy);
    if (ownerId === userIdStr) return 'owner';
    return null;
  },
};
