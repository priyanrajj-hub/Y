import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a faculty-created attendance session (5-10 min window).
class AttendanceSession {
  final String sessionId;
  final String classId;
  final String subjectName;
  final String facultyId;
  final DateTime startTime;
  final DateTime endTime;
  final String status; // 'active', 'closed', 'expired'
  final String hmacSecret; // server-side secret for token rotation

  AttendanceSession({
    required this.sessionId,
    required this.classId,
    required this.subjectName,
    required this.facultyId,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.hmacSecret,
  });

  factory AttendanceSession.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AttendanceSession(
      sessionId: doc.id,
      classId: data['classId'] ?? '',
      subjectName: data['subjectName'] ?? '',
      facultyId: data['facultyId'] ?? '',
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      status: data['status'] ?? 'closed',
      hmacSecret: data['hmacSecret'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'classId': classId,
        'subjectName': subjectName,
        'facultyId': facultyId,
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'status': status,
        'hmacSecret': hmacSecret,
      };

  bool get isActive => status == 'active' && DateTime.now().isBefore(endTime);

  /// Remaining seconds in this window.
  int get remainingSeconds =>
      isActive ? endTime.difference(DateTime.now()).inSeconds : 0;
}
