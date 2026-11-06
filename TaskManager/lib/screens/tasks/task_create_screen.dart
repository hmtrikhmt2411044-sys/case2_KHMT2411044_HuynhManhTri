import 'package:flutter/material.dart';
import '../../models/user.dart';
import '../../services/task_service.dart';
import '../../services/user_service.dart';

class TaskCreateScreen extends StatefulWidget {
  const TaskCreateScreen({super.key});

  @override
  State<TaskCreateScreen> createState() => _TaskCreateScreenState();
}

class _TaskCreateScreenState extends State<TaskCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _priority = 'medium';
  final String _status = 'todo';
  DateTime? _startDate;
  DateTime? _dueDate;

  List<User> _availableUsers = [];
  final List<User> _selectedAssignees = [];
  User? _primaryAssignee;
  bool _isLoading = false;
  bool _isLoadingUsers = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    final users = await UserService.searchUsers();
    if (mounted) {
      setState(() {
        _availableUsers = users;
        _isLoadingUsers = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final now = DateTime.now();
    final initialDate = isStart
        ? (_startDate ?? now)
        : (_dueDate ?? _startDate ?? now);

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2563EB),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
          if (_dueDate != null && _dueDate!.isBefore(picked)) {
            _dueDate = picked;
          }
        } else {
          _dueDate = picked;
        }
      });
    }
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Chưa chọn';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate != null && _dueDate != null && _dueDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hạn hoàn thành không thể trước ngày bắt đầu')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final newTask = await TaskService.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _priority,
        status: _status,
        startDate: _startDate,
        dueDate: _dueDate,
        assigneeIds: _selectedAssignees.map((u) => u.id).toList(),
        primaryAssigneeId: _primaryAssignee?.id,
      );

      if (mounted) {
        setState(() => _isLoading = false);
        if (newTask != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Tạo công việc mới thành công!'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thể tạo công việc. Vui lòng thử lại!'),
              backgroundColor: Color(0xFFEF4444),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: $e'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Tạo Công Việc Mới',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18, color: Color(0xFF0F172A)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFFE2E8F0), height: 1),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tiêu đề
              _buildSectionTitle('Tên công việc *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                decoration: _inputDecoration(
                  hintText: 'Nhập tiêu đề công việc...',
                  prefixIcon: Icons.task_alt_outlined,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Vui lòng nhập tên công việc';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Mô tả
              _buildSectionTitle('Mô tả chi tiết'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                decoration: _inputDecoration(
                  hintText: 'Mô tả nội dung, yêu cầu cụ thể của công việc...',
                  prefixIcon: Icons.description_outlined,
                ),
              ),
              const SizedBox(height: 20),

              // Mức độ ưu tiên
              _buildSectionTitle('Mức độ ưu tiên'),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildPriorityChip('low', 'Thấp', const Color(0xFF10B981)),
                  const SizedBox(width: 10),
                  _buildPriorityChip('medium', 'Trung bình', const Color(0xFFF59E0B)),
                  const SizedBox(width: 10),
                  _buildPriorityChip('high', 'Cao', const Color(0xFFEF4444)),
                ],
              ),
              const SizedBox(height: 20),

              // Thời hạn (Start Date & Due Date)
              _buildSectionTitle('Thời hạn thực hiện'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildDateTile(
                      label: 'Bắt đầu',
                      value: _formatDate(_startDate),
                      icon: Icons.calendar_today_outlined,
                      onTap: () => _pickDate(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildDateTile(
                      label: 'Hạn chót',
                      value: _formatDate(_dueDate),
                      icon: Icons.event_available_outlined,
                      onTap: () => _pickDate(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Phân công thành viên
              _buildSectionTitle('Giao việc cho thành viên'),
              const SizedBox(height: 8),
              _buildAssigneeSelector(),
              const SizedBox(height: 32),

              // Nút tạo công việc
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                        )
                      : const Text(
                          'Tạo công việc',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFF334155),
      ),
    );
  }

  InputDecoration _inputDecoration({required String hintText, required IconData prefixIcon}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
      prefixIcon: Icon(prefixIcon, color: const Color(0xFF64748B), size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
      ),
    );
  }

  Widget _buildPriorityChip(String value, String label, Color color) {
    final isSelected = _priority == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _priority = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE2E8F0),
              width: isSelected ? 1.5 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? color : const Color(0xFF64748B),
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: const Color(0xFF2563EB)),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                ),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssigneeSelector() {
    if (_isLoadingUsers) {
      return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Đã chọn: ${_selectedAssignees.length} thành viên',
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              TextButton.icon(
                onPressed: _showAssignDialog,
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                label: const Text('Thêm / Sửa'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          if (_selectedAssignees.isNotEmpty) ...[
            const Divider(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _selectedAssignees.map((u) {
                final isPrimary = _primaryAssignee?.id == u.id;
                return Chip(
                  avatar: CircleAvatar(
                    backgroundColor: const Color(0xFF2563EB),
                    child: Text(
                      u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                  label: Text(
                    '${u.fullName}${isPrimary ? ' (Chính)' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isPrimary ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 16),
                  onDeleted: () {
                    setState(() {
                      _selectedAssignees.removeWhere((item) => item.id == u.id);
                      if (_primaryAssignee?.id == u.id) {
                        _primaryAssignee = _selectedAssignees.isNotEmpty ? _selectedAssignees.first : null;
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  void _showAssignDialog() {
    showModalBottomSheet(
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
                  const Text(
                    'Chọn thành viên thực hiện',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Tích chọn để giao việc, bấm vào sao để đặt làm người phụ trách chính',
                    style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: _availableUsers.isEmpty
                        ? const Center(child: Text('Không có thành viên nào khác trong hệ thống'))
                        : ListView.separated(
                            itemCount: _availableUsers.length,
                            separatorBuilder: (_, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final u = _availableUsers[index];
                              final isSelected = _selectedAssignees.any((item) => item.id == u.id);
                              final isPrimary = _primaryAssignee?.id == u.id;

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
                                            _primaryAssignee = isPrimary ? null : u;
                                          });
                                          setState(() {});
                                        },
                                      ),
                                    Checkbox(
                                      value: isSelected,
                                      activeColor: const Color(0xFF2563EB),
                                      onChanged: (val) {
                                        setModalState(() {
                                          if (val == true) {
                                            _selectedAssignees.add(u);
                                            _primaryAssignee ??= u;
                                          } else {
                                            _selectedAssignees.removeWhere((item) => item.id == u.id);
                                            if (_primaryAssignee?.id == u.id) {
                                              _primaryAssignee = _selectedAssignees.isNotEmpty ? _selectedAssignees.first : null;
                                            }
                                          }
                                        });
                                        setState(() {});
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
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Hoàn tất chọn', style: TextStyle(fontWeight: FontWeight.w600)),
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
}
