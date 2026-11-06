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

// 4. Cập nhật thông tin công việc
exports.updateTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;
    const { title, description, startDate, dueDate, priority, status } = req.body;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (permission !== 'owner' && permission !== 'editor' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền chỉnh sửa công việc này',
      });
    }

    const updates = {};
    if (title && title.trim()) updates.title = title.trim();
    if (description !== undefined) updates.description = description.trim();
    if (startDate !== undefined) updates.startDate = startDate;
    if (dueDate !== undefined) updates.dueDate = dueDate;
    if (priority) updates.priority = priority;
    if (status) updates.status = status;

    const updated = await taskStore.updateTask(id, updates);

    return res.status(200).json({
      success: true,
      message: 'Cập nhật công việc thành công',
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi cập nhật công việc: ' + error.message,
    });
  }
};

// 5. Cập nhật nhanh trạng thái công việc (todo -> in_progress -> completed)
exports.updateStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    const userId = req.user._id;

    if (!['todo', 'in_progress', 'completed'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Trạng thái không hợp lệ (chỉ chấp nhận: todo, in_progress, completed)',
      });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền thay đổi trạng thái công việc này',
      });
    }

    const updated = await taskStore.updateStatus(id, status);

    return res.status(200).json({
      success: true,
      message: 'Cập nhật trạng thái công việc thành công',
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi cập nhật trạng thái: ' + error.message,
    });
  }
};

// 6. Xóa công việc
exports.deleteTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (permission !== 'owner' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo (owner) mới có quyền xóa công việc này',
      });
    }

    await taskStore.deleteTask(id);

    return res.status(200).json({
      success: true,
      message: 'Xóa công việc thành công',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi xóa công việc: ' + error.message,
    });
  }
};
