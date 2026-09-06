import 'dart:async';
import 'dart:convert';

import 'package:ae_coaching/auth/domain/entities/auth_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRemoteDataSource {
  Future<String> requestOtp(String phoneNumber);

  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  });

  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  });

  Future<AuthUser> login(String phone, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String _authEmailFromPhone(String phone) {
    final digitsOnly = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) {
      throw Exception('Invalid phone number.');
    }
    return 'u$digitsOnly@ae-coaching.app';
  }

  Future<void> _linkPasswordLogin({
    required User user,
    required String phone,
    required String password,
  }) async {
    final emailCredential = EmailAuthProvider.credential(
      email: _authEmailFromPhone(phone),
      password: password,
    );

    try {
      await user.linkWithCredential(emailCredential);
    } on FirebaseAuthException catch (e) {
      if (e.code == 'provider-already-linked') {
        return;
      }
      if (e.code == 'credential-already-in-use' ||
          e.code == 'email-already-in-use') {
        throw Exception('Account already exists. Please login.');
      }
      rethrow;
    }
  }

  String _mapFirebaseAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect phone number or password.';
      case 'operation-not-allowed':
        return 'Enable Email/Password sign-in method in Firebase Authentication.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return e.message ?? e.code;
    }
  }

  @override
  Future<String> requestOtp(String phoneNumber) async {
    final completer = Completer<String>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {},
      verificationFailed: (FirebaseAuthException e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!completer.isCompleted) completer.complete(verificationId);
      },
    );

    return completer.future;
  }

  @override
  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  }) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final userCredential = await _auth.signInWithCredential(credential);
    final user = userCredential.user;

    if (user == null) {
      throw Exception('Unable to complete registration.');
    }

    await _linkPasswordLogin(
      user: user,
      phone: phone,
      password: password,
    );

    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'name': name,
      'phoneNumber': phone,
      'authEmail': _authEmailFromPhone(phone),
      'password': _hashPassword(password),
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  @override
  Future<AuthUser> registerWithPhonePassword({
    required String name,
    required String phone,
    required String password,
  }) async {
    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: _authEmailFromPhone(phone),
        password: password,
      );
      final user = userCredential.user;

      if (user == null) {
        throw Exception('Unable to complete registration.');
      }

      await user.updateDisplayName(name);

      await _firestore.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'phoneNumber': phone,
        'authEmail': _authEmailFromPhone(phone),
        'password': _hashPassword(password),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return AuthUser(
        uid: user.uid,
        name: name,
        phoneNumber: phone,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        throw Exception('Account already exists. Please login.');
      }
      throw Exception(_mapFirebaseAuthException(e));
    }
  }

  @override
  Future<AuthUser> login(String phone, String password) async {
    try {
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: _authEmailFromPhone(phone),
        password: password,
      );
      final firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception('Unable to login. Please try again.');
      }

      final userRef = _firestore.collection('users').doc(firebaseUser.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) {
        await userRef.set({
          'uid': firebaseUser.uid,
          'phoneNumber': phone,
          'authEmail': _authEmailFromPhone(phone),
          'createdAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      final userData = userDoc.data() ?? {};

      return AuthUser(
        uid: firebaseUser.uid,
        name: (userData['name'] as String?) ?? '',
        phoneNumber: (userData['phoneNumber'] as String?) ?? phone,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(_mapFirebaseAuthException(e));
    }
  }
}
