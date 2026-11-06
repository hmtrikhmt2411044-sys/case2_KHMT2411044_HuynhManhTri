const taskStore = require('../services/taskStore');

// 1. Tạo công việc mới
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
