
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

import '../Services/sos_service.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  StreamSubscription<AccelerometerEvent>? _subscription;

  bool _sending = false;
  bool _shakeEnabled = true;

  int _shakeCount = 0;
  DateTime _lastShake = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime _lastAutoSos = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  void initState() {
    super.initState();
    _startShakeDetection();
  }

  void _startShakeDetection() {
    _subscription = accelerometerEventStream(
      samplingPeriod: SensorInterval.gameInterval,
    ).listen(
          (event) {
        if (!_shakeEnabled || _sending) return;

        final acceleration = (event.x * event.x +
            event.y * event.y +
            event.z * event.z);
        final now = DateTime.now();

        // Ngưỡng rung ban đầu, cần thử trên điện thoại thật.
        if (acceleration > 225) {
          if (now.difference(_lastShake).inMilliseconds < 1500) {
            return;
          }

          _lastShake = now;
          _shakeCount++;

          if (_shakeCount >= 3) {
            _shakeCount = 0;

            // Chống gửi SOS liên tục.
            if (now.difference(_lastAutoSos).inSeconds >= 30) {
              _lastAutoSos = now;
              _confirmAutoSos();
            }
          }
        } else if (now.difference(_lastShake).inSeconds > 2) {
          _shakeCount = 0;
        }
      },
      onError: (Object error) {
        if (mounted) {
          _showMessage('Không đọc được cảm biến: $error');
        }
      },
    );
  }

  Future<void> _confirmAutoSos() async {
    if (!mounted || _sending) return;

    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Phát hiện rung mạnh'),
        content: const Text(
          'Mày có cần gửi cảnh báo SOS cho phụ huynh không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Không cần'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Gửi SOS'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (confirmed == true) {
      await _sendSos();
    }
  }

  Future<void> _sendSos() async {
    if (_sending) return;

    setState(() => _sending = true);

    try {
      final result = await SosService.sendSos();

      if (!mounted) return;

      _showMessage(
        result is Map
            ? (result['message'] ?? 'Đã gửi SOS thành công.').toString()
            : 'Đã gửi SOS thành công.',
      );
    } catch (e) {
      if (mounted) {
        _showMessage('Gửi SOS thất bại: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SOS khẩn cấp')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.health_and_safety,
                color: Colors.red,
                size: 90,
              ),
              const SizedBox(height: 16),
              const Text(
                'Khi cần trợ giúp, hãy gửi SOS cho phụ huynh.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 190,
                height: 190,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.red,
                    shape: const CircleBorder(),
                  ),
                  onPressed: _sending ? null : _sendSos,
                  child: _sending
                      ? const CircularProgressIndicator(
                    color: Colors.white,
                  )
                      : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.sos, size: 54),
                      SizedBox(height: 8),
                      Text(
                        'GỬI SOS',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SwitchListTile(
                title: const Text('Phát hiện rung lắc'),
                subtitle: const Text(
                  'Yêu cầu màn hình này đang mở.',
                ),
                value: _shakeEnabled,
                onChanged: (value) {
                  setState(() {
                    _shakeEnabled = value;
                    _shakeCount = 0;
                  });
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
