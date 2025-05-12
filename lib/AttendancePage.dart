import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitstrongcheckin/SuccessScreen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
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
  List<String> _allNames = [];
  bool _namesLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMemberNames();
  }

  Future<void> _fetchMemberNames() async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('Users')
              .doc(widget.gymId)
              .collection('members')
              .get();

      setState(() {
        _allNames =
            querySnapshot.docs
                .map((doc) => (doc['name'] as String).toLowerCase())
                .toList();
      });
    } catch (e) {
      debugPrint("Error fetching member names: $e");
    }
  }

  void _checkIn() async {
    String name = _nameController.text.trim();

    if (name.isEmpty || !_allNames.contains(name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select a valid name from suggestions.',
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              physics: const ClampingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      ..._buildTopContent(context),
                      const Spacer(),
                      Padding(
                        padding: const EdgeInsets.only(top: 24.0, bottom: 16),
                        child: Column(
                          children: [
                            Image.asset(
                              'assets/brandbg.png',
                              height: 100,
                              width: 100,
                            ),
                            const SizedBox(height: 8),
                            Row(
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
                                    if (await canLaunchUrl(url)) {
                                      await launchUrl(url);
                                    }
                                  },
                                  child: const Text(
                                    '  Sahil Potdukhe',
                                    style: TextStyle(color: Colors.blue),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<Widget> _buildTopContent(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final height = MediaQuery.of(context).size.height;

    return [
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
                  style: const TextStyle(fontSize: 16, color: Colors.white),
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
            SizedBox(height: (width < 615) ? height * 0.1 : height * 0.42),
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
                child: TypeAheadFormField<String>(
                  textFieldConfiguration: TextFieldConfiguration(
                    controller: _nameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Enter Your Name',
                      labelText: 'Name',
                      hintStyle: const TextStyle(color: Colors.white70),
                      labelStyle: const TextStyle(color: Colors.white),
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
                      suffixIcon: const Icon(Icons.person, color: Colors.white),
                    ),
                  ),
                  suggestionsCallback: (pattern) {
                    final lowercasePattern = pattern.toLowerCase();
                    return _allNames
                        .where((name) => name.contains(lowercasePattern))
                        .toList();
                  },
                  suggestionsBoxDecoration: SuggestionsBoxDecoration(
                    color: Colors.white,
                    elevation: 6.0,
                    borderRadius: BorderRadius.circular(12),
                    shadowColor: Colors.black.withOpacity(0.3),
                  ),
                  itemBuilder: (context, suggestion) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4.0,
                        horizontal: 12.0,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          suggestion,
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  },
                  onSuggestionSelected: (suggestion) {
                    _nameController.text = suggestion;
                  },
                  noItemsFoundBuilder:
                      (context) => Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Text(
                          'No match found',
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ),
                ),
              ),
            ),
            _isLoading
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
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
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
    ];
  }
}
