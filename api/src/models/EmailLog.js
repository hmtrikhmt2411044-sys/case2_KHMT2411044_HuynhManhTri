const mongoose = require('mongoose');

const emailLogSchema = new mongoose.Schema(
  {
    taskId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'Task',
      default: null,
      index: true,
    },
    recipientEmail: {
      type: String,
      required: [true, 'Email người nhận là bắt buộc'],
      trim: true,
      lowercase: true,
      index: true,
    },
    eventType: {
      type: String,
      required: [true, 'Sự kiện kích hoạt email là bắt buộc'],
      enum: ['assigned', 'shared', 'status_changed', 'deadline_approaching', 'completed', 'updated', 'general'],
    },
    subject: {
      type: String,
      required: [true, 'Tiêu đề email là bắt buộc'],
      trim: true,
    },
    contentPreview: {
      type: String,
      default: '',
    },
    status: {
      type: String,
      enum: ['pending', 'sent', 'failed'],
      default: 'pending',
      index: true,
    },
    attempts: {
      type: Number,
      default: 1,
    },
    errorMessage: {
      type: String,
      default: null,
    },
    sentAt: {
      type: Date,
      default: null,
    },
  },
  {
    timestamps: true,
  }
);

emailLogSchema.index({ taskId: 1, createdAt: -1 });

const EmailLog = mongoose.model('EmailLog', emailLogSchema);

module.exports = EmailLog;
