import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';

/// Central auth service — wraps Firebase Auth + device biometrics.
///
/// Login flow: credential check → biometric check → session.
/// The biometric step uses [local_auth] which never transmits
/// biometric data off-device (Android BiometricPrompt / iOS Face ID).
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  /// The college email domain that is allowed to register / log in.
  /// Change this to your institution's domain before deploying.
  static const String collegeDomain = '@college.edu.in';

  // ─── Getters ──────────────────────────────────────────────────────

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Domain validation ────────────────────────────────────────────

  /// Returns `true` if [email] belongs to the allowed college domain.
  bool isCollegeDomain(String email) {
    return email.trim().toLowerCase().endsWith(collegeDomain);
  }

  // ─── Biometric helpers ────────────────────────────────────────────

  /// Whether the device has any enrolled biometrics (fingerprint, face, etc.).
  Future<bool> isBiometricAvailable() async {
    final canCheck = await _localAuth.canCheckBiometrics;
    final isDeviceSupported = await _localAuth.isDeviceSupported();
    return canCheck && isDeviceSupported;
  }

  /// Prompts the user for biometric authentication.
  /// Returns `true` only if the check succeeds.
  Future<bool> performBiometricAuth() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Confirm it\'s you to continue',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  // ─── Sign-in (credential + biometric) ─────────────────────────────

  /// Full login flow:
  /// 1. Validate email domain.
  /// 2. Firebase `signInWithEmailAndPassword`.
  /// 3. Biometric prompt via `local_auth`.
  /// 4. Return the [User] only if ALL steps succeed.
  ///
  /// Throws [AuthException] with a user-friendly message on failure.
  Future<User> signIn(String email, String password) async {
    // 1. Domain check
    if (!isCollegeDomain(email)) {
      throw AuthException('Only $collegeDomain emails are allowed.');
    }

    // 2. Firebase credential check
    UserCredential credential;
    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }

    // 3. Check account verification status (from Firestore — caller handles)
    //    The login_screen checks Firestore 'status' field after this returns.

    // 4. Biometric second factor
    final bioAvailable = await isBiometricAvailable();
    if (!bioAvailable) {
      await _auth.signOut();
      throw AuthException(
        'Biometric authentication is required but not available on this device. '
        'Please enroll a fingerprint or face ID in your device settings.',
      );
    }

    final bioSuccess = await performBiometricAuth();
    if (!bioSuccess) {
      await _auth.signOut();
      throw AuthException(
        'Biometric verification failed. You must pass the biometric check to continue.',
      );
    }

    return credential.user!;
  }

  // ─── Registration ─────────────────────────────────────────────────

  /// Creates a Firebase Auth account.  Does NOT set up Firestore profile
  /// or upload photo — that is handled by the register screen after this
  /// returns a UID.
  Future<User> register(String email, String password) async {
    if (!isCollegeDomain(email)) {
      throw AuthException('Only $collegeDomain emails are allowed.');
    }

    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return credential.user!;
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e.code));
    }
  }

  // ─── Sign-out ─────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ─── Helpers ──────────────────────────────────────────────────────

  String _mapFirebaseError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found for this email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect password. Please try again.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'invalid-email':
        return 'The email address is not valid.';
      default:
        return 'Authentication failed ($code). Please try again.';
    }
  }
}

/// Custom exception for user-facing auth errors.
class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => message;
}
