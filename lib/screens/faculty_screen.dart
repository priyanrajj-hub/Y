import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_scanner.dart';
import '../models/detected_device.dart';

class FacultyScreen extends StatefulWidget {
  const FacultyScreen({super.key});

  @override
  State<FacultyScreen> createState() => _FacultyScreenState();
}

class _FacultyScreenState extends State<FacultyScreen> {
  final BleScanner _scanner = BleScanner();
  final Map<String, DetectedDevice> _detected = {};
  StreamSubscription<List<ScanResult>>? _subscription;
  bool _isScanning = false;

  @override
  void dispose() {
    _subscription?.cancel();
    _scanner.stopScan();
    super.dispose();
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _startScan() async {
    final granted = await _ensurePermissions();
    if (!granted) return;

    setState(() => _isScanning = true);

    _subscription = _scanner.scanResults.listen((results) {
      for (final result in results) {
        final studentId = _scanner.decodeStudentId(result);
        if (studentId == null) continue;

        setState(() {
          _detected[studentId] = DetectedDevice(
            studentId: studentId,
            rssi: result.rssi,
            lastSeen: DateTime.now(),
          );
        });
      }
    });

    await _scanner.startScan();
  }

  Future<void> _stopScan() async {
    await _scanner.stopScan();
    await _subscription?.cancel();
    setState(() => _isScanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final devices = _detected.values.toList()
      ..sort((a, b) => b.rssi.compareTo(a.rssi));

    return Scaffold(
      appBar: AppBar(title: const Text('Faculty — Scan')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _isScanning ? _stopScan : _startScan,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(_isScanning ? 'Stop Scanning' : 'Start Scanning'),
              ),
            ),
          ),
          if (_isScanning)
            const Padding(
              padding: EdgeInsets.only(bottom: 8.0),
              child: Text('Scanning for nearby students...'),
            ),
          Expanded(
            child: devices.isEmpty
                ? const Center(child: Text('No students detected yet.'))
                : ListView.builder(
                    itemCount: devices.length,
                    itemBuilder: (context, index) {
                      final d = devices[index];
                      final secondsAgo =
                          DateTime.now().difference(d.lastSeen).inSeconds;
                      return ListTile(
                        leading: const Icon(Icons.bluetooth_connected),
                        title: Text(d.studentId),
                        subtitle: Text('Last seen ${secondsAgo}s ago'),
                        trailing: Text('${d.rssi} dBm'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
