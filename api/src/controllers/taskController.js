const taskStore = require('../services/taskStore');
const userStore = require('../services/userStore');
const emailService = require('../services/emailService');
const notificationService = require('../services/notificationService');
const activityStore = require('../services/activityStore');

// Chạy tác vụ gửi email ở chế độ nền (non-blocking) để HTTP API phản hồi tức thì dưới 0.5s
const runBackgroundTask = (fn, tag = 'BackgroundTask') => {
  Promise.resolve()
    .then(fn)
    .catch((err) => console.warn(`[${tag}]`, err?.message || err));
};

// Gom tập người nhận duy nhất (loại trừ người thực hiện thao tác)
const collectOtherRecipients = (task, actorUserId) => {
  const actorId = String(actorUserId);
  const recipients = new Set();
  const creatorId = String(task.createdBy?._id || task.createdBy || '');
  if (creatorId && creatorId !== actorId) recipients.add(creatorId);
  const taskAssignees = task.assigneeIds || task.assignees || [];
  if (Array.isArray(taskAssignees)) {
    taskAssignees.forEach((a) => {
      const aId = String(a?._id || a?.id || a || '');
      if (aId && aId !== actorId) recipients.add(aId);
    });
  }
  return Array.from(recipients);
};

// Lấy danh sách user object (tái sử dụng field đã populate để bỏ qua truy vấn Atlas lặp lại)
const resolveOtherRecipientUsers = async (task, actorUserId) => {
  const actorId = String(actorUserId);
  const byId = new Map();
  const missingIds = new Set();
  const candidates = [
    task.createdBy,
    ...(Array.isArray(task.assigneeIds || task.assignees) ? task.assigneeIds || task.assignees : []),
  ];
  for (const item of candidates) {
    if (!item) continue;
    const id = String(item._id || item.id || item);
    if (!id || id === actorId || byId.has(id)) continue;
    if (typeof item === 'object' && item.email) {
      byId.set(id, item);
    } else {
      missingIds.add(id);
    }
  }
  if (missingIds.size > 0) {
    const fetched = await Promise.all(Array.from(missingIds).map((id) => userStore.findById(id)));
    fetched.filter(Boolean).forEach((u) => byId.set(String(u._id || u.id), u));
  }
  return Array.from(byId.values());
};

// 1. Lấy danh sách công việc của người dùng
exports.getTasks = async (req, res) => {
  try {
    const userId = req.user._id;
    const { type, scope, status, priority, assigneeId, search, q, sortBy, order } = req.query;

    const tasks = await taskStore.getTasks({
      userId,
      type: type || scope || 'all',
      status,
      priority,
      assigneeId,
      search: search || q,
      sortBy: sortBy || 'createdAt',
      order,
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
    const permission = await taskStore.checkPermission(id, userId, task);
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

    // Tự động gửi thông báo trong ứng dụng & gửi email ở chế độ nền cho các thành viên được giao
    const newAssignees = newTask.assigneeIds || newTask.assignees || [];
    if (Array.isArray(newAssignees) && newAssignees.length > 0) {
      const targetUsers = newAssignees.filter((u) => String(u._id || u.id) !== String(req.user._id));
      await Promise.allSettled(
        targetUsers.map((u) => {
          const uId = String(u._id || u.id);
          const isPrimary = String(newTask.primaryAssigneeId?._id || newTask.primaryAssigneeId) === uId;
          return notificationService.createNotification({
            userId: uId,
            taskId: newTask._id,
            type: 'assigned',
            title: isPrimary ? 'Bạn là người phụ trách chính ⭐' : 'Công việc mới được giao',
            message: `${req.user.fullName} vừa giao cho bạn công việc: "${newTask.title}"`,
          });
        })
      );
      targetUsers.forEach((u) => {
        if (u.email) {
          const isPrimary = String(newTask.primaryAssigneeId?._id || newTask.primaryAssigneeId) === String(u._id || u.id);
          runBackgroundTask(
            () =>
              emailService.sendAssignEmail({
                toEmail: u.email,
                recipientName: u.fullName,
                task: newTask,
                assignerName: req.user.fullName,
                isPrimary,
              }),
            'CreateAssignEmail'
          );
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
    const permission = await taskStore.checkPermission(id, userId, task);
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

    const activityPromise = activityStore.logActivity({ taskId: id, userId, action: 'updated', details: filteredUpdates });

    // Gửi thông báo & email khi hạn hoàn thành hoặc thông tin quan trọng thay đổi
    const changedLabels = [];
    if (filteredUpdates.dueDate !== undefined && String(filteredUpdates.dueDate || '') !== String(task.dueDate || '')) {
      changedLabels.push('Hạn hoàn thành');
    }
    if (filteredUpdates.priority !== undefined && filteredUpdates.priority !== task.priority) {
      changedLabels.push('Mức độ ưu tiên');
    }
    if (filteredUpdates.title !== undefined && filteredUpdates.title !== task.title) {
      changedLabels.push('Tiêu đề');
    }
    if (filteredUpdates.status !== undefined && filteredUpdates.status !== task.status) {
      changedLabels.push('Trạng thái');
    }

    if (changedLabels.length > 0 && updated) {
      try {
        const users = await resolveOtherRecipientUsers(updated, userId);
        await Promise.allSettled([
          ...users.map((targetU) =>
            notificationService.createNotification({
              userId: targetU._id,
              taskId: updated._id,
              type: 'updated',
              title: 'Công việc có thay đổi quan trọng',
              message: `${req.user.fullName} vừa cập nhật (${changedLabels.join(', ')}) công việc "${updated.title}"`,
            })
          ),
          activityPromise,
        ]);
        users.forEach((targetU) => {
          if (targetU.email) {
            runBackgroundTask(
              () =>
                emailService.sendTaskChangeEmail({
                  toEmail: targetU.email,
                  recipientName: targetU.fullName,
                  task: updated,
                  updaterName: req.user.fullName,
                  changedFields: changedLabels,
                }),
              'TaskChangeEmail'
            );
          }
        });
      } catch (notifErr) {
        console.warn('[Update Notif Error]', notifErr.message);
        await Promise.allSettled([activityPromise]);
      }
    } else {
      await Promise.allSettled([activityPromise]);
    }

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

    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }

    const permission = await taskStore.checkPermission(id, userId, task);
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
    const activityPromise = activityStore.logActivity({ taskId: id, userId, action: 'status_changed', details: { status } });

    // Gửi thông báo tức thì và gửi email cập nhật trạng thái ở chế độ nền (không làm treo request Flutter)
    if (updated) {
      try {
        const users = await resolveOtherRecipientUsers(updated, userId);
        const isCompleted = status === 'completed';
        const statusText = status === 'completed' ? 'Hoàn thành' : status === 'in_progress' ? 'Đang làm' : 'Cần làm';

        await Promise.allSettled([
          ...users.map((targetU) =>
            notificationService.createNotification({
              userId: targetU._id,
              taskId: updated._id,
              type: isCompleted ? 'completed' : 'status_changed',
              title: isCompleted ? 'Công việc đã hoàn thành 🎉' : 'Cập nhật trạng thái công việc',
              message: `${req.user.fullName} vừa chuyển trạng thái công việc "${updated.title}" sang: ${statusText}`,
            })
          ),
          activityPromise,
        ]);

        users.forEach((targetU) => {
          if (targetU.email) {
            runBackgroundTask(
              () =>
                emailService.sendStatusUpdateEmail({
                  toEmail: targetU.email,
                  recipientName: targetU.fullName,
                  task: updated,
                  updaterName: req.user.fullName,
                  newStatus: status,
                }),
              'StatusUpdateEmail'
            );
          }
        });
      } catch (notifErr) {
        console.warn('[Status Notif Error]', notifErr.message);
        await Promise.allSettled([activityPromise]);
      }
    } else {
      await Promise.allSettled([activityPromise]);
    }

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
    const permission = await taskStore.checkPermission(id, userId, task);
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
    const permission = await taskStore.checkPermission(id, userId, task);
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

    // Tự động thông báo trong app song song với ghi nhận lịch sử và gửi email ở chế độ nền
    const updatedAssignees = updated.assigneeIds || updated.assignees || [];
    const targetUsers = Array.isArray(updatedAssignees)
      ? updatedAssignees.filter((u) => String(u._id || u.id) !== String(req.user._id))
      : [];

    await Promise.allSettled([
      ...targetUsers.map((u) => {
        const uId = String(u._id || u.id);
        const isPrimary = String(updated.primaryAssigneeId?._id || updated.primaryAssigneeId) === uId;
        return notificationService.createNotification({
          userId: uId,
          taskId: updated._id,
          type: 'assigned',
          title: isPrimary ? 'Bạn được đặt làm phụ trách chính ⭐' : 'Phân công công việc',
          message: `${req.user.fullName} vừa phân công bạn thực hiện công việc: "${updated.title}"`,
        });
      }),
      activityStore.logActivity({
        taskId: id,
        userId,
        action: 'assigned',
        details: { assigneesCount: assigneeIds.length, primaryAssigneeId },
      }),
    ]);

    targetUsers.forEach((u) => {
      if (u.email) {
        const isPrimary = String(updated.primaryAssigneeId?._id || updated.primaryAssigneeId) === String(u._id || u.id);
        runBackgroundTask(
          () =>
            emailService.sendAssignEmail({
              toEmail: u.email,
              recipientName: u.fullName,
              task: updated,
              assignerName: req.user.fullName,
              isPrimary,
            }),
          'AssignEmail'
        );
      }
    });

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
    const targetUserId = req.body.targetUserId || req.body.userId;
    const { permission } = req.body;

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
    const userPermission = await taskStore.checkPermission(id, userId, task);
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

    const activityPromise = activityStore.logActivity({
      taskId: id,
      userId,
      action: 'shared',
      details: { targetUserId, permission },
    });

    // Gửi thông báo trong ứng dụng song song với ghi nhận lịch sử & gửi email ở chế độ nền
    try {
      const targetUser = share?.userId?.email ? share.userId : await userStore.findById(targetUserId);
      const tasksToAwait = [activityPromise];
      if (targetUser) {
        tasksToAwait.push(
          notificationService.createNotification({
            userId: targetUserId,
            taskId: task._id,
            type: 'shared',
            title: `Được chia sẻ công việc (${permission === 'editor' ? 'Chỉnh sửa' : 'Chỉ xem'})`,
            message: `${req.user.fullName} vừa chia sẻ công việc "${task.title}" với bạn`,
          })
        );
        if (targetUser.email) {
          runBackgroundTask(
            () =>
              emailService.sendShareEmail({
                toEmail: targetUser.email,
                recipientName: targetUser.fullName,
                task,
                sharerName: req.user.fullName,
                permission,
              }),
            'ShareEmail'
          );
        }
      }
      await Promise.allSettled(tasksToAwait);
    } catch (notifErr) {
      console.warn('[Share Notif Error]', notifErr.message);
      await Promise.allSettled([activityPromise]);
    }

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
    const userPermission = await taskStore.checkPermission(id, userId, task);
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
    const permission = await taskStore.checkPermission(id, userId, task);
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

    const permission = await taskStore.checkPermission(id, userId, task);
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

// 12. Lấy danh sách người được giao việc (GET /tasks/:id/assignees)
exports.getTaskAssignees = async (req, res) => {
  try {
    const { id } = req.params;
    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }
    const permission = await taskStore.checkPermission(id, req.user._id, task);
    if (!permission && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền truy cập công việc này' });
    }
    return res.status(200).json({
      success: true,
      data: {
        assignees: task.assigneeIds || [],
        primaryAssignee: task.primaryAssigneeId || null,
      },
    });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Lỗi lấy danh sách người được giao: ' + error.message });
  }
};

// 13. Cập nhật người phụ trách chính (PATCH /tasks/:id/assignees/:userId)
exports.setPrimaryAssignee = async (req, res) => {
  try {
    const { id, userId: targetUserId } = req.params;
    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }
    const permission = await taskStore.checkPermission(id, req.user._id, task);
    if (permission !== 'owner' && permission !== 'editor' && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền thay đổi người phụ trách chính' });
    }
    const currentAssignees = (task.assigneeIds || []).map((a) => String(a._id || a));
    if (!currentAssignees.includes(String(targetUserId))) {
      currentAssignees.push(String(targetUserId));
    }
    const updated = await taskStore.assignTask(id, {
      assigneeIds: currentAssignees,
      primaryAssigneeId: targetUserId,
    });
    return res.status(200).json({ success: true, message: 'Đã cập nhật người phụ trách chính', data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Lỗi cập nhật người phụ trách chính: ' + error.message });
  }
};

// 14. Hủy giao việc cho một người (DELETE /tasks/:id/assignees/:userId)
exports.removeAssignee = async (req, res) => {
  try {
    const { id, userId: targetUserId } = req.params;
    const task = await taskStore.getTaskById(id);
    if (!task) {
      return res.status(404).json({ success: false, message: 'Công việc không tồn tại' });
    }
    const permission = await taskStore.checkPermission(id, req.user._id, task);
    if (permission !== 'owner' && permission !== 'editor' && req.user.role !== 'admin') {
      return res.status(403).json({ success: false, message: 'Bạn không có quyền hủy giao việc' });
    }
    const remaining = (task.assigneeIds || [])
      .map((a) => String(a._id || a))
      .filter((aId) => aId !== String(targetUserId));
    const currentPrimary = task.primaryAssigneeId ? String(task.primaryAssigneeId._id || task.primaryAssigneeId) : null;
    const nextPrimary = currentPrimary === String(targetUserId) ? (remaining[0] || null) : currentPrimary;
    const updated = await taskStore.assignTask(id, {
      assigneeIds: remaining,
      primaryAssigneeId: nextPrimary,
    });
    return res.status(200).json({ success: true, message: 'Đã hủy giao việc cho thành viên', data: updated });
  } catch (error) {
    return res.status(500).json({ success: false, message: 'Lỗi hủy giao việc: ' + error.message });
  }
};

// 15. Thay đổi quyền chia sẻ (PATCH /tasks/:id/shares/:targetUserId)
exports.updateSharePermission = async (req, res) => {
  req.body = { ...req.body, targetUserId: req.params.targetUserId };
  return exports.shareTask(req, res);
};
