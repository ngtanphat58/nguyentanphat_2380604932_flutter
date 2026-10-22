
import 'package:flutter/material.dart';

import '../Models/app_models.dart';
import '../Services/api_client.dart';
import '../Services/auth_service.dart';
import '../Services/device_services.dart';
import '../themes/app_theme.dart';
import 'SosScreen.dart';

class ChildScreen extends StatefulWidget {
  const ChildScreen({super.key});

  @override
  State<ChildScreen> createState() => _ChildScreenState();
}

class _ChildScreenState extends State<ChildScreen> {
  ChildDevice? _device;
  List<ProtectionRule> _rules = [];

  bool _loading = true;
  bool _updatingLocation = false;
  bool _sendingEvent = false;

  @override
  void initState() {
    super.initState();
    _loadChildData();
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

  Map<String, dynamic>? _extractObject(dynamic response) {
    if (response is! Map) return null;

    final nested = response['data'] ?? response['Data'] ?? response['item'];
    if (nested is Map) {
      return Map<String, dynamic>.from(nested);
    }

    return Map<String, dynamic>.from(response);
  }

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

  Future<void> _loadChildData() async {
    setState(() => _loading = true);

    try {
      final results = await Future.wait([
        ApiClient.get('Child/my-device'),
        ApiClient.get('Child/my-rules'),
      ]);

      final deviceJson = _extractObject(results[0]);
      final ruleItems = _extractList(results[1]);

      if (!mounted) return;

      setState(() {
        _device = deviceJson == null
            ? null
            : ChildDevice.fromJson(deviceJson);

        _rules = ruleItems
            .whereType<Map>()
            .map(
              (item) => ProtectionRule.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
            .toList();
      });
    } catch (e) {
      _message('Không tải được dữ liệu: ${_errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateLocation() async {
    if (_updatingLocation) return;

    setState(() => _updatingLocation = true);

    try {
      // Chỉ lấy vị trí khi người dùng nhấn nút này.
      final position = await DeviceServices.getCurrentLocation();

      await ApiClient.put(
        'Child/my-location',
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      _message('Đã gửi vị trí hiện tại lên hệ thống.');
      await _loadChildData();
    } catch (e) {
      _message('Không cập nhật được vị trí: ${_errorText(e)}',
          error: true);
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _showEventForm() async {
    final formKey = GlobalKey<FormState>();
    final typeController = TextEditingController(text: 'ManualReport');
    final descriptionController = TextEditingController();

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gửi sự kiện'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: typeController,
                  decoration: const InputDecoration(
                    labelText: 'Loại sự kiện',
                    hintText: 'Ví dụ: ManualReport',
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Nhập loại sự kiện'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: descriptionController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Nội dung',
                    hintText: 'Nhập nội dung muốn báo cho phụ huynh',
                  ),
                  validator: (value) =>
                  value == null || value.trim().isEmpty
                      ? 'Nhập nội dung sự kiện'
                      : null,
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
                'eventType': typeController.text.trim(),
                'description': descriptionController.text.trim(),
              });
            },
            child: const Text('Gửi'),
          ),
        ],
      ),
    );

    typeController.dispose();
    descriptionController.dispose();

    if (result == null) return;

    setState(() => _sendingEvent = true);

    try {
      await ApiClient.post(
        'Child/my-events',
        body: result,
      );

      _message('Đã gửi sự kiện cho hệ thống.');
    } catch (e) {
      _message('Không gửi được sự kiện: ${_errorText(e)}', error: true);
    } finally {
      if (mounted) setState(() => _sendingEvent = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn muốn đăng xuất khỏi tài khoản này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Ở lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    await AuthService.logout();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/login',
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'ParentShield',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loadChildData,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            onPressed: _logout,
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
        onRefresh: _loadChildData,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            _buildWelcome(),
            const SizedBox(height: 20),
            _buildLocationCard(),
            const SizedBox(height: 18),
            _buildDeviceCard(),
            const SizedBox(height: 24),
            _sectionTitle(
              'Quy tắc bảo vệ',
              Icons.shield_outlined,
            ),
            const SizedBox(height: 12),
            if (_rules.isEmpty)
              _emptyCard('Chưa có quy tắc bảo vệ được thiết lập.')
            else
              ..._rules.map(_buildRuleCard),
            const SizedBox(height: 24),
            _sectionTitle(
              'Hành động',
              Icons.touch_app_rounded,
            ),
            const SizedBox(height: 12),
            _actionButton(
              icon: Icons.location_on_outlined,
              title: 'Cập nhật vị trí hiện tại',
              subtitle: 'Chỉ gửi vị trí khi bạn nhấn nút',
              onTap: _updateLocation,
              loading: _updatingLocation,
            ),
            const SizedBox(height: 10),
            _actionButton(
              icon: Icons.outgoing_mail,
              title: 'Gửi sự kiện',
              subtitle: 'Gửi thông tin đến hệ thống bảo vệ',
              onTap: _showEventForm,
              loading: _sendingEvent,
            ),
            const SizedBox(height: 10),

            _actionButton(
              icon: Icons.sos_rounded,
              title: 'SOS khẩn cấp',
              subtitle: 'Gửi cảnh báo ngay cho phụ huynh',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SosScreen(),
                  ),
                );
              },
              loading: false,
            ),
            const Text(
              'ParentShield • Bảo vệ an toàn số',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.muted,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcome() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppTheme.navy, AppTheme.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 15),
          Text(
            'Xin chào!',
            style: TextStyle(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 7),
          Text(
            'Kiểm tra thiết bị và các quy tắc bảo vệ của bạn.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard() {
    final hasLocation =
        _device?.latitude != null && _device?.longitude != null;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.location_on_rounded,
                color: AppTheme.primary,
              ),
              SizedBox(width: 9),
              Text(
                'Vị trí đã lưu',
                style: TextStyle(
                  color: AppTheme.navy,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            hasLocation
                ? 'Vĩ độ: ${_device!.latitude}\nKinh độ: ${_device!.longitude}'
                : 'Chưa có vị trí được lưu.',
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.7,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _updatingLocation ? null : _updateLocation,
              icon: _updatingLocation
                  ? const SizedBox(
                width: 17,
                height: 17,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
                  : const Icon(Icons.my_location_rounded),
              label: Text(
                _updatingLocation
                    ? 'Đang cập nhật...'
                    : 'Cập nhật vị trí',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceCard() {
    final device = _device;

    if (device == null) {
      return _emptyCard(
        'Tài khoản chưa được liên kết với thiết bị. '
            'Hãy kiểm tra mã liên kết với phụ huynh.',
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle('Thiết bị của bạn', Icons.phone_android_rounded),
          const SizedBox(height: 15),
          _infoRow('Tên thiết bị', device.deviceName),
          _infoRow('Tên trẻ', device.childName),
          _infoRow(
            'Trạng thái',
            device.isActive ? 'Đang hoạt động' : 'Đã tắt',
          ),
          _infoRow(
            'Mã thiết bị',
            device.deviceIdentifier ?? 'Chưa có',
          ),
        ],
      ),
    );
  }

  Widget _buildRuleCard(ProtectionRule rule) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.shield_outlined,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rule.ruleName,
                  style: const TextStyle(
                    color: AppTheme.navy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  rule.description?.isNotEmpty == true
                      ? rule.description!
                      : 'Loại quy tắc: ${rule.ruleType}',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
                if (rule.dailyLimitMinutes != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    'Giới hạn ${rule.dailyLimitMinutes} phút/ngày',
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  rule.isEnabled ? 'Đang bật' : 'Đang tắt',
                  style: TextStyle(
                    color: rule.isEnabled
                        ? AppTheme.success
                        : AppTheme.danger,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppTheme.primary),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: AppTheme.navy,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: AppTheme.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyCard(String message) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppTheme.muted,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _actionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required bool loading,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE8ECF4)),
          ),
          child: Row(
            children: [
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: loading
                    ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
                    : Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
