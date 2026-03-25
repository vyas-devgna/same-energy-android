import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../api/models/user_model.dart';
import '../domain/repositories/same_energy_repository.dart';
import '../storage/secure_storage.dart';
import '../storage/preferences_storage.dart';

class AuthRepository {
  AuthRepository(this._repository);

  final SameEnergyRepository _repository;

  Future<UserState> getCurrentUser() async {
    final hasCredentials = await SecureStorage.hasCredentials();
    if (hasCredentials) {
      final userId = await SecureStorage.getUserId();
      final token = await SecureStorage.getToken();
      if (userId != null && token != null && token.isNotEmpty) {
        return UserState.authenticated(userId: userId, token: token);
      }
    }
    return UserState.anonymous(userId: PreferencesStorage.getAnonymousUserId());
  }

  Future<UserState> login({
    required String email,
    required String password,
    bool createIfMissing = true,
  }) async {
    final anonymousUserId = PreferencesStorage.getAnonymousUserId();
    final passwordHash = sha1.convert(utf8.encode(password)).toString();

    try {
      if (createIfMissing) {
        await _repository.createUser(userId: email, passwordHash: passwordHash);
      }

      final loginData = await _repository.login(
        userId: email,
        passwordHash: passwordHash,
      );
      if (loginData != null && loginData.token.isNotEmpty) {
        await SecureStorage.saveCredentials(loginData.userId, loginData.token);
        return UserState.authenticated(
          userId: loginData.userId,
          token: loginData.token,
        );
      }
    } catch (_) {}

    try {
      final legacy = await _repository.legacyEmailLogin(
        email: email,
        anonymousUserId: anonymousUserId,
      );
      if (legacy != null && legacy.token.isNotEmpty) {
        await SecureStorage.saveCredentials(legacy.userId, legacy.token);
        return UserState.authenticated(
          userId: legacy.userId,
          token: legacy.token,
        );
      }
    } catch (_) {}

    try {
      final settings = await _repository.readSettings(
        UserState.anonymous(userId: anonymousUserId),
      );
      final token = settings['token']?.toString();
      if (token != null && token.isNotEmpty) {
        await SecureStorage.saveCredentials(email, token);
        return UserState.authenticated(userId: email, token: token);
      }
    } catch (_) {}

    return UserState.anonymous(userId: anonymousUserId);
  }

  Future<UserState> createAccount({
    required String email,
    required String password,
  }) async {
    final passwordHash = sha1.convert(utf8.encode(password)).toString();
    try {
      final data = await _repository.createUser(
        userId: email,
        passwordHash: passwordHash,
      );
      if (data != null && data.token.isNotEmpty) {
        await SecureStorage.saveCredentials(data.userId, data.token);
        return UserState.authenticated(userId: data.userId, token: data.token);
      }
      return await login(
        email: email,
        password: password,
        createIfMissing: false,
      );
    } catch (_) {
      return UserState.anonymous(
        userId: PreferencesStorage.getAnonymousUserId(),
      );
    }
  }

  Future<UserState> logout() async {
    await SecureStorage.clearCredentials();
    return UserState.anonymous(userId: PreferencesStorage.getAnonymousUserId());
  }

  Future<Map<String, dynamic>> readSettings(UserState user) async {
    try {
      return await _repository.readSettings(user);
    } catch (_) {}
    return {};
  }
}
