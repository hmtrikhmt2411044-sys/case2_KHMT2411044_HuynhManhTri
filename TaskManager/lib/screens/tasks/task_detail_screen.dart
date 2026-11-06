import 'package:flutter/material.dart';
import '../../models/task.dart';
import '../../models/task_share.dart';
import '../../models/user.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';
import 'task_edit_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final String taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  TaskModel? _task;
  String _permission = 'viewer';
  List<TaskShareModel> _shares = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final detail = await TaskService.getTaskDetail(widget.taskId);
    final shares = await TaskService.getTaskShares(widget.taskId);

    if (mounted) {
      if (detail != null) {
        setState(() {
          _task = detail['task'] as TaskModel;
          _permission = detail['permission'] as String;
          _shares = shares;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_task == null) return;
    final success = await TaskService.updateStatus(_task!.id, newStatus);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã cập nhật trạng thái công việc'),
          backgroundColor: Color(0xFF10B981),
          duration: Duration(seconds: 1),
        ),
      );
      _loadData();
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Xác nhận xóa công việc'),
        content: const Text('Bạn có chắc chắn muốn xóa công việc này không? Hành động này không thể hoàn tác.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Hủy', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await TaskService.deleteTask(widget.taskId);
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã xóa công việc thành công!'), backgroundColor: Color(0xFF10B981)),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Xóa công việc thất bại'), backgroundColor: Color(0xFFEF4444)),
          );
        }
      }
    }
  }

  // Mở modal phân công lại việc
  Future<void> _openAssignModal() async {
    final allUsers = await UserService.searchUsers();
    if (!mounted || _task == null) return;

    List<User> selectedUsers = List.from(_task!.assignees);
    User? primary = _task!.primaryAssignee;

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
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.7,
              ),
              child: Column(
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
                  const Text('Phân công thành viên', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Tích chọn thành viên và chọn sao để chỉ định người phụ trách chính',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: allUsers.length,
                      separatorBuilder: (_, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = allUsers[index];
                        final isSelected = selectedUsers.any((item) => item.id == u.id);
                        final isPrimary = primary?.id == u.id;

                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFEFF6FF),
                            child: Text(
                              u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.bold),
                            ),
                          ),
                          title: Text(u.fullName, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                          subtitle: Text(u.email, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isSelected)
                                IconButton(
                                  tooltip: isPrimary ? 'Người phụ trách chính' : 'Đặt làm phụ trách chính',
                                  icon: Icon(
                                    isPrimary ? Icons.star : Icons.star_border,
                                    color: isPrimary ? Colors.amber : Colors.grey,
                                  ),
                                  onPressed: () {
                                    setModalState(() {
                                      primary = isPrimary ? null : u;
                                    });
                                  },
                                ),
                              Checkbox(
                                value: isSelected,
                                activeColor: const Color(0xFF2563EB),
                                onChanged: (val) {
                                  setModalState(() {
                                    if (val == true) {
                                      selectedUsers.add(u);
                                      primary ??= u;
                                    } else {
                                      selectedUsers.removeWhere((item) => item.id == u.id);
                                      if (primary?.id == u.id) {
                                        primary = selectedUsers.isNotEmpty ? selectedUsers.first : null;
                                      }
                                    }
                                  });
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        final res = await TaskService.assignTask(
                          _task!.id,
                          assigneeIds: selectedUsers.map((u) => u.id).toList(),
                          primaryAssigneeId: primary?.id,
                        );
                        if (!mounted) return;
                        if (res != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cập nhật phân công thành công!'),
                              backgroundColor: Color(0xFF10B981),
                            ),
                          );
                          _loadData();
                        }
                      },
                      child: const Text('Lưu phân công', style: TextStyle(fontWeight: FontWeight.w600)),
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

  // Mở modal chia sẻ công việc (Viewer / Editor)
  Future<void> _openShareModal() async {
    final allUsers = await UserService.searchUsers();
    if (!mounted || _task == null) return;

    User? selectedUser;
    String selectedRole = 'viewer';

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
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
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
                  const Text('Chia sẻ công việc', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Chọn thành viên và quyền hạn (Chỉ xem hoặc Chỉnh sửa)',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<User>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Chọn thành viên',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    ),
                    items: allUsers.map((u) {
                      return DropdownMenuItem<User>(
                        value: u,
                        child: Text(
                          '${u.fullName} (${u.email})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (u) => setModalState(() => selectedUser = u),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedRole = 'viewer'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedRole == 'viewer' ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedRole == 'viewer' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: selectedRole == 'viewer' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.visibility_outlined,
                                  size: 18,
                                  color: selectedRole == 'viewer' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Chỉ xem',
                                  style: TextStyle(
                                    fontWeight: selectedRole == 'viewer' ? FontWeight.w700 : FontWeight.w500,
                                    color: selectedRole == 'viewer' ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setModalState(() => selectedRole = 'editor'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: selectedRole == 'editor' ? const Color(0xFFEFF6FF) : Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: selectedRole == 'editor' ? const Color(0xFF2563EB) : const Color(0xFFE2E8F0),
                                width: selectedRole == 'editor' ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: selectedRole == 'editor' ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Chỉnh sửa',
                                  style: TextStyle(
                                    fontWeight: selectedRole == 'editor' ? FontWeight.w700 : FontWeight.w500,
                                    color: selectedRole == 'editor' ? const Color(0xFF2563EB) : const Color(0xFF475569),
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
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
                      onPressed: selectedUser == null
                          ? null
                          : () async {
                              Navigator.pop(ctx);
                              final success = await TaskService.shareTask(
                                _task!.id,
                                targetUserId: selectedUser!.id,
                                permission: selectedRole,
                              );
                              if (!mounted) return;
                              if (success) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Đã chia sẻ công việc thành công!'),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                                _loadData();
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Không thể chia sẻ công việc này.'),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            },
                      child: const Text('Xác nhận chia sẻ', style: TextStyle(fontWeight: FontWeight.w600)),
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

  Future<void> _revokeShare(String targetUserId) async {
    final success = await TaskService.revokeShare(widget.taskId, targetUserId);
    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã thu hồi quyền chia sẻ'), backgroundColor: Color(0xFF10B981)),
      );
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAFC),
        body: Center(child: CircularProgressIndicator(color: Color(0xFF2563EB))),
      );
    }

    if (_task == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết công việc')),
        body: const Center(child: Text('Không tìm thấy thông tin công việc này')),
      );
    }

    final isOwner = _permission == 'owner';
    final canEdit = isOwner || _permission == 'editor';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Chi Tiết Công Việc',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: Color(0xFF2563EB)),
              tooltip: 'Chỉnh sửa',
              onPressed: () async {
                final refresh = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => TaskEditScreen(task: _task!)),
                );
                if (refresh == true) _loadData();
              },
            ),
          if (isOwner)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444)),
              tooltip: 'Xóa công việc',
              onPressed: _confirmDelete,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status & Priority Bar
            Row(
              children: [
                _buildPriorityBadge(_task!.priority),
                const SizedBox(width: 8),
                _buildStatusBadge(_task!.status),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Quyền: $_permission',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tiêu đề
            Text(
              _task!.title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),

            // Mô tả
            if (_task!.description.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  _task!.description,
                  style: const TextStyle(fontSize: 14, height: 1.6, color: Color(0xFF334155)),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // Đổi nhanh trạng thái
            if (canEdit || _permission == 'assignee') ...[
              _buildSectionHeader('Đổi trạng thái'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildQuickStatusBtn('todo', 'Cần làm', const Color(0xFF64748B)),
                  const SizedBox(width: 8),
                  _buildQuickStatusBtn('in_progress', 'Đang làm', const Color(0xFF2563EB)),
                  const SizedBox(width: 8),
                  _buildQuickStatusBtn('completed', 'Hoàn thành', const Color(0xFF10B981)),
                ],
              ),
              const SizedBox(height: 20),
            ],

            // Thời hạn thực hiện
            _buildSectionHeader('Thời hạn thực hiện'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_month_outlined, color: Color(0xFF2563EB), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bắt đầu: ${_formatDate(_task!.startDate)}',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Hạn chót: ${_formatDate(_task!.dueDate)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _task!.isOverdue ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_task!.isOverdue)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEE2E2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'Quá hạn',
                        style: TextStyle(color: Color(0xFFDC2626), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Người tạo & Người phụ trách
            _buildSectionHeader('Người thực hiện'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Người tạo
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 14,
                        backgroundColor: Color(0xFFF1F5F9),
                        child: Icon(Icons.person_pin, size: 18, color: Color(0xFF64748B)),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Người tạo: ${_task!.createdBy?.fullName ?? "Chưa rõ"}',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
                      ),
                    ],
                  ),
                  const Divider(height: 20),

                  // Người phụ trách chính
                  if (_task!.primaryAssignee != null) ...[
                    Row(
                      children: [
                        const CircleAvatar(
                          radius: 14,
                          backgroundColor: Color(0xFFFEF3C7),
                          child: Icon(Icons.star, size: 16, color: Color(0xFFD97706)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Phụ trách chính', style: TextStyle(fontSize: 11, color: Color(0xFFD97706), fontWeight: FontWeight.bold)),
                              Text(
                                '${_task!.primaryAssignee!.fullName} (${_task!.primaryAssignee!.email})',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Danh sách thành viên được giao
                  if (_task!.assignees.isNotEmpty) ...[
                    const Text('Các thành viên tham gia:', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: _task!.assignees.map((a) {
                        return Chip(
                          backgroundColor: const Color(0xFFEFF6FF),
                          avatar: CircleAvatar(
                            backgroundColor: const Color(0xFF2563EB),
                            child: Text(
                              a.fullName.isNotEmpty ? a.fullName[0].toUpperCase() : '?',
                              style: const TextStyle(color: Colors.white, fontSize: 10),
                            ),
                          ),
                          label: Text(a.fullName, style: const TextStyle(fontSize: 12, color: Color(0xFF1D4ED8))),
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        );
                      }).toList(),
                    ),
                  ] else ...[
                    const Text('Chưa có thành viên nào được giao việc', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ],

                  if (canEdit) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.group_add_outlined, size: 18),
                        label: const Text('Phân công lại thành viên'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _openAssignModal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Chia sẻ & Phân quyền (Nhóm C)
            _buildSectionHeader('Chia sẻ & Phân quyền'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_shares.isNotEmpty) ...[
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _shares.length,
                      separatorBuilder: (_, index) => const Divider(height: 12),
                      itemBuilder: (context, index) {
                        final s = _shares[index];
                        final isEditor = s.permission == 'editor';
                        return Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: isEditor ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                              child: Text(
                                s.user.fullName.isNotEmpty ? s.user.fullName[0].toUpperCase() : '?',
                                style: TextStyle(
                                  color: isEditor ? const Color(0xFF1D4ED8) : const Color(0xFF475569),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(s.user.fullName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                  Text(s.user.email, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isEditor ? const Color(0xFFEFF6FF) : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: isEditor ? const Color(0xFFBFDBFE) : const Color(0xFFE2E8F0)),
                              ),
                              child: Text(
                                s.permissionLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: isEditor ? const Color(0xFF1D4ED8) : const Color(0xFF64748B),
                                ),
                              ),
                            ),
                            if (isOwner)
                              IconButton(
                                icon: const Icon(Icons.close, size: 18, color: Color(0xFFEF4444)),
                                tooltip: 'Thu hồi quyền',
                                onPressed: () => _revokeShare(s.user.id),
                              ),
                          ],
                        );
                      },
                    ),
                  ] else ...[
                    const Text('Chưa có ai được chia sẻ công việc này', style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
                  ],

                  if (isOwner) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.share_outlined, size: 18),
                        label: const Text('Chia sẻ với người khác'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF2563EB),
                          side: const BorderSide(color: Color(0xFF2563EB)),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        onPressed: _openShareModal,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
    );
  }

  Widget _buildPriorityBadge(String priority) {
    Color bg;
    Color fg;
    String label;

    switch (priority) {
      case 'high':
        bg = const Color(0xFFFEE2E2);
        fg = const Color(0xFFDC2626);
        label = 'Ưu tiên Cao';
        break;
      case 'low':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        label = 'Ưu tiên Thấp';
        break;
      case 'medium':
      default:
        bg = const Color(0xFFFEF3C7);
        fg = const Color(0xFFD97706);
        label = 'Ưu tiên Trung bình';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case 'in_progress':
        bg = const Color(0xFFDBEAFE);
        fg = const Color(0xFF1D4ED8);
        label = 'Đang làm';
        break;
      case 'completed':
        bg = const Color(0xFFD1FAE5);
        fg = const Color(0xFF059669);
        label = 'Hoàn thành';
        break;
      case 'todo':
      default:
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF475569);
        label = 'Cần làm';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildQuickStatusBtn(String statusKey, String label, Color color) {
    final isSelected = _task!.status == statusKey;
    return Expanded(
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: isSelected ? color : Colors.white,
          foregroundColor: isSelected ? Colors.white : color,
          side: BorderSide(color: color),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () => _updateStatus(statusKey),
        child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Không có';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
