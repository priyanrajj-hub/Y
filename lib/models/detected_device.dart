class DetectedDevice {
  final String studentId;
  int rssi;
  DateTime lastSeen;

  DetectedDevice({
    required this.studentId,
    required this.rssi,
    required this.lastSeen,
  });
}
