
import 'package:flutter/material.dart';

import '../Models/app_models.dart';
import '../Services/api_client.dart';
import '../themes/app_theme.dart';

enum ManagementTab { alerts, events, rules }

class ManagementScreen extends StatefulWidget {
  const ManagementScreen({super.key});

  @override
  State<ManagementScreen> createState() => _ManagementScreenState();
}

class _ManagementScreenState extends State<ManagementScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _loadingAlerts = false;
  bool _loadingEvents = false;
  bool _loadingRules = false;

  List<ProtectionAlert> _alerts = [];
  List<DeviceEvent> _events = [];
  List<ProtectionRule> _rules = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAlerts();
    _loadEvents();
    _loadRules();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _message(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? AppTheme.danger : AppTheme.success,
        ),
      );
  }

  String _errorText(Object error) =>
      error.toString().replaceFirst('Exception: ', '');

  List<dynamic> _extractList(dynamic response) {
    if (response is List) return response;

    if (response is Map) {
      final data = response['data'] ??
          response['items'] ??
          response['results'] ??
          response['Data'] ??
          response['Items'];

      if (data is List) return data;
    }

    return [];
  }

  Future<void> _loadAlerts() async {
    setState(() => _loadingAlerts = true);

    try {
      final response = await ApiClient.get('Alert');
      final items = _extractList(response);

      if (!mounted) return;

      setState(() {
        _alerts = items
            .whereType<Map>()
            .map(
              (e) => ProtectionAlert.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
            .toList();
      });
    } catch (e) {
      _message('Không tải được cảnh báo: ${_errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _loadingAlerts = false);
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);

    try {
      final response = await ApiClient.get('DeviceEvent');
      final items = _extractList(response);

      if (!mounted) return;

      setState(() {
        _events = items
            .whereType<Map>()
            .map(
              (e) => DeviceEvent.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
            .toList();
      });
    } catch (e) {
      _message('Không tải được sự kiện: ${_errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _loadingEvents = false);
    }
  }

  Future<void> _loadRules() async {
    setState(() => _loadingRules = true);

    try {
      final response = await ApiClient.get('ProtectionRule');
      final items = _extractList(response);

      if (!mounted) return;

      setState(() {
        _rules = items
            .whereType<Map>()
            .map(
              (e) => ProtectionRule.fromJson(
            Map<String, dynamic>.from(e),
          ),
        )
            .toList();
      });
    } catch (e) {
      _message('Không tải được quy tắc: ${_errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _loadingRules = false);
    }
  }

  Future<void> _refreshAll() async {
    await Future.wait([
      _loadAlerts(),
      _loadEvents(),
      _loadRules(),
    ]);
  }

  Future<void> _markAlertRead(ProtectionAlert alert) async {
    try {
      await ApiClient.patch('Alert/${alert.id}/read');
      _message('Đã cập nhật trạng thái cảnh báo.');
      await _loadAlerts();
    } catch (e) {
      _message('Không cập nhật được: ${_errorText(e)}', error: true);
    }
  }

  Future<void> _deleteAlert(ProtectionAlert alert) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa cảnh báo?',
      message: 'Bạn muốn xóa cảnh báo "${alert.title}"?',
    );

    if (!confirmed) return;

    try {
      await ApiClient.delete('Alert/${alert.id}');
      _message('Đã xóa cảnh báo.');
      await _loadAlerts();
    } catch (e) {
      _message('Không xóa được: ${_errorText(e)}', error: true);
    }
  }

  Future<void> _deleteEvent(DeviceEvent event) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa sự kiện?',
      message: 'Bạn muốn xóa sự kiện "${event.eventType}"?',
    );

    if (!confirmed) return;

    try {
      await ApiClient.delete('DeviceEvent/${event.id}');
      _message('Đã xóa sự kiện.');
      await _loadEvents();
    } catch (e) {
      _message('Không xóa được: ${_errorText(e)}', error: true);
    }
  }

  Future<bool> _confirmDelete({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _showRuleForm({ProtectionRule? rule}) async {
    final formKey = GlobalKey<FormState>();
    final deviceIdController = TextEditingController(
      text: rule?.childDeviceId.toString() ?? '',
    );
    final nameController = TextEditingController(
      text: rule?.ruleName ?? '',
    );
    final typeController = TextEditingController(
      text: rule?.ruleType ?? 'ScreenTime',
    );
    final descriptionController = TextEditingController(
      text: rule?.description ?? '',
    );
    final limitController = TextEditingController(
      text: rule?.dailyLimitMinutes?.toString() ?? '120',
    );

    bool isEnabled = rule?.isEnabled ?? true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            rule == null ? 'Thêm quy tắc' : 'Sửa quy tắc',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: deviceIdController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'ID thiết bị trẻ',
                    ),
                    validator: (value) {
                      if (value == null ||
                          int.tryParse(value.trim()) == null) {
                        return 'Nhập ID thiết bị hợp lệ';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên quy tắc',
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nhập tên quy tắc'
                        : null,
                  ),
                  TextFormField(
                    controller: typeController,
                    decoration: const InputDecoration(
                      labelText: 'Loại quy tắc',
                      hintText: 'Ví dụ: ScreenTime',
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nhập loại quy tắc'
                        : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Mô tả',
                    ),
                  ),
                  TextFormField(
                    controller: limitController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Giới hạn phút mỗi ngày',
                    ),
                    validator: (value) {
                      if (value == null ||
                          int.tryParse(value.trim()) == null ||
                          int.parse(value.trim()) < 0) {
                        return 'Nhập số phút hợp lệ';
                      }
                      return null;
                    },
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Bật quy tắc'),
                    value: isEnabled,
                    onChanged: (value) {
                      setDialogState(() => isEnabled = value);
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Hủy'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;

                Navigator.pop(dialogContext, {
                  'childDeviceId':
                  int.parse(deviceIdController.text.trim()),
                  'ruleName': nameController.text.trim(),
                  'ruleType': typeController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'dailyLimitMinutes':
                  int.parse(limitController.text.trim()),
                  'isEnabled': isEnabled,
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      deviceIdController.dispose();
      nameController.dispose();
      typeController.dispose();
      descriptionController.dispose();
      limitController.dispose();
    });

    if (!mounted || result == null) return;

    try {
      if (rule == null) {
        await ApiClient.post('ProtectionRule', body: result);
        _message('Đã thêm quy tắc bảo vệ.');
      } else {
        await ApiClient.put(
          'ProtectionRule/${rule.id}',
          body: {
            'ruleName': result['ruleName'],
            'ruleType': result['ruleType'],
            'description': result['description'],
            'dailyLimitMinutes': result['dailyLimitMinutes'],
            'isEnabled': result['isEnabled'],
          },
        );
        _message('Đã cập nhật quy tắc.');
      }

      await _loadRules();
    } catch (e) {
      _message('Không lưu được quy tắc: ${_errorText(e)}', error: true);
    }
  }

  Future<void> _toggleRule(ProtectionRule rule) async {
    try {
      await ApiClient.patch('ProtectionRule/${rule.id}/toggle');
      _message('Đã thay đổi trạng thái quy tắc.');
      await _loadRules();
    } catch (e) {
      _message('Không đổi được trạng thái: ${_errorText(e)}',
          error: true);
    }
  }

  Future<void> _deleteRule(ProtectionRule rule) async {
    final confirmed = await _confirmDelete(
      title: 'Xóa quy tắc?',
      message: 'Bạn muốn xóa "${rule.ruleName}"?',
    );

    if (!confirmed) return;

    try {
      await ApiClient.delete('ProtectionRule/${rule.id}');
      _message('Đã xóa quy tắc.');
      await _loadRules();
    } catch (e) {
      _message('Không xóa được: ${_errorText(e)}', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Quản lý bảo vệ',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refreshAll,
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Tải lại',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.muted,
          indicatorColor: AppTheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.notifications_active_outlined), text: 'Cảnh báo'),
            Tab(icon: Icon(Icons.history_rounded), text: 'Sự kiện'),
            Tab(icon: Icon(Icons.shield_outlined), text: 'Quy tắc'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildAlerts(),
          _buildEvents(),
          _buildRules(),
        ],
      ),
      floatingActionButton: AnimatedBuilder(
        animation: _tabController,
        builder: (context, child) {
          if (_tabController.index != 2) {
            return const SizedBox.shrink();
          }

          return FloatingActionButton.extended(
            onPressed: () => _showRuleForm(),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Thêm quy tắc'),
          );
        },
      ),
    );
  }

  Widget _buildAlerts() {
    if (_loadingAlerts && _alerts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_alerts.isEmpty) {
      return _emptyState(
        Icons.notifications_none_rounded,
        'Chưa có cảnh báo',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadAlerts,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _alerts.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final alert = _alerts[index];

          return _card(
            icon: Icons.notifications_active_outlined,
            title: alert.title,
            subtitle: alert.message,
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'read') _markAlertRead(alert);
                if (value == 'delete') _deleteAlert(alert);
              },
              itemBuilder: (_) => [
                if (!alert.isRead)
                  const PopupMenuItem(
                    value: 'read',
                    child: Text('Đánh dấu đã đọc'),
                  ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa cảnh báo'),
                ),
              ],
            ),
            footer: Row(
              children: [
                _statusChip(
                  alert.isRead ? 'Đã đọc' : 'Chưa đọc',
                  alert.isRead ? AppTheme.success : AppTheme.warning,
                ),
                const SizedBox(width: 8),
                _statusChip(alert.severity, AppTheme.danger),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildEvents() {
    if (_loadingEvents && _events.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_events.isEmpty) {
      return _emptyState(Icons.history_rounded, 'Chưa có sự kiện');
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _events.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final event = _events[index];

          return _card(
            icon: Icons.event_note_rounded,
            title: event.eventType,
            subtitle: event.description ?? 'Không có mô tả',
            trailing: IconButton(
              tooltip: 'Xóa sự kiện',
              onPressed: () => _deleteEvent(event),
              icon: const Icon(
                Icons.delete_outline,
                color: AppTheme.danger,
              ),
            ),
            footer: Text(
              event.occurredAtUtc?.toLocal().toString() ??
                  'Thời gian chưa được cung cấp',
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRules() {
    if (_loadingRules && _rules.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_rules.isEmpty) {
      return _emptyState(
        Icons.shield_outlined,
        'Chưa có quy tắc bảo vệ',
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRules,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: _rules.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final rule = _rules[index];

          return _card(
            icon: Icons.shield_rounded,
            title: rule.ruleName,
            subtitle: [
              'Loại: ${rule.ruleType}',
              if (rule.description?.isNotEmpty == true)
                rule.description!,
              if (rule.dailyLimitMinutes != null)
                'Giới hạn: ${rule.dailyLimitMinutes} phút/ngày',
              'Thiết bị ID: ${rule.childDeviceId}',
            ].join('\n'),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') _showRuleForm(rule: rule);
                if (value == 'delete') _deleteRule(rule);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Chỉnh sửa'),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Xóa quy tắc'),
                ),
              ],
            ),
            footer: Row(
              children: [
                _statusChip(
                  rule.isEnabled ? 'Đang bật' : 'Đang tắt',
                  rule.isEnabled ? AppTheme.success : AppTheme.muted,
                ),
                const Spacer(),
                Switch(
                  value: rule.isEnabled,
                  onChanged: (_) => _toggleRule(rule),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _card({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    required Widget footer,
  }) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              trailing,
            ],
          ),
          const SizedBox(height: 13),
          footer,
        ],
      ),
    );
  }

  Widget _statusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _emptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 56, color: AppTheme.muted),
          const SizedBox(height: 14),
          Text(
            message,
            style: const TextStyle(
              color: AppTheme.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
