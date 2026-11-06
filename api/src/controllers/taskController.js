const taskStore = require('../services/taskStore');

// 1. Lấy danh sách công việc của người dùng
exports.getTasks = async (req, res) => {
  try {
    const userId = req.user._id;
    const { type, status, priority, search, sortBy } = req.query;

    const tasks = await taskStore.getTasks({
      userId,
      type: type || 'all',
      status,
      priority,
      search,
      sortBy: sortBy || 'createdAt',
    });

    return res.status(200).json({
      success: true,
      count: tasks.length,
      data: tasks,
    });
  } catch (error) {
    console.error('Lỗi lấy danh sách công việc:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi server khi lấy danh sách công việc: ' + error.message,
    });
  }
};

// 2. Lấy chi tiết 1 công việc
exports.getTaskById = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({
        success: false,
        message: 'Không tìm thấy công việc này',
      });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền truy cập vào công việc này',
      });
    }

    return res.status(200).json({
      success: true,
      permission,
      data: task,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy chi tiết công việc: ' + error.message,
    });
  }
};

// 3. Tạo công việc mới
exports.createTask = async (req, res) => {
  try {
    const { title, description, startDate, dueDate, priority, status } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({
        success: false,
        message: 'Tên công việc không được để trống',
      });
    }

    const newTask = await taskStore.createTask({
      title: title.trim(),
      description: description ? description.trim() : '',
      createdBy: req.user._id,
      startDate: startDate || null,
      dueDate: dueDate || null,
      priority: priority || 'medium',
      status: status || 'todo',
    });

    return res.status(201).json({
      success: true,
      message: 'Tạo công việc mới thành công',
      data: newTask,
    });
  } catch (error) {
    console.error('Lỗi tạo công việc:', error);
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi tạo công việc: ' + error.message,
    });
  }
};
