import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../profile/profile_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';
import '../notifications/notification_screen.dart';
import '../statistics/statistics_screen.dart';
import '../../services/notification_service.dart';

class TaskListScreen extends StatefulWidget {
  const TaskListScreen({super.key});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  User? _currentUser;
  List<TaskModel> _tasks = [];
  bool _isLoading = true;

  // Filters
  String _selectedType = 'all'; // 'all', 'my_tasks', 'assigned', 'shared'
  String? _selectedStatus; // null, 'todo', 'in_progress', 'completed'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotificationsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadUserAndTasks();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserAndTasks() async {
    setState(() => _isLoading = true);
    final user = await AuthService.getLocalUser() ?? await AuthService.getProfile();
    _currentUser = user;
    _loadUnreadNotifications();
    await _fetchTasks();
  }

  
  Future<void> _loadUnreadNotifications() async {
    final count = await NotificationService.getUnreadCount();
    if (mounted) {
      setState(() {
        _unreadNotificationsCount = count;
      });
    }
  }

  Future<void> _fetchTasks() async {
    final tasks = await TaskService.getTasks(
      type: _selectedType,
      status: _selectedStatus,
      search: _searchQuery,
    );

    if (mounted) {
      setState(() {
        _tasks = tasks;
        _isLoading = false;
        _loadUnreadNotifications();
      });
    }
  }

  Future<void> _toggleTaskStatus(TaskModel task) async {
    final newStatus = task.status == 'completed' ? 'todo' : 'completed';
    final success = await TaskService.updateStatus(task.id, newStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'completed' ? 'Đã hoàn thành công việc!' : 'Đã chuyển về Cần làm'),
          backgroundColor: newStatus == 'completed' ? const Color(0xFF10B981) : const Color(0xFF64748B),
          duration: const Duration(seconds: 1),
        ),
      );
      _fetchTasks();
    }
  }

  @override
  Widget build(BuildContext context) {
    final todoCount = _tasks.where((t) => t.status == 'todo').length;
    final inProgressCount = _tasks.where((t) => t.status == 'in_progress').length;
    final completedCount = _tasks.where((t) => t.status == 'completed').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: Row(
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadUserAndTasks());
              },
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2563EB),
                child: Text(
                  _currentUser?.fullName.isNotEmpty == true
                      ? _currentUser!.fullName[0].toUpperCase()
                      : 'U',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Chào, ${_currentUser?.fullName ?? "Bạn"} 👋',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF0F172A)),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text(
                    'Quản lý công việc và tiến độ nhóm',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Thống kê & Báo cáo',
            icon: const Icon(Icons.insights_rounded, color: Color(0xFF2563EB)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StatisticsScreen()),
              );
            },
          ),

          IconButton(
            tooltip: 'Thông báo',
            icon: Badge(
              isLabelVisible: _unreadNotificationsCount > 0,
              label: Text(
                _unreadNotificationsCount > 99 ? '99+' : _unreadNotificationsCount.toString(),
                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
              ),
              backgroundColor: const Color(0xFFEF4444),
              child: const Icon(Icons.notifications_outlined, color: Color(0xFF475569)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationScreen()),
              ).then((_) {
                _loadUnreadNotifications();
                _fetchTasks();
              });
            },
          ),

          IconButton(
            tooltip: 'Hồ sơ cá nhân',
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF475569)),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProfileScreen()),
              ).then((_) => _loadUserAndTasks());
            },
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF2563EB),
        onRefresh: _fetchTasks,
        child: Column(
          children: [
            // Thanh tìm kiếm và bộ lọc nhanh
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                children: [
                  // Search input
                  TextField(
                    controller: _searchController,
                    onChanged: (val) {
                      _searchQuery = val;
                      _fetchTasks();
                    },
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm công việc theo tiêu đề...',
                      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                      prefixIcon: const Icon(Icons.search, size: 20, color: Color(0xFF64748B)),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18, color: Color(0xFF94A3B8)),
                              onPressed: () {
                                _searchController.clear();
                                _searchQuery = '';
                                _fetchTasks();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF1F5F9),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Scope Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildScopeFilterChip('all', 'Tất cả'),
                        const SizedBox(width: 8),
                        _buildScopeFilterChip('my_tasks', 'Của tôi'),
                        const SizedBox(width: 8),
                        _buildScopeFilterChip('assigned', 'Được giao'),
                        const SizedBox(width: 8),
                        _buildScopeFilterChip('shared', 'Được chia sẻ'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Summary Metrics Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  _buildMetricPill('Cần làm', todoCount, const Color(0xFF64748B), 'todo'),
                  const SizedBox(width: 8),
                  _buildMetricPill('Đang làm', inProgressCount, const Color(0xFF2563EB), 'in_progress'),
                  const SizedBox(width: 8),
                  _buildMetricPill('Hoàn thành', completedCount, const Color(0xFF10B981), 'completed'),
                ],
              ),
            ),

            // Danh sách công việc
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Color(0xFF2563EB)))
                  : _tasks.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                          itemCount: _tasks.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final task = _tasks[index];
                            return _buildTaskCard(task);
                          },
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2563EB),
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('Thêm việc', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
          );
          if (res == true) _fetchTasks();
        },
      ),
    );
  }

  Widget _buildScopeFilterChip(String typeKey, String label) {
    final isSelected = _selectedType == typeKey;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedType = typeKey);
        _fetchTasks();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2563EB) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF475569),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildMetricPill(String label, int count, Color color, String statusKey) {
    final isSelected = _selectedStatus == statusKey;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedStatus = isSelected ? null : statusKey;
          });
          _fetchTasks();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? color : const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskCard(TaskModel task) {
    final isDone = task.status == 'completed';

    Color priorityBg;
    Color priorityFg;
    switch (task.priority) {
      case 'high':
        priorityBg = const Color(0xFFFEE2E2);
        priorityFg = const Color(0xFFDC2626);
        break;
      case 'low':
        priorityBg = const Color(0xFFD1FAE5);
        priorityFg = const Color(0xFF059669);
        break;
      case 'medium':
      default:
        priorityBg = const Color(0xFFFEF3C7);
        priorityFg = const Color(0xFFD97706);
        break;
    }

    return GestureDetector(
      onTap: () async {
        final res = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TaskDetailScreen(taskId: task.id)),
        );
        if (res == true) _fetchTasks();
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDone ? const Color(0xFFE2E8F0) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Priority badge + Due date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: priorityBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.priorityLabel,
                    style: TextStyle(color: priorityFg, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
                if (task.dueDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 13,
                        color: task.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${task.dueDate!.day}/${task.dueDate!.month}/${task.dueDate!.year}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: task.isOverdue ? FontWeight.bold : FontWeight.normal,
                          color: task.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Middle row: Checkbox + Title
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => _toggleTaskStatus(task),
                  child: Container(
                    width: 22,
                    height: 22,
                    margin: const EdgeInsets.only(top: 2, right: 10),
                    decoration: BoxDecoration(
                      color: isDone ? const Color(0xFF10B981) : Colors.transparent,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isDone ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                        width: 1.5,
                      ),
                    ),
                    child: isDone
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isDone ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                          decoration: isDone ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      if (task.description.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.4),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Bottom row: Status badge + Assignees
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    task.statusLabel,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                  ),
                ),
                if (task.assignees.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.people_outline, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 4),
                      Text(
                        task.primaryAssignee != null
                            ? task.primaryAssignee!.fullName
                            : '${task.assignees.length} người',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF6FF),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.assignment_outlined, size: 36, color: Color(0xFF2563EB)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa có công việc nào',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Bắt đầu tổ chức công việc của bạn bằng cách thêm công việc mới.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: () async {
                final res = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TaskCreateScreen()),
                );
                if (res == true) _fetchTasks();
              },
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Thêm công việc đầu tiên'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
