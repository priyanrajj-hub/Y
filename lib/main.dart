import 'package:flutter/material.dart';
import 'screens/role_select_screen.dart';

void main() {
  runApp(const AttendanceBleTestApp());
}

class AttendanceBleTestApp extends StatelessWidget {
  const AttendanceBleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Attendance Test',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        useMaterial3: true,
      ),
      home: const RoleSelectScreen(),
    );
  }
}
