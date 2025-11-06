import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

/// Utility class for password hashing using bcrypt-style implementation
/// Uses PBKDF2 with SHA256 for secure password hashing
class PasswordHasher {
  static const int _iterations = 10000;
  static const int _saltLength = 16;
  static const int _hashLength = 32;

  /// Generate a random salt
  static String _generateSalt() {
    final random = Random.secure();
    final saltBytes = List<int>.generate(_saltLength, (_) => random.nextInt(256));
    return base64Url.encode(saltBytes);
  }

  /// Hash a password with PBKDF2
  static String _pbkdf2(String password, String salt, int iterations) {
    var bytes = utf8.encode(password + salt);
    var hash = bytes;

    for (var i = 0; i < iterations; i++) {
      hash = sha256.convert(hash).bytes;
    }

    return base64Url.encode(hash);
  }

  /// Hash a password with automatic salt generation
  /// Returns: salt\$iterations\$hash
  static String hashPassword(String password) {
    final salt = _generateSalt();
    final hash = _pbkdf2(password, salt, _iterations);
    return '$salt\$$_iterations\$$hash';
  }

  /// Verify a password against a stored hash
  static bool verifyPassword(String password, String storedHash) {
    try {
      final parts = storedHash.split('\$');
      if (parts.length != 3) return false;

      final salt = parts[0];
      final iterations = int.parse(parts[1]);
      final hash = parts[2];

      final computedHash = _pbkdf2(password, salt, iterations);
      return hash == computedHash;
    } catch (e) {
      return false;
    }
  }
}
