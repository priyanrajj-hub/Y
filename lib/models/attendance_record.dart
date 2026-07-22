import 'package:cloud_firestore/cloud_firestore.dart';

/// A single attendance record — one student in one session.
class AttendanceRecord {
  final String id;
  final String sessionId;
  final String studentId; // Firebase UID
  final String studentName;
  final String rollNo;
  final String status; // 'present', 'absent', 'od'
  final int rssi;
  final int scanCount; // number of BLE scan hits (dwell-time check)
  final DateTime markedAt;
  final String? editedBy;
  final String? previousStatus;
  final DateTime? editedAt;

  AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.status,
    required this.rssi,
    required this.scanCount,
    required this.markedAt,
    this.editedBy,
    this.previousStatus,
    this.editedAt,
  });

  factory AttendanceRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceRecord(
      id: doc.id,
      sessionId: data['sessionId'] ?? '',
      studentId: data['studentId'] ?? '',
      studentName: data['studentName'] ?? '',
      rollNo: data['rollNo'] ?? '',
      status: data['status'] ?? 'absent',
      rssi: data['rssi'] ?? 0,
      scanCount: data['scanCount'] ?? 0,
      markedAt: (data['markedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      editedBy: data['editedBy'],
      previousStatus: data['previousStatus'],
      editedAt: (data['editedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'sessionId': sessionId,
        'studentId': studentId,
        'studentName': studentName,
        'rollNo': rollNo,
        'status': status,
        'rssi': rssi,
        'scanCount': scanCount,
        'markedAt': Timestamp.fromDate(markedAt),
        if (editedBy != null) 'editedBy': editedBy,
        if (previousStatus != null) 'previousStatus': previousStatus,
        if (editedAt != null) 'editedAt': Timestamp.fromDate(editedAt!),
      };
}
