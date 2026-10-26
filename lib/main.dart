import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'firebase_options.dart';
import 'scanner_page.dart';
import 'sign_in_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // The desk must keep working through a Wi-Fi drop. This is Firestore's
  // default on a phone or tablet, but it is the whole reason check-ins are
  // not lost, so it is written down rather than assumed. An unlimited cache
  // means a long outage fills up with queued arrivals instead of evicting
  // them, and everything on disk survives the tablet being restarted.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // A desk scanner is held one way and used by staff, not browsed.
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(const CheckInApp());
}

class CheckInApp extends StatelessWidget {
  const CheckInApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FitStrong Attendance',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF15803D)),
      ),
      home: const _AuthGate(),
    );
  }
}

/// Shows the scanner when the device is signed in, and the sign in screen
/// when it is not. The gym's own id is the signed in account's id, so the
/// scanner can only ever read and write this gym's data.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) return const SignInPage();
        return ScannerPage(gymId: user.uid);
      },
    );
  }
}
