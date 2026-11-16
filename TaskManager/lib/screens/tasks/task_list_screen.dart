import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/user.dart';
import '../../services/api_client.dart';
import '../../services/auth_service.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';
import '../profile/profile_screen.dart';
import 'task_create_screen.dart';
import 'task_detail_screen.dart';
import '../notifications/notification_screen.dart';
import '../../services/notification_service.dart';

class TaskListScreen extends StatefulWidget {
  final bool isTab;
  final ValueChanged<int>? onSwitchTab;

  const TaskListScreen({
    super.key,
    this.isTab = false,
    this.onSwitchTab,
  });

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  User? _currentUser;
  List<TaskModel> _allTasks = [];
  bool _isLoading = true;

  // Filters
  String _selectedType = 'all'; // 'all', 'my_tasks', 'assigned', 'shared'
  String? _selectedStatus; // null, 'todo', 'in_progress', 'completed'
  String? _selectedPriority; // null, 'low', 'medium', 'high'
  String? _selectedAssigneeId;
  String? _selectedAssigneeName;
  String _sortBy = 'createdAt'; // 'createdAt', 'dueDate', 'priority'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _unreadNotificationsCount = 0;
  bool _hasConnectionError = false;

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
    setState(() {
      _isLoading = true;
      _hasConnectionError = false;
    });
    try {
      final user = await AuthService.getLocalUser() ?? await AuthService.getProfile();
      if (mounted) setState(() => _currentUser = user);
      await _loadUnreadNotifications();
      await _fetchTasks();
    } on UnauthorizedException {
      // ApiClient tự động chuyển về màn hình đăng nhập
    } catch (_) {
      if (mounted) setState(() => _hasConnectionError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
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
    try {
      final tasks = await TaskService.getTasks(
        type: _selectedType,
        priority: _selectedPriority,
        assigneeId: _selectedAssigneeId,
        search: _searchQuery,
        sortBy: _sortBy,
      );

      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _hasConnectionError = false;
          _loadUnreadNotifications();
        });
      }
    } on UnauthorizedException {
      // ApiClient tự động chuyển về màn hình đăng nhập
    } catch (_) {
      if (mounted) setState(() => _hasConnectionError = true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _changeTaskStatus(TaskModel task, String newStatus) async {
    if (task.status == newStatus) return;
    try {
      final result = await TaskService.updateStatusWithResult(task.id, newStatus);
      if (!mounted) return;
      if (result['success'] == true) {
        final label = newStatus == 'completed'
            ? 'Hoàn thành'
            : newStatus == 'in_progress'
                ? 'Đang làm'
                : 'Cần làm';
        final color = newStatus == 'completed'
            ? const Color(0xFF10B981)
            : newStatus == 'in_progress'
                ? const Color(0xFF2563EB)
                : const Color(0xFF64748B);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Đã chuyển sang "$label"!'),
            backgroundColor: color,
            duration: const Duration(seconds: 1),
          ),
        );
        _fetchTasks();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Không thể cập nhật trạng thái'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } on UnauthorizedException {
      // Đã xử lý chuyển về màn hình đăng nhập
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi kết nối: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  Future<void> _toggleTaskStatus(TaskModel task) async {
    final newStatus = task.status == 'completed' ? 'todo' : 'completed';
    await _changeTaskStatus(task, newStatus);
  }

  @override
  Widget build(BuildContext context) {
    final todoCount = _allTasks.where((t) => t.status == 'todo').length;
    final inProgressCount = _allTasks.where((t) => t.status == 'in_progress').length;
    final completedCount = _allTasks.where((t) => t.status == 'completed').length;

    final displayedTasks = _selectedStatus == null
        ? _allTasks
        : _allTasks.where((t) => t.status == _selectedStatus).toList();

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
                if (widget.onSwitchTab != null) {
                  widget.onSwitchTab!(2);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  ).then((_) => _loadUserAndTasks());
                }
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
              if (widget.onSwitchTab != null) {
                widget.onSwitchTab!(2);
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProfileScreen()),
                ).then((_) => _loadUserAndTasks());
              }
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
                  // Search input + Nút Lọc & Sắp xếp
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
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
                      ),
                      const SizedBox(width: 8),
                      _buildFilterSortButton(),
                    ],
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
                  if (_hasActiveFilters) ...[
                    const SizedBox(height: 8),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (_sortBy != 'createdAt')
                            _buildActiveFilterChip(
                              'Sắp xếp: ${_sortBy == 'dueDate' ? 'Hạn hoàn thành' : 'Ưu tiên'}',
                              () {
                                setState(() => _sortBy = 'createdAt');
                                _fetchTasks();
                              },
                            ),
                          if (_selectedPriority != null)
                            _buildActiveFilterChip(
                              'Ưu tiên: ${_selectedPriority == 'high' ? 'Cao' : _selectedPriority == 'low' ? 'Thấp' : 'Trung bình'}',
                              () {
                                setState(() => _selectedPriority = null);
                                _fetchTasks();
                              },
                            ),
                          if (_selectedAssigneeId != null)
                            _buildActiveFilterChip(
                              'Phụ trách: ${_selectedAssigneeName ?? 'Đã chọn'}',
                              () {
                                setState(() {
                                  _selectedAssigneeId = null;
                                  _selectedAssigneeName = null;
                                });
                                _fetchTasks();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
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
                  : _hasConnectionError && _allTasks.isEmpty
                      ? _buildConnectionErrorState()
                      : displayedTasks.isEmpty
                          ? _buildEmptyState(filterStatus: _selectedStatus)
                      : ListView.separated(
                          padding: const EdgeInsets.only(left: 16, right: 16, bottom: 80, top: 4),
                          itemCount: displayedTasks.length,
                          separatorBuilder: (_, index) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final task = displayedTasks[index];
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

            // Bottom row: Quick 3-status switcher + Assignees
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildCardStatusMenu(task),
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

  bool get _hasActiveFilters =>
      _selectedPriority != null || _selectedAssigneeId != null || _sortBy != 'createdAt';

  Widget _buildActiveFilterChip(String label, VoidCallback onClear) {
    return Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFBFDBFE)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close, size: 13, color: Color(0xFF1D4ED8)),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSortButton() {
    final active = _hasActiveFilters;
    return Material(
      color: active ? const Color(0xFFEFF6FF) : const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _openFilterSortSheet,
        child: Container(
          height: 44,
          width: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: active ? Border.all(color: const Color(0xFF2563EB)) : null,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                Icons.tune_rounded,
                size: 20,
                color: active ? const Color(0xFF2563EB) : const Color(0xFF475569),
              ),
              if (active)
                const Positioned(
                  right: -3,
                  top: -3,
                  child: CircleAvatar(
                    radius: 4,
                    backgroundColor: Color(0xFF2563EB),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFilterSortSheet() async {
    List<User> members = [];
    try {
      members = await UserService.searchUsers();
    } catch (_) {}
    if (_currentUser != null && !members.any((u) => u.id == _currentUser!.id)) {
      members.insert(0, _currentUser!);
    }
    if (!mounted) return;

    String? tempPriority = _selectedPriority;
    String? tempAssigneeId = _selectedAssigneeId;
    String? tempAssigneeName = _selectedAssigneeName;
    String tempSortBy = _sortBy;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Lọc & Sắp xếp công việc',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempPriority = null;
                            tempAssigneeId = null;
                            tempAssigneeName = null;
                            tempSortBy = 'createdAt';
                          });
                        },
                        child: const Text('Đặt lại', style: TextStyle(color: Color(0xFF2563EB))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  const Text('Sắp xếp theo', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Mới nhất'),
                        selected: tempSortBy == 'createdAt',
                        onSelected: (_) => setModalState(() => tempSortBy = 'createdAt'),
                      ),
                      ChoiceChip(
                        label: const Text('Hạn hoàn thành'),
                        selected: tempSortBy == 'dueDate',
                        onSelected: (_) => setModalState(() => tempSortBy = 'dueDate'),
                      ),
                      ChoiceChip(
                        label: const Text('Mức độ ưu tiên'),
                        selected: tempSortBy == 'priority',
                        onSelected: (_) => setModalState(() => tempSortBy = 'priority'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Lọc theo mức độ ưu tiên', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Tất cả'),
                        selected: tempPriority == null,
                        onSelected: (_) => setModalState(() => tempPriority = null),
                      ),
                      ChoiceChip(
                        label: const Text('Cao'),
                        selected: tempPriority == 'high',
                        onSelected: (_) => setModalState(() => tempPriority = 'high'),
                      ),
                      ChoiceChip(
                        label: const Text('Trung bình'),
                        selected: tempPriority == 'medium',
                        onSelected: (_) => setModalState(() => tempPriority = 'medium'),
                      ),
                      ChoiceChip(
                        label: const Text('Thấp'),
                        selected: tempPriority == 'low',
                        onSelected: (_) => setModalState(() => tempPriority = 'low'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  const Text('Lọc theo người phụ trách', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF334155))),
                  const SizedBox(height: 8),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: const Text('Tất cả'),
                            selected: tempAssigneeId == null,
                            onSelected: (_) => setModalState(() {
                              tempAssigneeId = null;
                              tempAssigneeName = null;
                            }),
                          ),
                        ),
                        ...members.map(
                          (u) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(u.fullName),
                              selected: tempAssigneeId == u.id,
                              onSelected: (_) => setModalState(() {
                                tempAssigneeId = u.id;
                                tempAssigneeName = u.fullName;
                              }),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        setState(() {
                          _selectedPriority = tempPriority;
                          _selectedAssigneeId = tempAssigneeId;
                          _selectedAssigneeName = tempAssigneeName;
                          _sortBy = tempSortBy;
                        });
                        _fetchTasks();
                      },
                      child: const Text('Áp dụng', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCardStatusMenu(TaskModel task) {
    Color bg;
    Color fg;
    switch (task.status) {
      case 'in_progress':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        break;
      case 'completed':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        break;
      case 'todo':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        break;
    }

    return PopupMenuButton<String>(
      tooltip: 'Chuyển trạng thái nhanh',
      padding: EdgeInsets.zero,
      onSelected: (newStatus) => _changeTaskStatus(task, newStatus),
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'todo',
          child: Row(
            children: [
              Icon(Icons.radio_button_unchecked, size: 16, color: Color(0xFF64748B)),
              SizedBox(width: 8),
              Text('Cần làm', style: TextStyle(fontSize: 13)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'in_progress',
          child: Row(
            children: [
              Icon(Icons.timelapse_rounded, size: 16, color: Color(0xFF2563EB)),
              SizedBox(width: 8),
              Text('Đang làm', style: TextStyle(fontSize: 13, color: Color(0xFF2563EB), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'completed',
          child: Row(
            children: [
              Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF10B981)),
              SizedBox(width: 8),
              Text('Hoàn thành', style: TextStyle(fontSize: 13, color: Color(0xFF10B981), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              task.statusLabel,
              style: TextStyle(fontSize: 11, color: fg, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down, size: 14, color: fg),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFFEF2F2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.cloud_off_rounded, size: 36, color: Color(0xFFEF4444)),
            ),
            const SizedBox(height: 16),
            const Text(
              'Chưa kết nối được máy chủ Backend',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Mở Terminal và gõ lệnh:\nnpm run dev\nđể khởi động máy chủ API.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            ElevatedButton.icon(
              onPressed: _loadUserAndTasks,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Thử kết nối lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({String? filterStatus}) {
    String title = 'Chưa có công việc nào';
    String subtitle = 'Bắt đầu tổ chức công việc của bạn bằng cách thêm công việc mới.';
    if (filterStatus != null) {
      if (filterStatus == 'todo') title = 'Không có việc cần làm';
      if (filterStatus == 'in_progress') title = 'Không có việc đang làm';
      if (filterStatus == 'completed') title = 'Chưa có việc nào hoàn thành';
      subtitle = 'Chạm vào mục trạng thái khác hoặc thêm việc mới.';
    }

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
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.4),
            ),
            const SizedBox(height: 18),
            if (filterStatus != null) ...[
              OutlinedButton.icon(
                onPressed: () {
                  setState(() => _selectedStatus = null);
                },
                icon: const Icon(Icons.clear_all, size: 18),
                label: const Text('Xem tất cả công việc'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  side: const BorderSide(color: Color(0xFF2563EB)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
              const SizedBox(height: 10),
            ],
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
