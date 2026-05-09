import 'package:ae_coaching/auth/data/models/Exercise_Set.dart';
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/service_locator.dart'; // تأكد من المسار الصحيح
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'package:firebase_core/firebase_core.dart'; // سطر مهم جداً
import 'package:ae_coaching/firebase_options.dart'; // لو بتستخدم flutterfire configure

void main() async {
  // 1. التأكد من تهيئة الـ Widgets
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. تهيئة Firebase (هذا السطر هو الحل!)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 3. تشغيل الـ Service Locator
  initAuth(); 
  
  // 4. تهيئة Hive
  await Hive.initFlutter();
  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(ExerciseSetAdapter());
  }
  
  await Hive.openBox<ExerciseSet>('sets');
  await Hive.openBox('authBox');

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'AE Coaching',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      // الراوتر هو اللي هيقرر يفتح Login ولا Home بناءً على الـ Hive
      initialRoute: AppNavigator.initial,
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}