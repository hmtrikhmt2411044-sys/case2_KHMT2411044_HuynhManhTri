const mongoose = require('mongoose');

const taskActivitySchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: [true, 'Mã công việc là bắt buộc'],
      index: true,
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Người thực hiện là bắt buộc'],
    },
    action: {
      type: String,
      enum: ['created', 'updated', 'assigned', 'shared', 'status_changed', 'share_revoked', 'deleted'],
      required: [true, 'Hành động là bắt buộc'],
    },
    details: {
      type: mongoose.Schema.Types.Mixed,
      default: {},
    },
  },
  {
    timestamps: true,
  }
);

taskActivitySchema.index({ taskId: 1, createdAt: -1 });

const TaskActivity = mongoose.model('TaskActivity', taskActivitySchema);

module.exports = TaskActivity;
