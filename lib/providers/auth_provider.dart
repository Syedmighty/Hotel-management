import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/user_dao.dart';
import 'package:hotel_inventory_management/main.dart';
import 'package:hotel_inventory_management/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

// SharedPreferences provider
final sharedPreferencesProvider = FutureProvider<SharedPreferences>((ref) async {
  return await SharedPreferences.getInstance();
});

// UserDao provider
final userDaoProvider = Provider<UserDao>((ref) {
  final database = ref.watch(databaseProvider);
  return UserDao(database);
});

// AuthService provider
final authServiceProvider = Provider<AuthService>((ref) {
  final userDao = ref.watch(userDaoProvider);
  final prefs = ref.watch(sharedPreferencesProvider).value;

  if (prefs == null) {
    throw Exception('SharedPreferences not initialized');
  }

  return AuthService(userDao, prefs);
});

// Auth state notifier
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;

  AuthNotifier(this._authService) : super(const AsyncValue.loading()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = const AsyncValue.loading();
    try {
      await _authService.initialize();
      state = AsyncValue.data(_authService.currentUser);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<LoginResult> login(String username, String password) async {
    final result = await _authService.login(username, password);
    if (result.success) {
      state = AsyncValue.data(result.user);
    }
    return result;
  }

  Future<void> logout() async {
    await _authService.logout();
    state = const AsyncValue.data(null);
  }

  bool hasPermission(String permission) {
    return _authService.hasPermission(permission);
  }

  bool hasRole(String role) {
    return _authService.hasRole(role);
  }

  User? get currentUser => _authService.currentUser;
  bool get isAuthenticated => _authService.isAuthenticated;
}

// Auth state provider
final authNotifierProvider = StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authNotifierProvider);
  return authState.value;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});

final userRoleProvider = Provider<String?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});
