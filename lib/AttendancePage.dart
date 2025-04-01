import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitstrongcheckin/SuccessScreen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'utils.dart';

class AttendancePage extends StatefulWidget {
  final String gymId;
  const AttendancePage({super.key, required this.gymId});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final _nameController = TextEditingController();
  bool _isLoading = false;
  String get dateText => DateFormat('d MMMM, y').format(DateTime.now());
  String get timeText => TimeOfDay.now().format(context);

  void _checkIn() async {
    String name = _nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter Name',
            style: TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    DateTime now = DateTime.now();
    String dateStr =
        "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
    String monthName = getMonthName(now.month);
    String timeStr = TimeOfDay.now().format(context);

    Map<String, dynamic> data = {
      'name': name,
      'timestamp': now.millisecondsSinceEpoch,
      'date': dateStr,
      'month': monthName,
      'year': now.year.toString(),
      'time': timeStr,
      'gymId': widget.gymId,
    };

    try {
      await FirebaseFirestore.instance
          .collection("Users")
          .doc(widget.gymId)
          .collection('attendance')
          .add(data);

      _nameController.clear();

      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SuccessScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/blackbgdesktop.jpg'),
            fit: BoxFit.cover,
          ),
        ),
        child: ListView(
          children: [
            Row(
              children: [
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(18.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        dateText,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        timeText,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: (width < 615) ? height * 0.3 : height * 0.42,
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      (width > 470)
                          ? 'Please enter your name in the designated field and click the "Check In" button. Your check-in time will be recorded automatically. Thank you.'
                          : 'Enter name and click on "Check In" to mark attendance.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28.0, 20, 28, 28),
                    child: SizedBox(
                      width: width * 0.7,
                      child: TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Enter Your Name',
                          labelText: 'Name',
                          hintStyle: const TextStyle(color: Colors.white),
                          labelStyle: const TextStyle(
                            fontSize: 16.0,
                            color: Colors.white,
                          ),
                          floatingLabelStyle: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 18,
                            color: Colors.white,
                          ),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: const BorderSide(
                              color: Colors.white,
                              width: 2,
                            ),
                          ),
                          suffixIcon: const Icon(
                            Icons.person,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                  (_isLoading)
                      ? ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: () {},
                        child: const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        ),
                      )
                      : ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                        ),
                        onPressed: _checkIn,
                        child: const Text(
                          'Check In',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                ],
              ),
            ),
            SizedBox(height: (width < 450) ? 100 : 0),
            Column(
              children: [
                Image.asset('assets/brandbg.png', height: 100, width: 100),
                Container(
                  color: Colors.black,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child:
                          (width > 360)
                              ? Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text.rich(
                                    TextSpan(
                                      text: 'Made with ',
                                      style: TextStyle(color: Colors.white),
                                      children: [
                                        TextSpan(
                                          text: '❤️',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        TextSpan(
                                          text: ' by',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final Uri url = Uri.parse(
                                        'https://sahilpotdukhe.github.io/Portfolio-website/',
                                      );
                                      try {
                                        await launchUrl(url);
                                      } catch (e) {
                                        print(e.toString());
                                      }
                                    },
                                    child: const Text(
                                      '  Sahil Potdukhe',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              )
                              : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text.rich(
                                    TextSpan(
                                      text: 'Made with ',
                                      style: TextStyle(color: Colors.white),
                                      children: [
                                        TextSpan(
                                          text: '❤️',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                        TextSpan(
                                          text: ' by',
                                          style: TextStyle(color: Colors.white),
                                        ),
                                      ],
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () async {
                                      final Uri url = Uri.parse(
                                        'https://sahilpotdukhe.github.io/Portfolio-website/',
                                      );
                                      try {
                                        await launchUrl(url);
                                      } catch (e) {
                                        print(e.toString());
                                      }
                                    },
                                    child: const Text(
                                      '  Sahil Potdukhe',
                                      style: TextStyle(color: Colors.blue),
                                    ),
                                  ),
                                ],
                              ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
