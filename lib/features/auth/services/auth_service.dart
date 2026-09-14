import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<void> sendOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String message) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,

        verificationCompleted: (
          PhoneAuthCredential credential,
        ) async {
          await _auth.signInWithCredential(credential);
        },

        verificationFailed: (
          FirebaseAuthException error,
        ) {
          onError(
            error.message ?? 'Unable to send OTP',
          );
        },

        codeSent: (
          String verificationId,
          int? resendToken,
        ) {
          onCodeSent(verificationId);
        },

        codeAutoRetrievalTimeout: (
          String verificationId,
        ) {},
      );
    } catch (e) {
      onError(
        'Something went wrong. Please try again.',
      );
    }
  }

  Future<bool> verifyOtp({
    required String verificationId,
    required String otp,
  }) async {
    try {
      final credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await _auth.signInWithCredential(
        credential,
      );

      return true;
    } catch (e) {
      return false;
    }
  }

  User? get currentUser => _auth.currentUser;

  Future<void> logout() async {
    await _auth.signOut();
  }
}