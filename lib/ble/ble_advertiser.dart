import 'dart:typed_data';
import 'package:flutter_ble_peripheral/flutter_ble_peripheral.dart';
import 'ble_constants.dart';

/// Handles BLE advertising from the student side.
/// The student's phone broadcasts its ID via manufacturer data so the
/// faculty phone can pick it up during a scan.
class BleAdvertiser {
  final FlutterBlePeripheral _peripheral = FlutterBlePeripheral();

  Future<void> startAdvertising(String studentId) async {
    final data = AdvertiseData(
      serviceUuid: BleConstants.serviceUuid,
      manufacturerId: BleConstants.manufacturerId,
      manufacturerData: Uint8List.fromList(studentId.codeUnits),
    );

    await _peripheral.start(advertiseData: data);
  }

  Future<void> stopAdvertising() async {
    await _peripheral.stop();
  }

  /// Start advertising with a pre-built signed payload (Phase 2+).
  /// Used by [StudentBroadcastScreen] to send HMAC-signed manufacturer data.
  Future<void> startAdvertisingWithPayload(Uint8List payload) async {
    final data = AdvertiseData(
      serviceUuid: BleConstants.serviceUuid,
      manufacturerId: BleConstants.manufacturerId,
      manufacturerData: payload,
    );
    await _peripheral.start(advertiseData: data);
  }

  Future<bool> isAdvertising() async {
    return await _peripheral.isAdvertising;
  }
}
