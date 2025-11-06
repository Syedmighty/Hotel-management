import 'dart:convert';
import 'package:hotel_inventory_management/db/app_database.dart';
import 'package:hotel_inventory_management/db/daos/user_dao.dart';
import 'package:hotel_inventory_management/utils/password_hasher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AuthService {
  final UserDao _userDao;
  final SharedPreferences _prefs;
  User? _currentUser;

  AuthService(this._userDao, this._prefs);

  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  /// Initialize auth state from stored session
  Future<void> initialize() async {
    final userJson = _prefs.getString('current_user');
    if (userJson != null) {
      try {
        final userData = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User(
          userId: userData['userId'] as String,
          username: userData['username'] as String,
          passwordHash: userData['passwordHash'] as String,
          role: userData['role'] as String,
          permissions: userData['permissions'] as String,
          deviceId: userData['deviceId'] as String?,
          isActive: userData['isActive'] as bool,
          createdAt: DateTime.parse(userData['createdAt'] as String),
          lastLogin: userData['lastLogin'] != null
              ? DateTime.parse(userData['lastLogin'] as String)
              : null,
          lastModified: DateTime.parse(userData['lastModified'] as String),
        );
      } catch (e) {
        // Invalid stored session, clear it
        await _clearSession();
      }
    }
  }

  /// Login with username and password
  Future<LoginResult> login(String username, String password) async {
    try {
      // Get user by username
      final user = await _userDao.getUserByUsername(username);

      if (user == null) {
        await _userDao.logAuthEvent(
          userId: username,
          action: 'Login',
          success: false,
          errorMsg: 'User not found',
        );
        return LoginResult.failure('Invalid username or password');
      }

      // Check if user is active
      if (!user.isActive) {
        await _userDao.logAuthEvent(
          userId: user.userId,
          action: 'Login',
          success: false,
          errorMsg: 'Account is deactivated',
        );
        return LoginResult.failure('Your account has been deactivated');
      }

      // Check if user is locked due to too many failed attempts
      final isLocked = await _userDao.isUserLocked(user.userId);
      if (isLocked) {
        return LoginResult.failure(
          'Account is temporarily locked due to too many failed login attempts. Please try again in 15 minutes.',
        );
      }

      // Verify password
      final isPasswordValid = PasswordHasher.verifyPassword(
        password,
        user.passwordHash,
      );

      if (!isPasswordValid) {
        await _userDao.logAuthEvent(
          userId: user.userId,
          action: 'Login',
          success: false,
          errorMsg: 'Invalid password',
        );
        return LoginResult.failure('Invalid username or password');
      }

      // Login successful
      _currentUser = user;

      // Update last login time
      await _userDao.updateLastLogin(user.userId);

      // Log successful login
      await _userDao.logAuthEvent(
        userId: user.userId,
        action: 'Login',
        success: true,
      );

      // Save session
      await _saveSession(user);

      return LoginResult.success(user);
    } catch (e) {
      return LoginResult.failure('An error occurred during login: $e');
    }
  }

  /// Logout current user
  Future<void> logout() async {
    if (_currentUser != null) {
      await _userDao.logAuthEvent(
        userId: _currentUser!.userId,
        action: 'Logout',
        success: true,
      );
    }

    await _clearSession();
    _currentUser = null;
  }

  /// Create a new user (Admin only)
  Future<CreateUserResult> createUser({
    required String userId,
    required String username,
    required String password,
    required String role,
    Map<String, dynamic>? permissions,
  }) async {
    try {
      // Check if userId already exists
      final existingUser = await _userDao.getUserById(userId);
      if (existingUser != null) {
        return CreateUserResult.failure('User ID already exists');
      }

      // Hash password
      final passwordHash = PasswordHasher.hashPassword(password);

      // Create user
      final user = UsersCompanion.insert(
        userId: userId,
        username: username,
        passwordHash: passwordHash,
        role: role,
        permissions: jsonEncode(permissions ?? {}),
        isActive: const Value(true),
        createdAt: DateTime.now(),
        lastModified: DateTime.now(),
      );

      await _userDao.createUser(user);

      return CreateUserResult.success('User created successfully');
    } catch (e) {
      return CreateUserResult.failure('Failed to create user: $e');
    }
  }

  /// Change password
  Future<ChangePasswordResult> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    try {
      final user = await _userDao.getUserById(userId);
      if (user == null) {
        return ChangePasswordResult.failure('User not found');
      }

      // Verify old password
      final isOldPasswordValid = PasswordHasher.verifyPassword(
        oldPassword,
        user.passwordHash,
      );

      if (!isOldPasswordValid) {
        return ChangePasswordResult.failure('Current password is incorrect');
      }

      // Hash new password
      final newPasswordHash = PasswordHasher.hashPassword(newPassword);

      // Update user
      final updatedUser = user.copyWith(
        passwordHash: newPasswordHash,
        lastModified: DateTime.now(),
      );

      await _userDao.updateUser(updatedUser);

      // Log password change
      await _userDao.logAuthEvent(
        userId: userId,
        action: 'Password Change',
        success: true,
      );

      return ChangePasswordResult.success('Password changed successfully');
    } catch (e) {
      return ChangePasswordResult.failure('Failed to change password: $e');
    }
  }

  /// Check if user has permission
  bool hasPermission(String permission) {
    if (_currentUser == null) return false;

    try {
      final permissions = jsonDecode(_currentUser!.permissions) as Map<String, dynamic>;

      // Admin has all permissions
      if (permissions['all'] == true) return true;

      return permissions[permission] == true;
    } catch (e) {
      return false;
    }
  }

  /// Check if user has role
  bool hasRole(String role) {
    return _currentUser?.role == role;
  }

  /// Save session to SharedPreferences
  Future<void> _saveSession(User user) async {
    final userMap = {
      'userId': user.userId,
      'username': user.username,
      'passwordHash': user.passwordHash,
      'role': user.role,
      'permissions': user.permissions,
      'deviceId': user.deviceId,
      'isActive': user.isActive,
      'createdAt': user.createdAt.toIso8601String(),
      'lastLogin': user.lastLogin?.toIso8601String(),
      'lastModified': user.lastModified.toIso8601String(),
    };

    await _prefs.setString('current_user', jsonEncode(userMap));
  }

  /// Clear session from SharedPreferences
  Future<void> _clearSession() async {
    await _prefs.remove('current_user');
  }

  /// Get device ID
  Future<String> getDeviceId() async {
    String? deviceId = _prefs.getString('device_id');
    if (deviceId == null) {
      deviceId = const Uuid().v4();
      await _prefs.setString('device_id', deviceId);
    }
    return deviceId;
  }
}

// Result classes
class LoginResult {
  final bool success;
  final String? message;
  final User? user;

  LoginResult.success(this.user)
      : success = true,
        message = null;

  LoginResult.failure(this.message)
      : success = false,
        user = null;
}

class CreateUserResult {
  final bool success;
  final String message;

  CreateUserResult.success(this.message) : success = true;
  CreateUserResult.failure(this.message) : success = false;
}

class ChangePasswordResult {
  final bool success;
  final String message;

  ChangePasswordResult.success(this.message) : success = true;
  ChangePasswordResult.failure(this.message) : success = false;
}
