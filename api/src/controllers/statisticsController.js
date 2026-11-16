const taskStore = require('../services/taskStore');

// 1. Thống kê theo trạng thái công việc
exports.getTaskStatistics = async (req, res) => {
  try {
    const userId = req.user._id;
    const tasks = await taskStore.getTasks({ userId, type: 'all' });

    const total = tasks.length;
    const todo = tasks.filter((t) => t.status === 'todo').length;
    const inProgress = tasks.filter((t) => t.status === 'in_progress').length;
    const completed = tasks.filter((t) => t.status === 'completed').length;
    const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;

    return res.status(200).json({
      success: true,
      data: {
        total,
        todo,
        inProgress,
        completed,
        completionRate,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi thống kê trạng thái công việc: ' + error.message,
    });
  }
};

// Helper tính số liệu phân công vai trò
const computeAssignmentStats = (tasks, userId) => {
  const uid = String(userId);
  const createdCount = tasks.filter((t) => String(t.createdBy?._id || t.createdBy) === uid).length;
  const assignedCount = tasks.filter((t) => {
    const list = Array.isArray(t.assigneeIds) ? t.assigneeIds : t.assignees;
    return Array.isArray(list) && list.some((a) => String(a._id || a.id || a) === uid);
  }).length;
  const primaryCount = tasks.filter((t) => {
    const pId = String(t.primaryAssignee?._id || t.primaryAssignee?.id || t.primaryAssigneeId?._id || t.primaryAssigneeId || '');
    return pId === uid;
  }).length;
  return { createdCount, assignedCount, primaryCount };
};

// 2. Thống kê theo phân công vai trò
exports.getAssignmentStatistics = async (req, res) => {
  try {
    const userId = String(req.user._id);
    const tasks = await taskStore.getTasks({ userId, type: 'all' });

    return res.status(200).json({
      success: true,
      data: computeAssignmentStats(tasks, userId),
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi thống kê phân công: ' + error.message,
    });
  }
};

// 3. Thống kê theo thời hạn (sắp đến hạn trong 48h, quá hạn)
exports.getDeadlineStatistics = async (req, res) => {
  try {
    const userId = req.user._id;
    const tasks = await taskStore.getTasks({ userId, type: 'all' });
    const now = new Date();
    const in48h = new Date(now.getTime() + 48 * 60 * 60 * 1000);

    let overdueCount = 0;
    let dueSoonCount = 0;
    let onTimeCount = 0;

    tasks.forEach((t) => {
      if (!t.dueDate) return;
      const due = new Date(t.dueDate);
      if (t.status !== 'completed' && due < now) {
        overdueCount++;
      } else if (t.status !== 'completed' && due >= now && due <= in48h) {
        dueSoonCount++;
      } else {
        onTimeCount++;
      }
    });

    return res.status(200).json({
      success: true,
      data: {
        overdueCount,
        dueSoonCount,
        onTimeCount,
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi thống kê thời hạn: ' + error.message,
    });
  }
};

// 4. Tổng quan tất cả các chỉ số (Dashboard Overview)
exports.getOverview = async (req, res) => {
  try {
    const userId = String(req.user._id);
    const tasks = await taskStore.getTasks({ userId, type: 'all' });
    const now = new Date();
    const in48h = new Date(now.getTime() + 48 * 60 * 60 * 1000);

    const total = tasks.length;
    const todo = tasks.filter((t) => t.status === 'todo').length;
    const inProgress = tasks.filter((t) => t.status === 'in_progress').length;
    const completed = tasks.filter((t) => t.status === 'completed').length;
    const completionRate = total > 0 ? Math.round((completed / total) * 100) : 0;

    const assignmentStats = computeAssignmentStats(tasks, userId);

    let overdueCount = 0;
    let dueSoonCount = 0;

    tasks.forEach((t) => {
      if (!t.dueDate) return;
      const due = new Date(t.dueDate);
      if (t.status !== 'completed' && due < now) {
        overdueCount++;
      } else if (t.status !== 'completed' && due >= now && due <= in48h) {
        dueSoonCount++;
      }
    });

    return res.status(200).json({
      success: true,
      data: {
        statusStats: {
          total,
          todo,
          inProgress,
          completed,
          completionRate,
        },
        assignmentStats,
        deadlineStats: {
          overdueCount,
          dueSoonCount,
        },
      },
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy dữ liệu tổng quan thống kê: ' + error.message,
    });
  }
};
