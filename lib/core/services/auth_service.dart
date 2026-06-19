import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../constants/app_constants.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  bool _googleSignInInitialized = false;

  Future<UserCredential?> signInWithGoogle() async {
    if (!_googleSignInInitialized) {
      await GoogleSignIn.instance.initialize(
        serverClientId: '332127348645-ttrrcuk6961eevtvso8vmhrohk0rb8uh.apps.googleusercontent.com',
      );
      _googleSignInInitialized = true;
    }

    GoogleSignInAccount? googleUser;

    // Step 1: Try One Tap (bottom sheet) — lightweight, no full account picker
    try {
      final lightweightFuture = GoogleSignIn.instance.attemptLightweightAuthentication();
      if (lightweightFuture != null) {
        googleUser = await lightweightFuture;
      }
    } catch (_) {
      // One Tap not available or failed — proceed to full flow
    }

    // Step 2: If One Tap didn't sign in, show the full bottom-sheet account picker
    if (googleUser == null) {
      try {
        googleUser = await GoogleSignIn.instance.authenticate();
      } on GoogleSignInException catch (e) {
        if (e.code == GoogleSignInExceptionCode.canceled) return null;
        rethrow;
      }
    }

    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final OAuthCredential credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
    );

    final userCredential = await _auth.signInWithCredential(credential);
    if (userCredential.user != null) {
      await _createUserRecord(
        userCredential.user!,
        userCredential.user!.displayName ?? 'ShowSnap User',
        AppConstants.roleUser,
      );
    }
    return userCredential;
  }



  /// Web-specific Google Sign-In using signInWithPopup (no SDK needed on web).
  Future<UserCredential?> signInWithGoogleWeb() async {
    if (!kIsWeb) return signInWithGoogle();
    try {
      final provider = GoogleAuthProvider();
      provider.addScope('email');
      provider.addScope('profile');
      final userCredential = await _auth.signInWithPopup(provider);
      if (userCredential.user != null) {
        await _createUserRecord(
          userCredential.user!,
          userCredential.user!.displayName ?? 'ShowSnap User',
          AppConstants.roleUser,
        );
      }
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

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
    
    final ref = _db.ref('${AppConstants.usersPath}/${user.uid}');
    final snap = await ref.get();
    
    if (!snap.exists) {
      await ref.set(UserModel(
        uid: user.uid,
        displayName: user.displayName ?? 'Admin',
        email: user.email ?? '',
        role: AppConstants.roleAdmin,
        createdAt: DateTime.now().millisecondsSinceEpoch,
      ).toJson());
    } else if (snap.child('role').value?.toString() != AppConstants.roleAdmin) {
      await ref.child('role').set(AppConstants.roleAdmin);
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
