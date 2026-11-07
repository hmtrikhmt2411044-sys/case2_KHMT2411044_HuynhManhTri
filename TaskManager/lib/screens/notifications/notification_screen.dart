import 'package:flutter/material.dart';
import '../../models/app_notification.dart';
import '../../services/notification_service.dart';
import '../tasks/task_detail_screen.dart';

class NotificationScreen extends StatefulWidget {
  const NotificationScreen({super.key});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  List<AppNotification> _notifications = [];
  bool _isLoading = true;
  String _selectedFilter = 'all'; // 'all' hoặc 'unread'
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() => _isLoading = true);
    final isReadFilter = _selectedFilter == 'unread' ? false : null;
    final results = await NotificationService.getNotifications(isRead: isReadFilter);
    final count = await NotificationService.getUnreadCount();

    if (mounted) {
      setState(() {
        _notifications = results;
        _unreadCount = count;
        _isLoading = false;
      });
    }
  }

  Future<void> _handleMarkAllAsRead() async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await NotificationService.markAllAsRead();
    if (!mounted) return;
    if (success) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Đã đánh dấu tất cả thông báo là đã đọc'),
          backgroundColor: Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _fetchNotifications();
    }
  }

  Future<void> _handleTapNotification(AppNotification notif) async {
    // Đánh dấu đã đọc nếu chưa đọc
    if (!notif.isRead) {
      await NotificationService.markAsRead(notif.id);
      if (mounted) {
        setState(() {
          notif.isRead = true;
          if (_unreadCount > 0) _unreadCount--;
        });
      }
    }

    // Nếu có gắn với công việc, điều hướng sang TaskDetailScreen
    if (notif.taskId != null && notif.taskId!.isNotEmpty && mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TaskDetailScreen(taskId: notif.taskId!),
        ),
      ).then((_) {
        if (mounted) _fetchNotifications();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Thông báo',
              style: TextStyle(
                color: Color(0xFF0F172A),
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              'Theo dõi cập nhật và phân công công việc',
              style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          if (_unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: TextButton.icon(
                onPressed: _handleMarkAllAsRead,
                icon: const Icon(Icons.done_all_rounded, size: 18, color: Color(0xFF2563EB)),
                label: const Text(
                  'Đọc tất cả',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2563EB),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchNotifications,
        color: const Color(0xFF2563EB),
        child: Column(
          children: [
            // Thanh chuyển đổi bộ lọc
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildFilterTab('all', 'Tất cả (${_notifications.length})'),
                  const SizedBox(width: 8),
                  _buildFilterTab('unread', 'Chưa đọc', badgeCount: _unreadCount),
                ],
              ),
            ),
            const Divider(height: 1, color: Color(0xFFE2E8F0)),

            // Danh sách thông báo
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _notifications.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          itemCount: _notifications.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final notif = _notifications[index];
                            return _buildNotificationCard(notif);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterTab(String key, String title, {int badgeCount = 0}) {
    final isSelected = _selectedFilter == key;
    return InkWell(
      onTap: () {
        if (_selectedFilter != key) {
          setState(() {
            _selectedFilter = key;
          });
          _fetchNotifications();
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.transparent,
            width: 1.2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? const Color(0xFF2563EB) : const Color(0xFF64748B),
              ),
            ),
            if (badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(AppNotification notif) {
    return Container(
      decoration: BoxDecoration(
        color: notif.isRead ? Colors.white : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notif.isRead ? const Color(0xFFE2E8F0) : const Color(0xFFBFDBFE),
          width: notif.isRead ? 1 : 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: notif.isRead ? 0.015 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _handleTapNotification(notif),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon loại thông báo
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: notif.typeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(notif.typeIcon, color: notif.typeColor, size: 22),
                ),
                const SizedBox(width: 14),

                // Nội dung thông báo
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: notif.typeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              notif.typeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: notif.typeColor,
                              ),
                            ),
                          ),
                          Text(
                            notif.timeAgo,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        notif.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: notif.isRead ? FontWeight.w600 : FontWeight.w700,
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notif.message,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.35,
                        ),
                      ),
                      if (notif.taskId != null && notif.taskId!.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        const Row(
                          children: [
                            Text(
                              'Nhấn để xem chi tiết công việc',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                            SizedBox(width: 4),
                            Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF2563EB)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),

                // Chấm tròn báo chưa đọc
                if (!notif.isRead) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2563EB),
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 36,
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Không có thông báo nào',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Các hoạt động giao việc, chia sẻ và cập nhật\nsẽ được hiển thị tại đây.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
          ),
        ],
      ),
    );
  }
}
