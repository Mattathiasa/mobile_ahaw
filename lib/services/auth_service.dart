import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import 'localization_service.dart';

/// Mirrors the web's AuthContext + authService.
/// Handles:
///  - Username-or-email login (same fallback logic as web)
///  - Full user profile loaded from Firestore `users/{uid}`
///  - Exposes typed [UserModel] instead of raw Map
class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? _firebaseUser;
  UserModel? _userModel;
  bool _isLoading = true;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;

  /// Fired when the signed-in member's `status` changes while the app is open —
  /// `(previous, next)`. main.dart uses it to raise a local notification the
  /// moment an approver accepts or rejects the request.
  void Function(String previous, String next)? onStatusChanged;

  AuthService() {
    _auth.authStateChanges().listen(_onAuthStateChanged);
  }

  // ── Public getters ──────────────────────────────────────────────────────────

  /// Raw Firebase user (for email, uid, etc.)
  User? get user => _firebaseUser;

  /// Fully typed user model with all Firestore fields
  UserModel? get userModel => _userModel;

  /// Legacy: raw Firestore data map (keeps existing widgets working)
  Map<String, dynamic>? get userData => _userModel == null
      ? null
      : {
          'fullName': _userModel!.fullName,
          'fullNameEnglish': _userModel!.fullNameEnglish,
          'fullNameAmharic': _userModel!.fullNameAmharic,
          'role': _userModel!.role,
          'hierarchyLevel': _userModel!.hierarchyLevel,
          'phone': _userModel!.phone,
          'church': _userModel!.address?['city'] ??
              _userModel!.address?['woreda'] ??
              'Main Atbiya',
          'dateOfBirth': _userModel!.dateOfBirth,
          'workSchool': _userModel!.workSchool,
          'maritalStatus': _userModel!.maritalStatus,
          'hasChildren': _userModel!.hasChildren,
          'childrenCount': _userModel!.childrenCount,
          'createdAt': _userModel!.createdAt,
        };

  bool get isLoading => _isLoading;

  /// Anonymous sessions (minted transiently for the public suggestion box) do
  /// NOT count as authenticated — otherwise they would flip the app into the
  /// dashboard. Mirrors the web's isAnonymous guard in AuthContext.
  bool get isAuthenticated =>
      _firebaseUser != null && !_firebaseUser!.isAnonymous;

  // ── Auth state listener ─────────────────────────────────────────────────────

  Future<void> _onAuthStateChanged(User? firebaseUser) async {
    _firebaseUser = firebaseUser;

    if (firebaseUser != null && !firebaseUser.isAnonymous) {
      _listenToUserDoc(firebaseUser);
    } else {
      await _profileSub?.cancel();
      _profileSub = null;
      _userModel = null;
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Watches `users/{uid}` for the life of the session.
  ///
  /// This was a one-shot `.get()`, and that is what made approval invisible on
  /// the phone: a member sitting on the pending screen when an approver flipped
  /// `status` to `active` saw nothing until they killed and reopened the app.
  /// A listener also means a suspension takes effect immediately rather than at
  /// next launch.
  void _listenToUserDoc(User firebaseUser) {
    _profileSub?.cancel();
    _profileSub = _db
        .collection('users')
        .doc(firebaseUser.uid)
        .snapshots()
        .listen((doc) {
      final previous = _userModel?.status;

      if (doc.exists && doc.data() != null) {
        _userModel = UserModel.fromFirestore(
          firebaseUser.uid,
          doc.data()!,
          firebaseUser.email ?? '',
        );
      } else {
        // Authenticated with no profile document. This is NOT an ordinary
        // member: the web signs such an account straight back out, and the
        // status must not default to 'active' or the pending gate is bypassed
        // entirely by anyone whose record was deleted.
        _userModel = UserModel(
          id: firebaseUser.uid,
          username: firebaseUser.email?.split('@')[0] ?? 'user',
          email: firebaseUser.email ?? '',
          role: 'user',
          hierarchyLevel: 'HiyawanMahderat',
          status: 'missing',
        );
      }

      final next = _userModel?.status;
      if (previous != null && next != null && previous != next) {
        onStatusChanged?.call(previous, next);
      }

      _isLoading = false;
      notifyListeners();
    }, onError: (e) {
      if (kDebugMode) print('[AuthService] profile listen failed: $e');
      _isLoading = false;
      notifyListeners();
    });
  }

  // ── Sign in ─────────────────────────────────────────────────────────────────
  /// Accepts username OR email, exactly matching the web's login logic.

  Future<void> signIn(String usernameOrEmail, String password) async {
    String email = usernameOrEmail.trim();
    final typedAUsername = !email.contains('@');

    if (typedAUsername) {
      email = await _resolveUsernameToEmail(email);
    }

    try {
      if (kDebugMode) print('[AuthService] Signing in with: $email');
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e, typedAUsername: typedAUsername);
    }
  }

  /// The deterministic login address for a username.
  ///
  /// Self-service signup always creates the Auth account here, storing any real
  /// address the member gave as a *contact* field instead. Mirrors
  /// `syntheticEmail` in the web's src/services/signup.ts.
  static String syntheticEmail(String username) {
    final clean =
        username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$clean@mahibereahaw.local';
  }

  static bool isSyntheticEmail(String email) =>
      email.toLowerCase().endsWith('@mahibereahaw.local');

  /// Resolves a typed username to the address the Auth account actually uses.
  ///
  /// A port of `resolveEmail` in the web's src/services/auth.ts. The previous
  /// implementation queried `users` where `username ==` and returned that
  /// document's `email` — which is the member's *contact* address, not their
  /// login address, so it was wrong for every self-signed-up account. It also
  /// compared case-sensitively while the `usernames/` reservation is
  /// lowercased. It only worked because firestore.rules denies that pre-auth
  /// read, so it always fell through to the synthetic fallback.
  ///
  /// `usernames/{lowercased}` is world-readable by `get` precisely so this
  /// lookup can happen before sign-in.
  Future<String> _resolveUsernameToEmail(String username) async {
    final key = username.trim().toLowerCase();
    final deterministic = syntheticEmail(key);
    try {
      final row = await _db.collection('usernames').doc(key).get();
      final mapped = row.data()?['email'];
      if (mapped is String && mapped.trim().isNotEmpty) return mapped.trim();
      return deterministic;
    } catch (e) {
      if (kDebugMode) print('[AuthService] username lookup failed: $e');
      return deterministic;
    }
  }

  /// Sends a password-reset email, porting `sendPasswordReset` from the web.
  ///
  /// Returns the address it was sent to, so the caller can name it. Two
  /// deliberate behaviours are carried over: an account that only has a
  /// synthetic login address cannot receive a reset and is told so plainly,
  /// and `user-not-found` is swallowed rather than reported — otherwise this
  /// form becomes an account-enumeration oracle.
  Future<String> sendPasswordReset(String usernameOrEmail) async {
    var email = usernameOrEmail.trim();
    if (!email.contains('@')) {
      email = await _resolveUsernameToEmail(email);
    }
    if (isSyntheticEmail(email)) {
      throw _ResetWithoutEmail();
    }
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') return email;
      throw _mapFirebaseError(e);
    }
    return email;
  }

  /// Maps a Firebase auth code to an i18n key the UI resolves through
  /// `LocalizationService.t`. These were English literals, so an Amharic
  /// reader hit a wall of English the moment anything went wrong.
  ///
  /// `wrongPasswordTryEmail` is the web's nicety: when somebody typed a
  /// username, the likelier cause is that they registered with an email.
  AuthErrorKey _mapFirebaseError(FirebaseAuthException e,
      {bool typedAUsername = false}) {
    switch (e.code) {
      case 'invalid-login-credentials':
      case 'invalid-credential':
      case 'wrong-password':
        return AuthErrorKey(typedAUsername
            ? 'errors.wrongPasswordTryEmail'
            : 'errors.wrongPassword');
      case 'user-not-found':
        return AuthErrorKey('errors.noAccount');
      case 'invalid-email':
        return AuthErrorKey('errors.invalidIdentifier');
      case 'user-disabled':
        return AuthErrorKey('errors.accountDisabled');
      case 'too-many-requests':
        return AuthErrorKey('errors.tooManyAttempts');
      case 'network-request-failed':
        // Sign-in is the one thing the offline cache cannot serve, so say so
        // rather than surfacing a raw Firebase string.
        return AuthErrorKey('errors.networkProblem');
      default:
        return AuthErrorKey('errors.loginFailedDetail',
            params: {'detail': e.message ?? e.code});
    }
  }

  /// Re-reads the current user's Firestore profile and notifies listeners.
  /// Call after editing the profile / preferences so the UI reflects changes
  /// without waiting for an auth-state event.
  Future<void> refreshUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    // The snapshot listener already pushes every change; re-attaching is only
    // useful if it had errored out.
    _listenToUserDoc(firebaseUser);
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  /// Signs out and drops the local Firestore cache.
  ///
  /// The cache is not partitioned by user: without this, every document the
  /// previous member had read stays readable on the device after somebody else
  /// signs in. Server rules would deny a *fresh* read, but the SDK answers from
  /// disk first, so on a shared phone this was a real disclosure.
  ///
  /// `clearPersistence` only works with no active listeners, which is why the
  /// profile subscription is cancelled first and the whole thing is
  /// best-effort — failing to clear must never trap someone in a session.
  Future<void> signOut() async {
    await _profileSub?.cancel();
    _profileSub = null;
    await _auth.signOut();
    try {
      await _db.terminate();
      await _db.clearPersistence();
    } catch (e) {
      if (kDebugMode) print('[AuthService] cache clear failed: $e');
    }
  }

  @override
  void dispose() {
    _profileSub?.cancel();
    super.dispose();
  }

  // ── Change password ─────────────────────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw AuthErrorKey('errors.notSignedIn');
    }
    if (newPassword.length < 6) {
      throw AuthErrorKey('errors.passwordTooShort');
    }
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: currentPassword,
    );
    try {
      await firebaseUser.reauthenticateWithCredential(credential);
    } catch (_) {
      throw AuthErrorKey('errors.currentPasswordWrong');
    }
    await firebaseUser.updatePassword(newPassword);
  }
}

/// An auth failure carrying an i18n key rather than an English sentence.
///
/// The UI resolves it with `LocalizationService.t(key)` and substitutes
/// `{param}` placeholders, matching how the web's `AppError` + `errorMessage`
/// pair works.
class AuthErrorKey implements Exception {
  final String key;
  final Map<String, String> params;
  AuthErrorKey(this.key, {this.params = const {}});

  /// The resolved sentence. [translate] is normally `LocalizationService.t`.
  String resolve(String Function(String) translate) {
    return fillParams(translate(key), params);
  }

  @override
  String toString() => key;
}

/// Thrown when a reset is asked for on an account that has no real email.
class _ResetWithoutEmail extends AuthErrorKey {
  _ResetWithoutEmail() : super('errors.noEmailOnAccount');
}
