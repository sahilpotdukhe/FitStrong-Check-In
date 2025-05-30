import 'dart:html' as html; // 👈 Add this for localStorage

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'AttendancePage.dart';
import 'InvalidGymPage.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    String? gymId = Uri.base.queryParameters['gym'];

    gymId ??= html.window.localStorage['gymId'];

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym Attendance',
      home: gymId == null ? const InvalidGymPage() : GymChecker(gymId: gymId),
    );
  }
}

class GymChecker extends StatelessWidget {
  final String gymId;

  const GymChecker({super.key, required this.gymId});

  Future<bool> _gymExists() async {
    final doc =
        await FirebaseFirestore.instance.collection('Users').doc(gymId).get();
    return doc.exists;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _gymExists(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasError || snapshot.data == false) {
          return const InvalidGymPage();
        } else {
          return AttendancePage(gymId: gymId);
        }
      },
    );
  }
}
