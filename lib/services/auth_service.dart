import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';

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
      await _loadUserData(firebaseUser);
    } else {
      _userModel = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadUserData(User firebaseUser) async {
    try {
      final doc =
          await _db.collection('users').doc(firebaseUser.uid).get();
      if (doc.exists && doc.data() != null) {
        _userModel = UserModel.fromFirestore(
          firebaseUser.uid,
          doc.data()!,
          firebaseUser.email ?? '',
        );
      } else {
        // User exists in Auth but not Firestore — create minimal model
        _userModel = UserModel(
          id: firebaseUser.uid,
          username: firebaseUser.email?.split('@')[0] ?? 'user',
          email: firebaseUser.email ?? '',
          role: 'user',
          hierarchyLevel: 'HiyawanMahderat',
        );
      }
    } catch (e) {
      if (kDebugMode) print('[AuthService] Error loading user data: $e');
      _userModel = null;
    }
  }

  // ── Sign in ─────────────────────────────────────────────────────────────────
  /// Accepts username OR email, exactly matching the web's login logic.

  Future<void> signIn(String usernameOrEmail, String password) async {
    String email = usernameOrEmail.trim();

    // If not an email, resolve username → email via Firestore
    if (!email.contains('@')) {
      email = await _resolveUsernameToEmail(email);
    }

    try {
      if (kDebugMode) print('[AuthService] Signing in with: $email');
      await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw _mapFirebaseError(e);
    }
  }

  Future<String> _resolveUsernameToEmail(String username) async {
    try {
      final snapshot = await _db
          .collection('users')
          .where('username', isEqualTo: username)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        final data = snapshot.docs.first.data();
        if (data['email'] != null && (data['email'] as String).isNotEmpty) {
          return data['email'] as String;
        }
        // User exists but no email field — use deterministic fallback
        final clean = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        return '$clean@mahibereahaw.local';
      } else {
        // Not found — try deterministic fallback (legacy accounts)
        final clean = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
        return '$clean@mahibereahaw.local';
      }
    } catch (e) {
      if (kDebugMode) {
        print('[AuthService] Firestore username lookup failed: $e');
      }
      // Firestore permission denied before auth — use deterministic fallback
      final clean = username.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      return '$clean@mahibereahaw.local';
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-login-credentials':
      case 'invalid-credential':
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-not-found':
        return 'No account found with this username or email.';
      case 'invalid-email':
        return 'The email or username format is invalid.';
      case 'user-disabled':
        return 'This account has been disabled. Contact your administrator.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please wait a few minutes and try again.';
      default:
        return 'Login failed: ${e.message}';
    }
  }

  /// Re-reads the current user's Firestore profile and notifies listeners.
  /// Call after editing the profile / preferences so the UI reflects changes
  /// without waiting for an auth-state event.
  Future<void> refreshUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return;
    await _loadUserData(firebaseUser);
    notifyListeners();
  }

  // ── Sign out ────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ── Change password ─────────────────────────────────────────────────────────

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null || firebaseUser.email == null) {
      throw 'No user is currently signed in.';
    }
    if (newPassword.length < 6) {
      throw 'New password must be at least 6 characters long.';
    }
    final credential = EmailAuthProvider.credential(
      email: firebaseUser.email!,
      password: currentPassword,
    );
    try {
      await firebaseUser.reauthenticateWithCredential(credential);
    } catch (_) {
      throw 'Current password is incorrect.';
    }
    await firebaseUser.updatePassword(newPassword);
  }
}
