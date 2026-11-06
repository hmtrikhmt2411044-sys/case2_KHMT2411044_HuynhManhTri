const mongoose = require('mongoose');

const taskShareSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      required: [true, 'Mã công việc là bắt buộc'],
    },
    userId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Người được chia sẻ là bắt buộc'],
    },
    permission: {
      type: String,
      enum: ['viewer', 'editor'],
      default: 'viewer',
      required: [true, 'Quyền chia sẻ là bắt buộc (viewer hoặc editor)'],
    },
    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Người cấp quyền là bắt buộc'],
    },
  },
  {
    timestamps: { createdAt: true, updatedAt: false },
  }
);

// Tránh trùng lặp chia sẻ cho cùng 1 người trên 1 công việc
taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

const TaskShare = mongoose.model('TaskShare', taskShareSchema);

module.exports = TaskShare;
