import 'package:local_auth/local_auth.dart';

class AuthService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> authenticate() async {
    try {
      final canCheck =
          await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
      if (!canCheck) return false;
      return await _auth.authenticate(
        localizedReason: 'Scan fingerprint to unlock EasyRent Tracker',
      );
    } catch (_) {
      return false;
    }
  }
}
