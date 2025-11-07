import 'package:drift/drift.dart';
import 'package:hotel_inventory_management/db/app_database.dart';

part 'user_dao.g.dart';

@DriftAccessor(tables: [Users, AuthLogs])
class UserDao extends DatabaseAccessor<AppDatabase> with _$UserDaoMixin {
  UserDao(AppDatabase db) : super(db);

  // Get user by userId
  Future<User?> getUserById(String userId) {
    return (select(users)..where((u) => u.userId.equals(userId))).getSingleOrNull();
  }

  // Get user by username
  Future<User?> getUserByUsername(String username) {
    return (select(users)..where((u) => u.username.equals(username))).getSingleOrNull();
  }

  // Get all active users
  Future<List<User>> getAllActiveUsers() {
    return (select(users)..where((u) => u.isActive.equals(true))).get();
  }

  // Get all users
  Future<List<User>> getAllUsers() {
    return select(users).get();
  }

  // Create a new user
  Future<int> createUser(UsersCompanion user) {
    return into(users).insert(user);
  }

  // Update user
  Future<bool> updateUser(User user) {
    return update(users).replace(user);
  }

  // Delete user (soft delete by setting isActive to false)
  Future<int> deactivateUser(String userId) {
    return (update(users)..where((u) => u.userId.equals(userId)))
        .write(UsersCompanion(
      isActive: const Value(false),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Update last login time
  Future<int> updateLastLogin(String userId) {
    return (update(users)..where((u) => u.userId.equals(userId)))
        .write(UsersCompanion(
      lastLogin: Value(DateTime.now()),
      lastModified: Value(DateTime.now()),
    ));
  }

  // Log authentication event
  Future<int> logAuthEvent({
    required String userId,
    required String action,
    String? deviceId,
    String? ipAddress,
    required bool success,
    String? errorMsg,
  }) {
    return into(authLogs).insert(AuthLogsCompanion(
      userId: Value(userId),
      action: Value(action),
      deviceId: Value(deviceId),
      ipAddress: Value(ipAddress),
      success: Value(success),
      errorMsg: Value(errorMsg),
      timestamp: Value(DateTime.now()),
    ));
  }

  // Get recent auth logs for a user
  Future<List<AuthLog>> getRecentAuthLogs(String userId, {int limit = 10}) {
    return (select(authLogs)
          ..where((log) => log.userId.equals(userId))
          ..orderBy([(log) => OrderingTerm.desc(log.timestamp)])
          ..limit(limit))
        .get();
  }

  // Get failed login attempts
  Future<int> getFailedLoginCount(String userId, Duration timeWindow) {
    final cutoffTime = DateTime.now().subtract(timeWindow);
    return (selectOnly(authLogs)
          ..addColumns([authLogs.id.count()])
          ..where(authLogs.userId.equals(userId))
          ..where(authLogs.action.equals('Login'))
          ..where(authLogs.success.equals(false))
          ..where(authLogs.timestamp.isBiggerOrEqualValue(cutoffTime)))
        .map((row) => row.read(authLogs.id.count()) ?? 0)
        .getSingle();
  }

  // Check if user is locked due to too many failed attempts
  Future<bool> isUserLocked(String userId) async {
    final failedCount = await getFailedLoginCount(
      userId,
      const Duration(minutes: 15),
    );
    return failedCount >= 5; // Lock after 5 failed attempts in 15 minutes
  }
}
