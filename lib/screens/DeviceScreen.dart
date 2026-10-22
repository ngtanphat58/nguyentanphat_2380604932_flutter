
import 'package:flutter/material.dart';

import '../Models/app_models.dart';
import '../Services/api_client.dart';
import '../themes/app_theme.dart';

class DeviceScreen extends StatefulWidget {
  const DeviceScreen({super.key});

  @override
  State<DeviceScreen> createState() => _DeviceScreenState();
}

class _DeviceScreenState extends State<DeviceScreen> {
  List<ChildDevice> _devices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _message(String text, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
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

      // Một số API có thể trả một thiết bị dưới dạng object.
      if (response.containsKey('id') || response.containsKey('Id')) {
        return [response];
      }
    }

    return [];
  }

  Future<void> _loadDevices({bool showLoading = true}) async {
    if (!mounted) return;

    if (showLoading) {
      setState(() => _loading = true);
    }

    try {
      final response = await ApiClient.get('ChildDevice');
      final items = _extractList(response);

      final devices = items
          .whereType<Map>()
          .map(
            (item) => ChildDevice.fromJson(
          Map<String, dynamic>.from(item),
        ),
      )
          .toList();

      if (!mounted) return;

      setState(() {
        _devices = devices;
      });
    } catch (e) {
      if (mounted) {
        _message(
          'Không tải được thiết bị: ${_errorText(e)}',
          error: true,
        );
      }
    } finally {
      if (mounted && showLoading) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _showDeviceForm({ChildDevice? device}) async {
    final formKey = GlobalKey<FormState>();

    final childNameController = TextEditingController(
      text: device?.childName ?? '',
    );
    final deviceNameController = TextEditingController(
      text: device?.deviceName ?? '',
    );
    final identifierController = TextEditingController(
      text: device?.deviceIdentifier ?? '',
    );

    bool isActive = device?.isActive ?? true;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            device == null ? 'Thêm thiết bị' : 'Chỉnh sửa thiết bị',
          ),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: childNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên trẻ',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nhập tên trẻ'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: deviceNameController,
                    decoration: const InputDecoration(
                      labelText: 'Tên thiết bị',
                      prefixIcon: Icon(Icons.phone_android_rounded),
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nhập tên thiết bị'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: identifierController,
                    decoration: const InputDecoration(
                      labelText: 'Mã định danh thiết bị',
                      hintText: 'Ví dụ: CHILD-PHONE-01',
                      prefixIcon: Icon(Icons.fingerprint_rounded),
                    ),
                    validator: (value) =>
                    value == null || value.trim().isEmpty
                        ? 'Nhập mã định danh'
                        : null,
                  ),
                  if (device != null) ...[
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Thiết bị đang hoạt động'),
                      value: isActive,
                      onChanged: (value) {
                        setDialogState(() => isActive = value);
                      },
                    ),
                  ],
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
                  'childName': childNameController.text.trim(),
                  'deviceName': deviceNameController.text.trim(),
                  'deviceIdentifier': identifierController.text.trim(),
                  'isActive': isActive,
                });
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || result == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        childNameController.dispose();
        deviceNameController.dispose();
        identifierController.dispose();
      });
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      childNameController.dispose();
      deviceNameController.dispose();
      identifierController.dispose();
    });

    try {
      if (device == null) {
        await ApiClient.post('ChildDevice', body: {
          'childName': result['childName'],
          'deviceName': result['deviceName'],
          'deviceIdentifier': result['deviceIdentifier'],
        });

        _message('Đã thêm thiết bị.');
      } else {
        await ApiClient.put(
          'ChildDevice/${device.id}',
          body: {
            ...result,
            'id': device.id,
          },
        );

        _message('Đã cập nhật thiết bị.');
      }

      await _loadDevices(showLoading: false);
    } catch (e) {
      _message('Không lưu được thiết bị: ${_errorText(e)}',
          error: true);
    }
  }

  Future<void> _deleteDevice(ChildDevice device) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thiết bị?'),
        content: Text(
          'Bạn có chắc muốn xóa thiết bị "${device.deviceName}" không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ApiClient.delete('ChildDevice/${device.id}');
      _message('Đã xóa thiết bị.');
      await _loadDevices(showLoading: false);
    } catch (e) {
      _message('Không xóa được thiết bị: ${_errorText(e)}',
          error: true);
    }
  }

  Future<void> _createLinkCode(ChildDevice device) async {
    try {
      final response = await ApiClient.post(
        'ChildLink/device/${device.id}/create',
      );

      final data = response is Map
          ? Map<String, dynamic>.from(response)
          : <String, dynamic>{};

      final code = (data['code'] ??
          data['linkCode'] ??
          data['codeText'] ??
          data['childLinkCode'] ??
          data['Code'] ??
          data['LinkCode'] ??
          '')
          .toString();

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Mã liên kết tài khoản trẻ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.link_rounded,
                color: AppTheme.primary,
                size: 48,
              ),
              const SizedBox(height: 16),
              if (code.isNotEmpty)
                SelectableText(
                  code,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 5,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.navy,
                  ),
                )
              else
                const Text(
                  'API đã trả kết quả nhưng không tìm thấy trường mã liên kết. '
                      'Hãy kiểm tra JSON response của endpoint tạo mã.',
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              const Text(
                'Chia sẻ mã này với tài khoản trẻ để đăng ký liên kết. '
                    'Nếu mã hết hạn, hãy tạo mã mới.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.muted,
                  height: 1.5,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đóng'),
            ),
          ],
        ),
      );
    } catch (e) {
      _message('Không tạo được mã liên kết: ${_errorText(e)}',
          error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'Quản lý thiết bị',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDevices,
            tooltip: 'Tải lại',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showDeviceForm(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Thêm thiết bị'),
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: _loading && _devices.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : _devices.isEmpty
            ? ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(24),
          children: const [
            SizedBox(height: 100),
            Icon(
              Icons.devices_other_rounded,
              size: 65,
              color: AppTheme.muted,
            ),
            SizedBox(height: 18),
            Text(
              'Chưa có thiết bị nào',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.navy,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Nhấn “Thêm thiết bị” để bắt đầu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.muted),
            ),
          ],
        )
            : ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          itemCount: _devices.length,
          separatorBuilder: (_, __) =>
          const SizedBox(height: 12),
          itemBuilder: (context, index) =>
              _deviceCard(_devices[index]),
        ),
      ),
    );
  }

  Widget _deviceCard(ChildDevice device) {
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.deviceName,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      'Trẻ: ${device.childName}',
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') {
                    _showDeviceForm(device: device);
                  } else if (value == 'delete') {
                    _deleteDevice(device);
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'edit',
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Chỉnh sửa'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: ListTile(
                      leading: Icon(
                        Icons.delete_outline,
                        color: AppTheme.danger,
                      ),
                      title: Text('Xóa thiết bị'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow(
            Icons.fingerprint_rounded,
            'Mã thiết bị',
            device.deviceIdentifier ?? 'Chưa có',
          ),
          const SizedBox(height: 8),
          _detailRow(
            Icons.circle,
            'Trạng thái',
            device.isActive ? 'Đang hoạt động' : 'Đã tắt',
            valueColor:
            device.isActive ? AppTheme.success : AppTheme.danger,
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _createLinkCode(device),
              icon: const Icon(Icons.link_rounded),
              label: const Text('Tạo mã liên kết cho trẻ'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(
      IconData icon,
      String label,
      String value, {
        Color? valueColor,
      }) {
    return Row(
      children: [
        Icon(icon, size: 17, color: AppTheme.muted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? AppTheme.navy,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
