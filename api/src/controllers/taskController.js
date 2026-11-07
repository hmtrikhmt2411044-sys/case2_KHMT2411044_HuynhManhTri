const taskStore = require('../services/taskStore');
const userStore = require('../services/userStore');
const emailService = require('../services/emailService');
const notificationService = require('../services/notificationService');
const activityStore = require('../services/activityStore');

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
        message: 'Công việc không tồn tại',
      });
    }

    // Kiểm tra quyền xem
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
    const { title, description, startDate, dueDate, priority, status, assigneeIds, primaryAssigneeId } = req.body;

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
      assigneeIds: Array.isArray(assigneeIds) ? assigneeIds : [],
      primaryAssigneeId: primaryAssigneeId || null,
      startDate: startDate || null,
      dueDate: dueDate || null,
      priority: priority || 'medium',
      status: status || 'todo',
    });

    // Tự động gửi thông báo trong ứng dụng & email cho các thành viên được giao
    if (newTask.assignees && newTask.assignees.length > 0) {
      newTask.assignees.forEach(async (u) => {
        const uId = String(u._id || u.id);
        if (uId !== String(req.user._id)) {
          const isPrimary = String(newTask.primaryAssigneeId?._id || newTask.primaryAssigneeId) === uId;
          try {
            await notificationService.createNotification({
              userId: uId,
              taskId: newTask._id,
              type: 'assigned',
              title: isPrimary ? 'Bạn là người phụ trách chính ⭐' : 'Công việc mới được giao',
              message: `${req.user.fullName} vừa giao cho bạn công việc: "${newTask.title}"`,
            });
            if (u.email) {
              await emailService.sendAssignEmail({
                toEmail: u.email,
                recipientName: u.fullName,
                task: newTask,
                assignerName: req.user.fullName,
                isPrimary,
              });
            }
          } catch (notifErr) {
            console.warn('[Assign Notif Error]', notifErr.message);
          }
        }
      });
    }

    await activityStore.logActivity({ taskId: newTask._id, userId: req.user._id, action: 'created', details: { title: newTask.title } });

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
    const updates = req.body;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    // Kiểm tra quyền: Owner, Editor hoặc Admin
    const permission = await taskStore.checkPermission(id, userId);
    if (permission !== 'owner' && permission !== 'editor' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn chỉ có quyền xem (viewer), không thể chỉnh sửa công việc này',
      });
    }

    // Lọc các trường được phép cập nhật
    const allowedFields = ['title', 'description', 'startDate', 'dueDate', 'priority', 'status'];
    const filteredUpdates = {};
    for (const key of allowedFields) {
      if (updates[key] !== undefined) {
        filteredUpdates[key] = updates[key];
      }
    }

    const updated = await taskStore.updateTask(id, filteredUpdates);

    await activityStore.logActivity({ taskId: id, userId, action: 'updated', details: filteredUpdates });

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
    if (permission === 'viewer') {
      return res.status(403).json({
        success: false,
        message: 'Quyền xem (viewer) không thể đổi trạng thái công việc',
      });
    }

    const updated = await taskStore.updateStatus(id, status);

    // Gửi thông báo và email cập nhật trạng thái
    try {
      const task = updated;
      const recipients = new Set();
      const creatorId = String(task.createdBy?._id || task.createdBy);
      if (creatorId && creatorId !== String(userId)) {
        recipients.add(creatorId);
      }
      if (Array.isArray(task.assignees)) {
        task.assignees.forEach((a) => {
          const aId = String(a._id || a.id);
          if (aId !== String(userId)) recipients.add(aId);
        });
      }

      for (const rId of recipients) {
        const targetU = await userStore.findById(rId);
        if (targetU) {
          const isCompleted = status === 'completed';
          const statusText = status === 'completed' ? 'Hoàn thành' : status === 'in_progress' ? 'Đang làm' : 'Cần làm';
          await notificationService.createNotification({
            userId: rId,
            taskId: task._id,
            type: isCompleted ? 'completed' : 'status_changed',
            title: isCompleted ? 'Công việc đã hoàn thành 🎉' : 'Cập nhật trạng thái công việc',
            message: `${req.user.fullName} vừa chuyển trạng thái công việc "${task.title}" sang: ${statusText}`,
          });
          if (targetU.email) {
            await emailService.sendStatusUpdateEmail({
              toEmail: targetU.email,
              recipientName: targetU.fullName,
              task,
              updaterName: req.user.fullName,
              newStatus: status,
            });
          }
        }
      }
    } catch (notifErr) {
      console.warn('[Status Notif Error]', notifErr.message);
    }

    await activityStore.logActivity({ taskId: id, userId, action: 'status_changed', details: { status } });

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

    // Chỉ Owner hoặc Admin mới có quyền xóa
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

// 7. Giao việc cho thành viên (Assign task)
exports.assignTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;
    let { assigneeIds, primaryAssigneeId } = req.body;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    // Chỉ Owner hoặc Editor mới có quyền giao việc
    const permission = await taskStore.checkPermission(id, userId);
    if (permission !== 'owner' && permission !== 'editor' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền giao việc này cho thành viên khác',
      });
    }

    assigneeIds = Array.isArray(assigneeIds) ? assigneeIds : [];
    if (primaryAssigneeId && !assigneeIds.includes(primaryAssigneeId)) {
      assigneeIds.push(primaryAssigneeId);
    }

    const updated = await taskStore.assignTask(id, { assigneeIds, primaryAssigneeId });

    // Tự động thông báo và gửi email cho các thành viên được giao việc
    if (updated.assignees && updated.assignees.length > 0) {
      updated.assignees.forEach(async (u) => {
        const uId = String(u._id || u.id);
        if (uId !== String(req.user._id)) {
          const isPrimary = String(updated.primaryAssigneeId?._id || updated.primaryAssigneeId) === uId;
          try {
            await notificationService.createNotification({
              userId: uId,
              taskId: updated._id,
              type: 'assigned',
              title: isPrimary ? 'Bạn được đặt làm phụ trách chính ⭐' : 'Phân công công việc',
              message: `${req.user.fullName} vừa phân công bạn thực hiện công việc: "${updated.title}"`,
            });
            if (u.email) {
              await emailService.sendAssignEmail({
                toEmail: u.email,
                recipientName: u.fullName,
                task: updated,
                assignerName: req.user.fullName,
                isPrimary,
              });
            }
          } catch (notifErr) {
            console.warn('[Assign Notif Error]', notifErr.message);
          }
        }
      });
    }

    await activityStore.logActivity({ taskId: id, userId, action: 'assigned', details: { assigneesCount: assigneeIds.length, primaryAssigneeId } });

    return res.status(200).json({
      success: true,
      message: 'Cập nhật phân công việc thành công',
      data: updated,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi giao việc: ' + error.message,
    });
  }
};

// 8. Chia sẻ công việc với quyền viewer hoặc editor
exports.shareTask = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;
    const { targetUserId, permission } = req.body;

    if (!targetUserId) {
      return res.status(400).json({
        success: false,
        message: 'Vui lòng chọn người dùng cần chia sẻ',
      });
    }

    if (!['viewer', 'editor'].includes(permission)) {
      return res.status(400).json({
        success: false,
        message: 'Quyền chia sẻ không hợp lệ (chỉ chấp nhận: viewer hoặc editor)',
      });
    }

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    // Chỉ Owner mới được chia sẻ hoặc sửa quyền
    const userPermission = await taskStore.checkPermission(id, userId);
    if (userPermission !== 'owner' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo (owner) mới có quyền chia sẻ công việc này',
      });
    }

    // Không thể tự chia sẻ cho chính mình
    if (String(task.createdBy?._id || task.createdBy) === String(targetUserId)) {
      return res.status(400).json({
        success: false,
        message: 'Bạn đã là chủ sở hữu (owner) của công việc này',
      });
    }

    const share = await taskStore.shareTask(id, {
      userId: targetUserId,
      permission,
      sharedBy: userId,
    });

    // Gửi thông báo trong ứng dụng & email chia sẻ
    try {
      const targetUser = await userStore.findById(targetUserId);
      if (targetUser) {
        await notificationService.createNotification({
          userId: targetUserId,
          taskId: task._id,
          type: 'shared',
          title: `Được chia sẻ công việc (${permission === 'editor' ? 'Chỉnh sửa' : 'Chỉ xem'})`,
          message: `${req.user.fullName} vừa chia sẻ công việc "${task.title}" với bạn`,
        });
        if (targetUser.email) {
          await emailService.sendShareEmail({
            toEmail: targetUser.email,
            recipientName: targetUser.fullName,
            task,
            sharerName: req.user.fullName,
            permission,
          });
        }
      }
    } catch (notifErr) {
      console.warn('[Share Notif Error]', notifErr.message);
    }

    await activityStore.logActivity({ taskId: id, userId, action: 'shared', details: { targetUserId, permission } });

    return res.status(200).json({
      success: true,
      message: `Đã chia sẻ công việc với quyền ${permission === 'editor' ? 'chỉnh sửa (editor)' : 'xem (viewer)'}`,
      data: share,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi chia sẻ công việc: ' + error.message,
    });
  }
};

// 9. Thu hồi quyền chia sẻ
exports.revokeShare = async (req, res) => {
  try {
    const { id, targetUserId } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    // Chỉ Owner hoặc Admin mới có quyền thu hồi chia sẻ
    const userPermission = await taskStore.checkPermission(id, userId);
    if (userPermission !== 'owner' && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Chỉ người tạo (owner) mới có quyền thu hồi chia sẻ',
      });
    }

    await taskStore.revokeShare(id, targetUserId);

    await activityStore.logActivity({ taskId: id, userId, action: 'share_revoked', details: { targetUserId } });

    return res.status(200).json({
      success: true,
      message: 'Đã thu hồi quyền chia sẻ công việc',
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi thu hồi chia sẻ: ' + error.message,
    });
  }
};

// 10. Lấy danh sách chia sẻ của công việc
exports.getTaskShares = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    // User phải có quyền truy cập công việc
    const permission = await taskStore.checkPermission(id, userId);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xem thông tin chia sẻ của công việc này',
      });
    }

    const shares = await taskStore.getTaskShares(id);

    return res.status(200).json({
      success: true,
      count: shares.length,
      data: shares,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy danh sách chia sẻ: ' + error.message,
    });
  }
};


// 11. Xem lịch sử hoạt động của công việc
exports.getTaskActivities = async (req, res) => {
  try {
    const { id } = req.params;
    const userId = req.user._id;

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    const permission = await taskStore.checkPermission(id, userId);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({
        success: false,
        message: 'Bạn không có quyền xem lịch sử hoạt động của công việc này',
      });
    }

    const activities = await activityStore.getActivitiesByTaskId(id);

    return res.status(200).json({
      success: true,
      count: activities.length,
      data: activities,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: 'Lỗi khi lấy lịch sử hoạt động: ' + error.message,
    });
  }
};
