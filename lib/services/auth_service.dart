import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  User? _user;
  bool _isLoading = true;

  AuthService() {
    _auth.authStateChanges().listen((User? user) {
      _user = user;
      _isLoading = false;
      notifyListeners();
    });
  }

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;

  Future<void> signIn(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      if (kDebugMode) {
        print("Sign In Error: $e");
      }
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> signUp(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } catch (e) {
      if (kDebugMode) {
        print("Sign Up Error: $e");
      }
      rethrow;
    }
  }
}
