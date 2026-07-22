class BleConstants {
  /// Custom service UUID for this app. The faculty scanner filters on this
  /// so it ignores unrelated BLE devices nearby (headphones, smartwatches, etc).
  static const String serviceUuid = "0000b81d-0000-1000-8000-00805f9b34fb";

  /// Manufacturer ID used to embed the student ID inside the advertisement
  /// payload. 0xFFFF is reserved for prototyping/testing use — swap this
  /// for a registered manufacturer ID before any real deployment.
  static const int manufacturerId = 0xFFFF;
}
