import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../ble/ble_advertiser.dart';

class StudentScreen extends StatefulWidget {
  const StudentScreen({super.key});

  @override
  State<StudentScreen> createState() => _StudentScreenState();
}

class _StudentScreenState extends State<StudentScreen>
    with WidgetsBindingObserver {
  final BleAdvertiser _advertiser = BleAdvertiser();
  final TextEditingController _idController =
      TextEditingController(text: 'STU001');

  bool _isBroadcasting = false;
  String _statusMessage = 'Enter your student ID and tap Start';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _advertiser.stopAdvertising();
    _idController.dispose();
    super.dispose();
  }

  // Core requirement: if the student leaves this app (switches apps,
  // locks the screen, etc.) while broadcasting, the session terminates
  // immediately rather than continuing in the background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isBroadcasting && state != AppLifecycleState.resumed) {
      _terminateSession(reason: 'Session terminated — app was backgrounded.');
    }
  }

  Future<bool> _ensurePermissions() async {
    final statuses = await [
      Permission.bluetoothAdvertise,
      Permission.bluetoothConnect,
      Permission.locationWhenInUse,
    ].request();

    return statuses.values.every((status) => status.isGranted);
  }

  Future<void> _startBroadcasting() async {
    final studentId = _idController.text.trim();
    if (studentId.isEmpty) {
      setState(() => _statusMessage = 'Please enter a student ID first.');
      return;
    }

    final granted = await _ensurePermissions();
    if (!granted) {
      setState(() {
        _statusMessage =
            'Bluetooth/location permissions are required to broadcast.';
      });
      return;
    }

    await _advertiser.startAdvertising(studentId);
    setState(() {
      _isBroadcasting = true;
      // Local-only confirmation for this test phase (Option 1): confirms
      // the phone is actively broadcasting, not that it was actually
      // received by the faculty device. True acknowledgment is Phase 2.
      _statusMessage = 'UUID sent successfully';
    });
  }

  Future<void> _terminateSession({required String reason}) async {
    await _advertiser.stopAdvertising();
    if (!mounted) return;
    setState(() {
      _isBroadcasting = false;
      _statusMessage = reason;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Student — Broadcast')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _idController,
              enabled: !_isBroadcasting,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isBroadcasting ? null : _startBroadcasting,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Start Broadcasting'),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _isBroadcasting
                  ? () => _terminateSession(reason: 'Broadcasting stopped.')
                  : null,
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Stop'),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              _statusMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _isBroadcasting ? Colors.green[700] : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
