import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/attendance_session.dart';
import '../models/attendance_record.dart';
import 'token_service.dart';

/// Manages attendance sessions and records in Firestore.
class SessionService {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // ─── Session management ───────────────────────────────────────────

  /// Faculty creates a new attendance session (5-10 min window).
  Future<AttendanceSession> createSession({
    required String classId,
    required String subjectName,
    int durationMinutes = 5,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final now = DateTime.now();
    final secret = TokenService.generateSessionSecret();

    final docRef = _firestore.collection('sessions').doc();

    final session = AttendanceSession(
      sessionId: docRef.id,
      classId: classId,
      subjectName: subjectName,
      facultyId: user.uid,
      startTime: now,
      endTime: now.add(Duration(minutes: durationMinutes)),
      status: 'active',
      hmacSecret: secret,
    );

    await docRef.set(session.toFirestore());
    return session;
  }

  /// Close a session manually (faculty stops early).
  Future<void> closeSession(String sessionId) async {
    await _firestore.collection('sessions').doc(sessionId).update({
      'status': 'closed',
      'endTime': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Get the current active session for a faculty member.
  Future<AttendanceSession?> getActiveSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;

    final query = await _firestore
        .collection('sessions')
        .where('facultyId', isEqualTo: user.uid)
        .where('status', isEqualTo: 'active')
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final session = AttendanceSession.fromFirestore(query.docs.first);
    // Auto-expire if past endTime
    if (DateTime.now().isAfter(session.endTime)) {
      await _firestore
          .collection('sessions')
          .doc(session.sessionId)
          .update({'status': 'expired'});
      return null;
    }
    return session;
  }

  /// Get any active session (for students to find the current window).
  Future<AttendanceSession?> findActiveSession() async {
    final query = await _firestore
        .collection('sessions')
        .where('status', isEqualTo: 'active')
        .orderBy('startTime', descending: true)
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final session = AttendanceSession.fromFirestore(query.docs.first);
    if (DateTime.now().isAfter(session.endTime)) {
      await _firestore
          .collection('sessions')
          .doc(session.sessionId)
          .update({'status': 'expired'});
      return null;
    }
    return session;
  }

  /// Stream of sessions for the faculty (history).
  Stream<List<AttendanceSession>> facultySessions() {
    final user = _auth.currentUser;
    if (user == null) return const Stream.empty();

    return _firestore
        .collection('sessions')
        .where('facultyId', isEqualTo: user.uid)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AttendanceSession.fromFirestore(d)).toList());
  }

  // ─── Attendance records ───────────────────────────────────────────

  /// Mark a student as present (called after HMAC verification + RSSI check).
  Future<void> markPresent({
    required String sessionId,
    required String studentUid,
    required int rssi,
    required int scanCount,
  }) async {
    // Look up student profile
    final studentDoc =
        await _firestore.collection('users').doc(studentUid).get();
    final studentData = studentDoc.data() ?? {};

    final docRef = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(studentUid);

    final existing = await docRef.get();
    if (existing.exists) {
      // Update scan count and RSSI (dwell-time accumulation)
      await docRef.update({
        'scanCount': FieldValue.increment(1),
        'rssi': rssi, // latest RSSI
        'lastSeenAt': Timestamp.fromDate(DateTime.now()),
      });
    } else {
      final record = AttendanceRecord(
        id: studentUid,
        sessionId: sessionId,
        studentId: studentUid,
        studentName: studentData['name'] ?? 'Unknown',
        rollNo: studentData['rollNo'] ?? '',
        status: 'present',
        rssi: rssi,
        scanCount: 1,
        markedAt: DateTime.now(),
      );
      await docRef.set(record.toFirestore());
    }
  }

  /// Edit an attendance record (faculty: present↔absent, mentor: can set OD).
  Future<void> editAttendance({
    required String sessionId,
    required String studentUid,
    required String newStatus,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not authenticated');

    final docRef = _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('attendance')
        .doc(studentUid);

    final doc = await docRef.get();
    final oldStatus = doc.data()?['status'] ?? 'absent';

    await docRef.update({
      'status': newStatus,
      'previousStatus': oldStatus,
      'editedBy': user.uid,
      'editedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Write audit trail
    await _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('audit')
        .add({
      'studentId': studentUid,
      'oldStatus': oldStatus,
      'newStatus': newStatus,
      'editedBy': user.uid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Get attendance records for a session.
  Stream<List<AttendanceRecord>> sessionAttendance(String sessionId) {
    return _firestore
        .collection('sessions')
        .doc(sessionId)
        .collection('attendance')
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => AttendanceRecord.fromFirestore(d)).toList());
  }

  /// Get attendance history for a specific student across all sessions.
  Future<List<Map<String, dynamic>>> studentHistory(String studentUid) async {
    final sessions = await _firestore
        .collection('sessions')
        .orderBy('startTime', descending: true)
        .get();

    final history = <Map<String, dynamic>>[];

    for (final sessionDoc in sessions.docs) {
      final session = AttendanceSession.fromFirestore(sessionDoc);
      final attendanceDoc = await _firestore
          .collection('sessions')
          .doc(session.sessionId)
          .collection('attendance')
          .doc(studentUid)
          .get();

      history.add({
        'session': session,
        'status': attendanceDoc.exists
            ? attendanceDoc.data()?['status'] ?? 'absent'
            : 'absent',
        'record': attendanceDoc.exists
            ? AttendanceRecord.fromFirestore(attendanceDoc)
            : null,
      });
    }
    return history;
  }

  /// Calculate attendance percentage for a student in a specific subject.
  Future<double> attendancePercentage(
      String studentUid, String subjectName) async {
    final sessions = await _firestore
        .collection('sessions')
        .where('subjectName', isEqualTo: subjectName)
        .get();

    if (sessions.docs.isEmpty) return 0.0;

    int totalSessions = sessions.docs.length;
    int presentCount = 0;

    for (final sessionDoc in sessions.docs) {
      final attendanceDoc = await _firestore
          .collection('sessions')
          .doc(sessionDoc.id)
          .collection('attendance')
          .doc(studentUid)
          .get();

      if (attendanceDoc.exists) {
        final status = attendanceDoc.data()?['status'];
        if (status == 'present' || status == 'od') {
          presentCount++;
        }
      }
    }
    return (presentCount / totalSessions) * 100;
  }
}
