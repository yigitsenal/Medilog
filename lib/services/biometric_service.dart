import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _localAuth = LocalAuthentication();

  // Biyometrik kimlik doğrulamanın kullanılabilir olup olmadığını kontrol eder
  Future<bool> isAvailable() async {
    bool canAuthenticateWithBiometrics;
    bool canAuthenticate;

    try {
      canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      canAuthenticate = await _localAuth.isDeviceSupported();
      
      return canAuthenticateWithBiometrics && canAuthenticate;
    } on PlatformException catch (_) {
      return false;
    }
  }

  // Kullanılabilir biyometrik kimlik doğrulama tiplerini getirir
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException catch (_) {
      return [];
    }
  }

  // Biyometrik kimlik doğrulama işlemini başlatır
  Future<bool> authenticate({required String reason}) async {
    bool authenticated = false;

    try {
      authenticated = await _localAuth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
      return authenticated;
    } on PlatformException catch (_) {
      return false;
    }
  }
}