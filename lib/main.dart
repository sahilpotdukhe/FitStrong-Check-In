import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'AttendancePage.dart';
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
    final gymId = Uri.base.queryParameters['gym'];
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym Attendance',
      home:
          gymId == null
              ? const Scaffold(
                body: Center(
                  child: Text(
                    '❌ Gym ID missing in URL.\nAdd ?gym=GYM123 to the link.',
                  ),
                ),
              )
              : AttendancePage(gymId: gymId),
    );
  }
}
