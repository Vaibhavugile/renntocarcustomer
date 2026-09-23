import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();

  static final AuthService instance =
      AuthService._();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: 'asia-south1',
  );

  // ============================================================
  // SEND MSG91 WHATSAPP OTP
  // ============================================================

  Future<Map<String, dynamic>> sendOtp({
    required String tenantId,
    required String phoneNumber,
  }) async {
    try {
      final callable =
          _functions.httpsCallable(
        'sendMsg91Otp',
      );

      final result =
          await callable.call({
        'tenantId':
            tenantId,

        'phoneNumber':
            phoneNumber,
      });

      if (result.data == null) {
        throw const AuthServiceException(
          'Empty response from OTP service.',
        );
      }

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      if (data['success'] != true) {
        throw const AuthServiceException(
          'Unable to send OTP.',
        );
      }

      return data;
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.message ??
            'Unable to send OTP. Please try again.',
      );
    } catch (error) {
      if (error is AuthServiceException) {
        rethrow;
      }

      throw const AuthServiceException(
        'Unable to send OTP. Please try again.',
      );
    }
  }

  // ============================================================
  // VERIFY MSG91 WHATSAPP OTP
  // ============================================================
  //
  // Backend function:
  //
  // verifyMsg91Otp
  //
  // Backend:
  //
  // 1. Validates tenant
  // 2. Validates phone
  // 3. Validates OTP
  // 4. Checks expiry
  // 5. Checks attempts
  // 6. Finds existing Firebase user
  // 7. Creates Firebase user if required
  // 8. Creates Firebase Custom Token
  //
  // Flutter:
  //
  // signInWithCustomToken()
  //
  // ============================================================

  Future<bool> verifyOtp({
    required String tenantId,
    required String phoneNumber,
    required String otp,
  }) async {
    try {
      final callable =
          _functions.httpsCallable(
        'verifyMsg91Otp',
      );

      final result =
          await callable.call({
        'tenantId':
            tenantId,

        'phoneNumber':
            phoneNumber,

        'otp':
            otp,
      });

      if (result.data == null) {
        throw const AuthServiceException(
          'Empty response from OTP verification service.',
        );
      }

      final data =
          Map<String, dynamic>.from(
        result.data as Map,
      );

      final success =
          data['success'] == true;

      if (!success) {
        throw const AuthServiceException(
          'Unable to verify OTP.',
        );
      }

      final customToken =
          data['customToken'];

      if (customToken is! String ||
          customToken.trim().isEmpty) {
        throw const AuthServiceException(
          'Authentication token was not received.',
        );
      }

      // --------------------------------------------------------
      // SIGN IN USING FIREBASE CUSTOM TOKEN
      // --------------------------------------------------------

      await _auth.signInWithCustomToken(
        customToken,
      );

      // --------------------------------------------------------
      // VERIFY FIREBASE SESSION
      // --------------------------------------------------------

      final user =
          _auth.currentUser;

      if (user == null) {
        throw const AuthServiceException(
          'Firebase authentication could not be completed.',
        );
      }

      return true;
    } on FirebaseFunctionsException catch (error) {
      // Preserve the actual backend error.
      //
      // Examples:
      //
      // Invalid OTP
      // OTP expired
      // Too many attempts
      // OTP not found
      // Tenant not found
      //
      throw AuthServiceException(
        error.message ??
            'Unable to verify OTP. Please try again.',
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        error.message ??
            'Firebase authentication failed. Please try again.',
      );
    } catch (error) {
      if (error is AuthServiceException) {
        rethrow;
      }

      throw const AuthServiceException(
        'Unable to verify OTP. Please try again.',
      );
    }
  }

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get currentUser =>
      _auth.currentUser;

  // ============================================================
  // CURRENT UID
  // ============================================================

  String? get currentUid =>
      _auth.currentUser?.uid;

  // ============================================================
  // CURRENT PHONE
  // ============================================================

  String? get currentPhoneNumber =>
      _auth.currentUser?.phoneNumber;

  // ============================================================
  // IS LOGGED IN
  // ============================================================

  bool get isLoggedIn =>
      _auth.currentUser != null;

  // ============================================================
  // LOGOUT
  // ============================================================

  Future<void> logout() async {
    await _auth.signOut();
  }
}


// ============================================================
// AUTH SERVICE EXCEPTION
// ============================================================

class AuthServiceException
    implements Exception {
  final String message;

  const AuthServiceException(
    this.message,
  );

  @override
  String toString() =>
      message;
}