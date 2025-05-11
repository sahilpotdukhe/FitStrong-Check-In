import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class InvalidGymPage extends StatelessWidget {
  const InvalidGymPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Lottie.asset('assets/404-error.json', width: double.infinity),
      ),
    );
  }
}
