
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../Models/app_models.dart';
import '../Services/api_client.dart';
import '../Services/auth_service.dart';
import '../Services/device_services.dart';
import '../themes/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<ChildDevice> _devices = [];
  bool _loading = true;
  bool _updatingLocation = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadDevices();
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? AppTheme.danger : AppTheme.success,
      ),
    );
  }

  Future<void> _loadDevices() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.get('ChildDevice');
      dynamic data = response;

      if (response is Map) {
        data = response['data'] ??
            response['items'] ??
            response['results'] ??
            response['Data'] ??
            response['Items'] ??
            response;
      }

      final List<ChildDevice> devices = [];

      if (data is List) {
        for (final item in data) {
          if (item is Map) {
            devices.add(
              ChildDevice.fromJson(Map<String, dynamic>.from(item)),
            );
          }
        }
      } else if (data is Map) {
        devices.add(
          ChildDevice.fromJson(Map<String, dynamic>.from(data)),
        );
      }

      if (!mounted) return;

      setState(() => _devices = devices);
    } catch (e) {
      if (!mounted) return;

      setState(() => _error = e.toString());
      _showMessage('Không tải được danh sách thiết bị: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _updateLocation(ChildDevice device) async {
    setState(() => _updatingLocation = true);

    try {
      final position = await DeviceServices.getCurrentLocation();

      await ApiClient.put(
        'ChildDevice/${device.id}/location',
        body: {
          'latitude': position.latitude,
          'longitude': position.longitude,
        },
      );

      if (!mounted) return;

      _showMessage('Đã gửi vị trí hiện tại lên máy chủ.');
      await _loadDevices();
    } catch (e) {
      if (mounted) {
        _showMessage('Không cập nhật được vị trí: $e', error: true);
      }
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Đăng xuất'),
        content: const Text('Bạn có chắc muốn đăng xuất không?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hủy'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Đăng xuất'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await AuthService.logout();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _devices.where((d) => d.isActive).length;
    final locationCount = _devices
        .where((d) => d.latitude != null && d.longitude != null)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text(
          'ParentShield',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'Tải lại',
            onPressed: _loading ? null : _loadDevices,
            icon: const Icon(Icons.refresh_rounded),
          ),
          IconButton(
            tooltip: 'Tài khoản',
            onPressed: () => Navigator.pushNamed(context, '/profile'),
            icon: const Icon(Icons.account_circle_outlined),
          ),
          IconButton(
            tooltip: 'Đăng xuất',
            onPressed: _logout,
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDevices,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            _welcomeCard(),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.devices_rounded,
                    label: 'Thiết bị',
                    value: _loading ? '—' : '${_devices.length}',
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    icon: Icons.check_circle_outline_rounded,
                    label: 'Đang hoạt động',
                    value: _loading ? '—' : '$activeCount',
                    color: AppTheme.success,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    icon: Icons.location_on_outlined,
                    label: 'Có vị trí',
                    value: _loading ? '—' : '$locationCount',
                    color: const Color(0xFF7C3AED),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _sectionHeader(
              'Vị trí thiết bị',
              'Vị trí được lưu gần nhất',
            ),
            const SizedBox(height: 12),
            _buildMap(),
            const SizedBox(height: 24),
            _sectionHeader(
              'Thiết bị của trẻ',
              '${_devices.length} thiết bị đã liên kết',
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null && _devices.isEmpty)
              _emptyCard(
                icon: Icons.cloud_off_outlined,
                title: 'Không tải được dữ liệu',
                subtitle: 'Kiểm tra kết nối API và đăng nhập rồi thử lại.',
                actionLabel: 'Thử lại',
                onAction: _loadDevices,
              )
            else if (_devices.isEmpty)
                _emptyCard(
                  icon: Icons.devices_other_rounded,
                  title: 'Chưa có thiết bị',
                  subtitle: 'Thêm thiết bị để bắt đầu quản lý.',
                  actionLabel: 'Thêm thiết bị',
                  onAction: () =>
                      Navigator.pushNamed(context, '/devices').then((_) {
                        if (mounted) _loadDevices();
                      }),
                )
              else
                ..._devices.map(_deviceCard),
            const SizedBox(height: 24),
            _sectionHeader('Quản lý', 'Các chức năng chính'),
            const SizedBox(height: 12),
            _navigationCard(
              icon: Icons.devices_rounded,
              title: 'Quản lý thiết bị',
              subtitle: 'Thêm, sửa, xóa thiết bị và tạo mã liên kết',
              onTap: () =>
                  Navigator.pushNamed(context, '/devices').then((_) {
                    if (mounted) _loadDevices();
                  }),
            ),
            const SizedBox(height: 10),
            _navigationCard(
              icon: Icons.notifications_active_outlined,
              title: 'Cảnh báo và sự kiện',
              subtitle: 'Theo dõi cảnh báo và lịch sử hoạt động',
              onTap: () => Navigator.pushNamed(context, '/management'),
            ),
            const SizedBox(height: 10),
            _navigationCard(
              icon: Icons.shield_outlined,
              title: 'Quy tắc bảo vệ',
              subtitle: 'Quản lý giới hạn và quy tắc an toàn',
              onTap: () => Navigator.pushNamed(
                context,
                '/management',
                arguments: 'rules',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _welcomeCard() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [Color(0xFF172554), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.shield_rounded,
            color: Colors.white,
            size: 36,
          ),
          SizedBox(height: 18),
          Text(
            'Không gian gia đình an toàn',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Quản lý thiết bị, xem vị trí đã lưu và theo dõi các sự kiện bảo vệ.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.6,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 23),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w900,
              fontSize: 23,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppTheme.navy,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: AppTheme.muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildMap() {
    final locatedDevices = _devices
        .where((device) =>
    device.latitude != null && device.longitude != null)
        .toList();

    final center = locatedDevices.isNotEmpty
        ? LatLng(
      locatedDevices.first.latitude!,
      locatedDevices.first.longitude!,
    )
        : const LatLng(10.7769, 106.7009);

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 260,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE8ECF4)),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: locatedDevices.isEmpty ? 11 : 14,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.example.nguyentanphat_2380604932_ktra',
                ),
                MarkerLayer(
                  markers: locatedDevices.map((device) {
                    return Marker(
                      point: LatLng(
                        device.latitude!,
                        device.longitude!,
                      ),
                      width: 130,
                      height: 65,
                      child: Column(
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppTheme.danger,
                            size: 34,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(7),
                            ),
                            child: Text(
                              device.childName.isEmpty
                                  ? device.deviceName
                                  : device.childName,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
            if (locatedDevices.isEmpty)
              Positioned(
                left: 12,
                right: 12,
                top: 12,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Chưa có tọa độ được lưu. Bản đồ đang hiển thị khu vực tham chiếu TP.HCM.',
                    style: TextStyle(
                      color: AppTheme.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deviceCard(ChildDevice device) {
    final hasLocation =
        device.latitude != null && device.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.phone_android_rounded,
                  color: AppTheme.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.childName.isEmpty
                          ? 'Thiết bị trẻ'
                          : device.childName,
                      style: const TextStyle(
                        color: AppTheme.navy,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      device.deviceName,
                      style: const TextStyle(
                        color: AppTheme.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 9,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: device.isActive
                      ? AppTheme.success.withValues(alpha: 0.10)
                      : AppTheme.muted.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  device.isActive ? 'Hoạt động' : 'Đã tắt',
                  style: TextStyle(
                    color: device.isActive
                        ? AppTheme.success
                        : AppTheme.muted,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                hasLocation
                    ? Icons.location_on_outlined
                    : Icons.location_off_outlined,
                size: 18,
                color: hasLocation ? AppTheme.success : AppTheme.muted,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  hasLocation
                      ? '${device.latitude}, ${device.longitude}'
                      : 'Chưa có vị trí được lưu',
                  style: const TextStyle(
                    color: AppTheme.muted,
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cập nhật vị trí từ điện thoại đang chạy app',
                onPressed: _updatingLocation
                    ? null
                    : () => _updateLocation(device),
                icon: const Icon(
                  Icons.my_location_rounded,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8ECF4)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppTheme.muted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.navy,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.muted,
              height: 1.5,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ),
    );
  }

  Widget _navigationCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(15),
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
                child: Icon(icon, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
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
                        fontSize: 12,
                        height: 1.4,
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
