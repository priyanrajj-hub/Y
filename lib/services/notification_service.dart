import 'package:cloud_firestore/cloud_firestore.dart';

/// Notification service — writes notification records to Firestore.
///
/// In production, a Cloud Function triggers on writes to the
/// `notifications` collection and sends emails via SendGrid/SES.
/// This client-side service creates the notification records.
class NotificationService {
  final _firestore = FirebaseFirestore.instance;

  /// Record an attendance notification for a student (and optionally parent).
  ///
  /// A Cloud Function should watch the `notifications` collection and
  /// send the actual emails. This method only writes the intent.
  Future<void> notifyAttendance({
    required String studentUid,
    required String studentEmail,
    String? parentEmail,
    required String subjectName,
    required String classId,
    required String status, // 'present', 'absent'
    required DateTime sessionTime,
  }) async {
    final notification = {
      'type': 'attendance',
      'studentUid': studentUid,
      'recipients': [
        studentEmail,
        if (parentEmail != null && parentEmail.isNotEmpty) parentEmail,
      ],
      'subject':
          'Attendance ${status == 'present' ? 'Confirmed' : 'Missed'}: $subjectName',
      'body': _buildEmailBody(
        subjectName: subjectName,
        classId: classId,
        status: status,
        sessionTime: sessionTime,
      ),
      'status': 'pending', // Cloud Function picks this up
      'createdAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('notifications').add(notification);
  }

  /// Build the email body text.
  String _buildEmailBody({
    required String subjectName,
    required String classId,
    required String status,
    required DateTime sessionTime,
  }) {
    final timeStr =
        '${sessionTime.day}/${sessionTime.month}/${sessionTime.year} '
        '${sessionTime.hour}:${sessionTime.minute.toString().padLeft(2, '0')}';

    if (status == 'present') {
      return '''
Attendance Confirmed

Subject: $subjectName
Class: $classId
Time: $timeStr
Status: PRESENT ✓

Your attendance has been successfully recorded via BLE proximity detection.
''';
    } else {
      return '''
Attendance Missed

Subject: $subjectName
Class: $classId
Time: $timeStr
Status: ABSENT ✗

You were not detected during the attendance window for this session.
If you believe this is an error, please contact your faculty.
''';
    }
  }

  /// Get notification history for a student.
  Stream<List<Map<String, dynamic>>> studentNotifications(String studentUid) {
    return _firestore
        .collection('notifications')
        .where('studentUid', isEqualTo: studentUid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList());
  }
}
