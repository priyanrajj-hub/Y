import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/role_select_screen.dart';
import 'screens/admin_approval_screen.dart';

/// NOTE: After running `flutterfire configure`, import firebase_options.dart:
/// import 'firebase_options.dart';
/// and pass `DefaultFirebaseOptions.currentPlatform` to Firebase.initializeApp().

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase.
  // TODO: After running `flutterfire configure`, change this to:
  //   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Firebase.initializeApp();

  runApp(const AttendanceBleTestApp());
}

class AttendanceBleTestApp extends StatelessWidget {
  const AttendanceBleTestApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BLE Attendance',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.indigo,
        useMaterial3: true,
        brightness: Brightness.dark,
      ),
      themeMode: ThemeMode.system,
      initialRoute: '/login',
      routes: {
        '/login': (_) => const LoginScreen(),
        '/register': (_) => const RegisterScreen(),
        '/role-select': (_) => const RoleSelectScreen(),
        '/admin': (_) => const AdminApprovalScreen(),
      },
    );
  }
}
