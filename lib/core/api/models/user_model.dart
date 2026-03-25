class UserState {
  final String userId;
  final String token;
  final bool isAuthenticated;
  bool get isLoggedIn => isAuthenticated;

  const UserState({
    required this.userId,
    required this.token,
    this.isAuthenticated = false,
  });

  const UserState.anonymous({required this.userId})
    : token = '',
      isAuthenticated = false;

  const UserState.authenticated({required this.userId, required this.token})
    : isAuthenticated = true;

  factory UserState.fromJson(Map<String, dynamic> json) {
    final userId = json['user_id']?.toString() ?? '';
    final token = json['token']?.toString() ?? '';
    return UserState(
      userId: userId,
      token: token,
      isAuthenticated: token.isNotEmpty && !userId.startsWith('anonymous@@'),
    );
  }

  Map<String, dynamic> toJson() => {'user_id': userId, 'token': token};

  UserState copyWith({String? userId, String? token, bool? isAuthenticated}) {
    return UserState(
      userId: userId ?? this.userId,
      token: token ?? this.token,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }
}
