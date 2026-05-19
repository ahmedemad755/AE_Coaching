import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthRemoteDataSource {
  Future<String> requestOtp(String phoneNumber);

  // تم إضافة الاسم والباسورد عشان نحفظهم في الفايرستور
  Future<void> registerWithOtp({
    required String verificationId,
    required String smsCode,
    required String name,
    required String phone,
    required String password,
  });

  // تسجيل الدخول العادي بالرقم والباسورد
  Future<void> login(String phone, String password);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // دالة لتشفير الباسورد قبل حفظه (Security Best Practice)
  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  @override
  Future<String> requestOtp(String phoneNumber) async {
    Completer<String> completer = Completer<String>();

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
    // 1. تأكيد الـ OTP
    PhoneAuthCredential credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    UserCredential userCredential = await _auth.signInWithCredential(credential);

    // 2. حفظ بيانات المستخدم في Firestore
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'uid': userCredential.user!.uid,
      'name': name,
      'phoneNumber': phone,
      'password': _hashPassword(password), // بنحفظ الباسورد مشفر
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> login(String phone, String password) async {
    // 1. البحث عن المستخدم برقم الهاتف في Firestore
    var querySnapshot = await _firestore
        .collection('users')
        .where('phoneNumber', isEqualTo: phone)
        .get();

    if (querySnapshot.docs.isEmpty) {
      throw Exception('Account not found. Please register first.');
    }

    // 2. التحقق من الباسورد
    var userData = querySnapshot.docs.first.data();
    String storedHashedPassword = userData['password'];
    String inputHashedPassword = _hashPassword(password);

    if (storedHashedPassword != inputHashedPassword) {
      throw Exception('Incorrect password. Please try again.');
    }

    // إذا وصلنا هنا، يعني الرقم والباسورد صح!
  }
}