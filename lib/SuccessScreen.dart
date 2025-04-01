import 'package:flutter/material.dart';
import 'package:hexcolor/hexcolor.dart';

class SuccessScreen extends StatelessWidget {
  const SuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HexColor('0F172A'),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.all(18.0),
              child: Icon(
                Icons.check_circle_outline_sharp,
                color: HexColor('86EFAC'),
                size: 100,
              ),
            ),
            Text(
              'Checked In successfully!',
              style: TextStyle(color: HexColor('86EFAC'), fontSize: 22),
            ),
            SizedBox(
              height: 10,
            ),
            Text(
              'Thank you! ',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Text(
              'Your form has been submitted successfully. ',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
            Center(
                child: Text(
              'Have a good day!',
              style: TextStyle(color: Colors.white, fontSize: 16),
            )),
            SizedBox(
              height: 20,
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white),
              onPressed: () {
                Navigator.pop(context);
              },
              child: Text(
                'Go back',
                style: TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
