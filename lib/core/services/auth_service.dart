import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) =>
      _auth.signInWithEmailAndPassword(email: email, password: password);

  Future<UserCredential> signUpWithEmail(
      String email, String password, String displayName) async {
    final credential = await _auth.createUserWithEmailAndPassword(
        email: email, password: password);
    await credential.user?.updateDisplayName(displayName);
    await _createUserRecord(credential.user!, displayName, 'user');
    return credential;
  }

  Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email);

  Future<void> signOut() => _auth.signOut();

  Future<void> _createUserRecord(
      User user, String displayName, String role) async {
    final ref = _db.ref('${AppConstants.usersPath}/${user.uid}');
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set(UserModel(
        uid: user.uid,
        displayName: displayName,
        email: user.email ?? '',
        role: role,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ).toJson());
    }
  }

  /// Ensures the admin account has role='admin' in the DB.
  /// Called on every admin login — safe because auth.uid === $uid allows
  /// self-writes even before the DB role is set to 'admin'.
  Future<void> ensureAdminRole() async {
    final user = _auth.currentUser;
    if (user == null || user.email != 'admin@gmail.com') return;
    final roleRef = _db.ref('${AppConstants.usersPath}/${user.uid}/role');
    final snap = await roleRef.get();
    if (snap.value?.toString() != AppConstants.roleAdmin) {
      await roleRef.set(AppConstants.roleAdmin);
    }
  }

  /// Returns the current user's role.
  /// Short-circuits for admin@gmail.com without a DB call.
  Future<String> getCurrentUserRole() async {
    final user = _auth.currentUser;
    if (user == null) return AppConstants.roleUser;
    // Fast-path: admin email is always admin
    if (user.email == 'admin@gmail.com') return AppConstants.roleAdmin;
    final snapshot =
        await _db.ref('${AppConstants.usersPath}/${user.uid}/role').get();
    return snapshot.value?.toString() ?? AppConstants.roleUser;
  }

  Future<UserModel?> getCurrentUserModel() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    final snapshot = await _db.ref('${AppConstants.usersPath}/$uid').get();
    if (!snapshot.exists || snapshot.value == null) return null;
    return UserModel.fromJson(uid, snapshot.value as Map);
  }

  Future<void> updateUserProfile({
    String? displayName,
    String? phone,
    String? city,
    String? avatarUrl,
    List<String>? preferredGenres,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final updates = <String, dynamic>{};
    if (displayName != null) updates['displayName'] = displayName;
    if (phone != null) updates['phone'] = phone;
    if (city != null) updates['city'] = city;
    if (avatarUrl != null) updates['avatarUrl'] = avatarUrl;
    if (preferredGenres != null) updates['preferredGenres'] = preferredGenres;
    await _db.ref('${AppConstants.usersPath}/$uid').update(updates);
    if (displayName != null) {
      await _auth.currentUser?.updateDisplayName(displayName);
    }
  }

  Stream<UserModel?> streamCurrentUser() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);
    return _db
        .ref('${AppConstants.usersPath}/$uid')
        .onValue
        .map((event) {
      if (event.snapshot.value == null) return null;
      return UserModel.fromJson(uid, event.snapshot.value as Map);
    });
  }
}

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

final currentUserModelProvider = StreamProvider<UserModel?>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) {
      if (user == null) return Stream.value(null);
      return ref.watch(authServiceProvider).streamCurrentUser();
    },
    loading: () => Stream.value(null),
    error: (_, __) => Stream.value(null),
  );
});
