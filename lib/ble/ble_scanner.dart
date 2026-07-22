import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'ble_constants.dart';

/// Handles BLE scanning from the faculty side.
/// Filters for the app's service UUID and decodes the student ID
/// out of the manufacturer data of each matching advertisement.
class BleScanner {
  Stream<List<ScanResult>> get scanResults => FlutterBluePlus.scanResults;

  Future<void> startScan() async {
    await FlutterBluePlus.startScan(
      withServices: [Guid(BleConstants.serviceUuid)],
      continuousUpdates: true,
    );
  }

  Future<void> stopScan() async {
    await FlutterBluePlus.stopScan();
  }

  /// Extracts the student ID string from a scan result's manufacturer data.
  /// Returns null if this device isn't broadcasting in our expected format.
  String? decodeStudentId(ScanResult result) {
    final manufacturerData = result.advertisementData.manufacturerData;
    final bytes = manufacturerData[BleConstants.manufacturerId];
    if (bytes == null || bytes.isEmpty) return null;
    try {
      return utf8.decode(bytes);
    } catch (_) {
      return null;
    }
  }
}
