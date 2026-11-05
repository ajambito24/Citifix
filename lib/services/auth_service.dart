import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'push_service.dart';
import 'session_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // REGISTER RESIDENT - Matches your schema
  Future<String?> registerResident({
    required String fullName,
    required String email,
    required String password,
  }) async {
    try {
      UserCredential userCredential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .set({
        'fullName': fullName,
        'email': email,
        'role': 'resident',
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null; 
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // REGISTER RESIDENT (full multi-step form)
  Future<String?> registerResidentFull({
    required String firstName,
    required String lastName,
    required String phone,
    required String email,
    required String streetAddress,
    required String barangay,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        return 'Registration failed.';
      }

      await _firestore.collection('users').doc(user.uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'fullName': '$firstName $lastName', 
        'phone': phone,
        'email': email,
        'streetAddress': streetAddress,
        'barangay': barangay,
        'city': 'Manila',
        'role': 'resident',
        'isActive': true,
        'termsAccepted': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'email-already-in-use':
          return 'This email is already registered.';
        case 'invalid-email':
          return 'Invalid email address.';
        case 'weak-password':
          return 'Password is too weak.';
        default:
          return e.message ?? 'Registration failed.';
      }
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  // LOGIN
  Future<String?> login({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return null;
    } on FirebaseAuthException catch (e) {
      return e.message;
    } catch (e) {
      return e.toString();
    }
  }

  // GET CURRENT USER ROLE
  Future<String?> getUserRole() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot document =
          await _firestore.collection('users').doc(user.uid).get();

      if (document.exists) {
        return document['role'];
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // GET CURRENT USER DATA
  Future<Map<String, dynamic>?> getCurrentUserData() async {
    try {
      User? user = _auth.currentUser;
      if (user == null) return null;

      DocumentSnapshot document =
          await _firestore.collection('users').doc(user.uid).get();

      if (document.exists) {
        return document.data() as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE CURRENT USER PROFILE (name + phone)
  // ─────────────────────────────────────────────────────────────
  Future<void> updateUserProfile({
    required String fullName,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'fullName': fullName,
        'phone': phone,
      },
      SetOptions(merge: true), // merge so we don't wipe role/email/etc.
    );
  }

  // ─────────────────────────────────────────────────────────────
  // UPDATE CURRENT USER PROFILE (full: name, phone, address)
  // Email and city are intentionally not editable.
  // ─────────────────────────────────────────────────────────────
  Future<void> updateUserProfileFull({
    required String firstName,
    required String lastName,
    required String phone,
    required String streetAddress,
    required String barangay,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw Exception('No user is currently signed in.');
    }

    await _firestore.collection('users').doc(user.uid).set(
      {
        'firstName': firstName,
        'lastName': lastName,
        'fullName': '$firstName $lastName', // keeps older screens working
        'phone': phone,
        'streetAddress': streetAddress,
        'barangay': barangay,
      },
      SetOptions(merge: true), // merge so we don't wipe role/email/etc.
    );
  }

  // ─────────────────────────────────────────────────────────────
  // CHANGE PASSWORD
  // Re-authenticates with the current password, then updates it.
  // Returns null on success, or an error message.
  // ─────────────────────────────────────────────────────────────
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email;

    if (user == null || email == null) {
      return 'No user is currently signed in.';
    }

    try {
      final credential = EmailAuthProvider.credential(
        email: email,
        password: currentPassword,
      );

      await user.reauthenticateWithCredential(credential);
      await user.updatePassword(newPassword);

      return null;
    } on FirebaseAuthException catch (e) {
      switch (e.code) {
        case 'wrong-password':
        case 'invalid-credential':
          return 'Current password is incorrect.';
        case 'weak-password':
          return 'New password is too weak.';
        case 'too-many-requests':
          return 'Too many attempts. Please try again later.';
        case 'requires-recent-login':
          return 'Please log in again, then retry.';
        default:
          return e.message ?? 'Failed to change password.';
      }
    } catch (e) {
      return 'Something went wrong: $e';
    }
  }

  // LOGOUT
  // Push cleanup (token + topic) must run while still signed in, because
  // Firestore rules only let the user edit their own document. It is capped
  // so a bad connection can never block logging out.
  Future<void> logout() async {
    try {
      await PushService.instance.clear().timeout(const Duration(seconds: 6));
    } catch (_) {
      // ignore — log out regardless
    }

    await SessionService.clearSession();
    await _auth.signOut();
  }

  // CURRENT USER
  User? get currentUser => _auth.currentUser;
}