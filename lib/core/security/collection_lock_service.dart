import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../storage/secure_storage.dart';

final collectionLockServiceProvider = Provider<CollectionLockService>((ref) {
  return const CollectionLockService();
});

class CollectionLockService {
  const CollectionLockService();

  static const _pinSaltKey = 'collection_lock_pin_salt_v1';
  static const _pinHashKey = 'collection_lock_pin_hash_v1';

  static final RegExp _pinRegex = RegExp(r'^\d{4}$');

  bool isValidPin(String pin) => _pinRegex.hasMatch(pin);

  Future<bool> hasPin() async {
    final salt = await SecureStorage.readValue(_pinSaltKey);
    final hash = await SecureStorage.readValue(_pinHashKey);
    return (salt?.isNotEmpty ?? false) && (hash?.isNotEmpty ?? false);
  }

  Future<void> setPin(String pin4) async {
    if (!isValidPin(pin4)) {
      throw ArgumentError('PIN must be exactly 4 digits.');
    }
    final salt = _randomSalt();
    final hash = _hashPin(pin4, salt);
    await SecureStorage.writeValue(key: _pinSaltKey, value: salt);
    await SecureStorage.writeValue(key: _pinHashKey, value: hash);
  }

  Future<bool> verifyPin(String pin4) async {
    if (!isValidPin(pin4)) return false;
    final salt = await SecureStorage.readValue(_pinSaltKey);
    final expectedHash = await SecureStorage.readValue(_pinHashKey);
    if (salt == null || salt.isEmpty || expectedHash == null || expectedHash.isEmpty) {
      return false;
    }
    final actualHash = _hashPin(pin4, salt);
    return actualHash == expectedHash;
  }

  Future<void> resetPin() async {
    await SecureStorage.deleteValue(_pinSaltKey);
    await SecureStorage.deleteValue(_pinHashKey);
  }

  String _randomSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPin(String pin, String salt) {
    return sha256.convert(utf8.encode('$salt:$pin')).toString();
  }
}
