import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/models/user_model.dart';
import '../data/repositories/same_energy_repository_impl.dart';
import 'auth_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.read(sameEnergyRepositoryProvider)),
);

final authStateProvider = StateNotifierProvider<AuthNotifier, UserState>((ref) {
  return AuthNotifier(ref.read(authRepositoryProvider));
});

class AuthNotifier extends StateNotifier<UserState> {
  final AuthRepository _repository;

  /// A [ValueNotifier] that fires whenever the auth state changes.
  /// GoRouter uses this as `refreshListenable` to re-evaluate redirects.
  final ValueNotifier<int> authChangeNotifier = ValueNotifier<int>(0);

  /// Whether the initial credential load from storage has completed.
  bool _initialized = false;
  bool get isInitialized => _initialized;

  AuthNotifier(this._repository)
    : super(const UserState(userId: '', token: '')) {
    _init();
  }

  Future<void> _init() async {
    state = await _repository.getCurrentUser();
    _initialized = true;
    _notifyRouterChange();
  }

  Future<void> login({
    required String email,
    required String password,
    bool createIfMissing = true,
  }) async {
    state = await _repository.login(
      email: email,
      password: password,
      createIfMissing: createIfMissing,
    );
    _notifyRouterChange();
  }

  Future<void> createAccount({
    required String email,
    required String password,
  }) async {
    state = await _repository.createAccount(email: email, password: password);
    _notifyRouterChange();
  }

  Future<void> logout() async {
    state = await _repository.logout();
    _notifyRouterChange();
  }

  bool get isAuthenticated => state.isAuthenticated;

  void _notifyRouterChange() {
    authChangeNotifier.value++;
  }

  @override
  void dispose() {
    authChangeNotifier.dispose();
    super.dispose();
  }
}
