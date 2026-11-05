import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';


class UserSession {
  final String uid;
  final String role;
  final String firstName;

  const UserSession({
    required this.uid,
    required this.role,
    required this.firstName,
  });
}

class SessionService {
  SessionService._();

  static const _kUid = 'session_uid';
  static const _kRole = 'session_role';
  static const _kFirstName = 'session_first_name';

  static Future<void> saveSession({
    required String uid,
    required String role,
    required String firstName,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUid, uid);
    await prefs.setString(_kRole, role);
    await prefs.setString(_kFirstName, firstName);
  }

  static Future<UserSession?> getSession() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = prefs.getString(_kUid);
    final role = prefs.getString(_kRole);

    if (uid == null || uid.isEmpty || role == null || role.isEmpty) {
      return null;
    }

    return UserSession(
      uid: uid,
      role: role,
      firstName: prefs.getString(_kFirstName) ?? '',
    );
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUid);
    await prefs.remove(_kRole);
    await prefs.remove(_kFirstName);
  }

  /// Uses `firstName` if present, otherwise the first word of `fullName`.
  static String firstNameFrom(Map<String, dynamic>? data) {
    if (data == null) return '';

    final first = (data['firstName'] ?? '').toString().trim();
    if (first.isNotEmpty) return first;

    final full = (data['fullName'] ?? '').toString().trim();
    if (full.isEmpty) return '';

    return full.split(RegExp(r'\s+')).first;
  }

  /// Rebuilds the cache from Firestore when the user is still signed in to
  static Future<UserSession?> restoreFromFirebase(User user) async {
    try {
      final db = FirebaseFirestore.instance;
      Map<String, dynamic>? data;

      final doc = await db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        data = doc.data();
      } else {
        final query = await db
            .collection('users')
            .where('email', isEqualTo: user.email)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          data = query.docs.first.data();
        }
      }

      if (data == null) return null;

      final role = (data['role'] ?? 'resident').toString().toLowerCase();
      final firstName = firstNameFrom(data);

      await saveSession(uid: user.uid, role: role, firstName: firstName);

      return UserSession(uid: user.uid, role: role, firstName: firstName);
    } catch (_) {
      return null;
    }
  }
}