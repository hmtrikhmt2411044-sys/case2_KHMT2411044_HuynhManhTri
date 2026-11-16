import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task.dart';

/// Hiển thị Bottom Sheet chuyển đổi trạng thái công việc theo phong cách Linear / ClickUp.
/// Phân tách rõ luồng cập nhật tiến độ thông thường và luồng mở lại (Reopen) khi công việc đã hoàn thành.
Future<String?> showTaskStatusSheet(BuildContext context, TaskModel task) {
  HapticFeedback.lightImpact();
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _TaskStatusSheet(task: task),
  );
}

/// Hiển thị SnackBar thông báo đổi trạng thái kèm nút Hoàn tác và tự ẩn sau [duration].
void showStatusChangedSnackBar(
  BuildContext context, {
  required String newStatus,
  String? taskTitle,
  VoidCallback? onUndo,
  Duration duration = const Duration(seconds: 3),
}) {
  final label = switch (newStatus) {
    'completed' => 'Hoàn thành',
    'in_progress' => 'Đang làm',
    _ => 'Cần làm',
  };
  final color = switch (newStatus) {
    'completed' => const Color(0xFF10B981),
    'in_progress' => const Color(0xFF2563EB),
    _ => const Color(0xFF475569),
  };
  final message = newStatus == 'completed'
      ? (taskTitle != null ? 'Đã hoàn thành "$taskTitle"!' : 'Đã hoàn thành công việc!')
      : 'Đã chuyển sang "$label"';

  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: duration,
      // Flutter mặc định persist = (action != null), cần ép persist: false để tự ẩn khi hết duration.
      persist: false,
      action: onUndo != null
          ? SnackBarAction(
              label: 'Hoàn tác',
              textColor: Colors.white,
              onPressed: onUndo,
            )
          : null,
    ),
  );
}

class _TaskStatusSheet extends StatelessWidget {
  final TaskModel task;

  const _TaskStatusSheet({required this.task});

  @override
  Widget build(BuildContext context) {
    final isCompleted = task.status == 'completed';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isCompleted ? const Color(0xFFD1FAE5) : const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isCompleted ? 'ĐÃ HOÀN THÀNH' : 'CẬP NHẬT TIẾN ĐỘ',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: isCompleted ? const Color(0xFF059669) : const Color(0xFF2563EB),
                      ),
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              if (isCompleted) ...[
                // Trạng thái đã hoàn thành: phân tách rõ thao tác Mở lại (Reopen)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFA7F3D0)),
                  ),
                  child: const Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: Color(0xFF10B981),
                        child: Icon(Icons.check_rounded, color: Colors.white, size: 20),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Công việc này đã hoàn tất',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF065F46),
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Nếu cần chỉnh sửa hoặc làm tiếp, bạn có thể mở lại bên dưới.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF047857), height: 1.35),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Mở lại công việc',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                ),
                const SizedBox(height: 10),
                _buildOptionCard(
                  context,
                  statusKey: 'in_progress',
                  title: 'Mở lại — Đang làm',
                  subtitle: 'Tiếp tục thực hiện và theo dõi tiến độ',
                  icon: Icons.replay_rounded,
                  color: const Color(0xFF2563EB),
                  bgTint: const Color(0xFFEFF6FF),
                  isCurrent: false,
                ),
                const SizedBox(height: 10),
                _buildOptionCard(
                  context,
                  statusKey: 'todo',
                  title: 'Đặt lại — Cần làm',
                  subtitle: 'Đưa công việc về danh sách chưa thực hiện',
                  icon: Icons.radio_button_unchecked_rounded,
                  color: const Color(0xFF64748B),
                  bgTint: const Color(0xFFF8FAFC),
                  isCurrent: false,
                ),
              ] else ...[
                _buildOptionCard(
                  context,
                  statusKey: 'todo',
                  title: 'Cần làm',
                  subtitle: 'Chưa bắt đầu thực hiện, đang chờ xử lý',
                  icon: Icons.radio_button_unchecked_rounded,
                  color: const Color(0xFF64748B),
                  bgTint: const Color(0xFFF8FAFC),
                  isCurrent: task.status == 'todo',
                ),
                const SizedBox(height: 10),
                _buildOptionCard(
                  context,
                  statusKey: 'in_progress',
                  title: 'Đang làm',
                  subtitle: 'Đang bắt tay vào thực hiện công việc này',
                  icon: Icons.timelapse_rounded,
                  color: const Color(0xFF2563EB),
                  bgTint: const Color(0xFFEFF6FF),
                  isCurrent: task.status == 'in_progress',
                ),
                const SizedBox(height: 10),
                _buildOptionCard(
                  context,
                  statusKey: 'completed',
                  title: 'Hoàn thành',
                  subtitle: 'Xác nhận công việc đã xong hoàn toàn',
                  icon: Icons.check_circle_rounded,
                  color: const Color(0xFF10B981),
                  bgTint: const Color(0xFFECFDF5),
                  isCurrent: false,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required String statusKey,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Color bgTint,
    required bool isCurrent,
  }) {
    return Material(
      color: isCurrent ? bgTint : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: isCurrent
            ? () => Navigator.pop(context)
            : () {
                HapticFeedback.selectionClick();
                Navigator.pop(context, statusKey);
              },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isCurrent ? color : const Color(0xFFE2E8F0),
              width: isCurrent ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isCurrent ? color.withValues(alpha: 0.16) : bgTint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isCurrent ? color : const Color(0xFF0F172A),
                          ),
                        ),
                        if (isCurrent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Hiện tại',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Icon(
                isCurrent ? Icons.check_rounded : Icons.chevron_right_rounded,
                size: 20,
                color: isCurrent ? color : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
