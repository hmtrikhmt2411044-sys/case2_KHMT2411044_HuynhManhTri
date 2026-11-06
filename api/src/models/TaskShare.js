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
    },
    sharedBy: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'Người thực hiện chia sẻ là bắt buộc'],
    },
  },
  {
    timestamps: true,
  }
);

// Tránh tạo trùng lặp bản ghi chia sẻ cho cùng 1 cặp (taskId, userId)
taskShareSchema.index({ taskId: 1, userId: 1 }, { unique: true });

const TaskShare = mongoose.model('TaskShare', taskShareSchema);

module.exports = TaskShare;
