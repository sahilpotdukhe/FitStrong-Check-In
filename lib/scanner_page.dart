import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'checkin_service.dart';

/// The front desk screen: the camera runs continuously and every member who
/// holds up a code gets a card with their own face on it, so staff can see at
/// a glance that the person matches the code.
class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.gymId});

  final String gymId;

  @override
  State<ScannerPage> createState() => _ScannerPageState();
}

class _ScannerPageState extends State<ScannerPage> {
  late final CheckinService _service = CheckinService(gymId: widget.gymId);
  final MobileScannerController _camera = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );

  /// How long a result stays up before the desk is ready for the next person.
  static const Duration _showFor = Duration(seconds: 3);

  ScanResult? _result;
  bool _working = false;
  Timer? _clearResult;

  @override
  void dispose() {
    _clearResult?.cancel();
    _camera.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    // The camera keeps firing while a code is held up. One at a time, and
    // nothing new while a result is still on screen.
    if (_working || _result != null) return;

    final raw = capture.barcodes
        .map((b) => b.rawValue)
        .firstWhere((v) => v != null && v.isNotEmpty, orElse: () => null);
    if (raw == null) return;

    setState(() => _working = true);
    final result = await _service.handle(raw);
    if (!mounted) return;

    // A code that is not ours at all is ignored silently: the desk should not
    // flash a red card because somebody walked past with a boarding pass.
    if (result.outcome == ScanOutcome.notOurs) {
      setState(() => _working = false);
      return;
    }

    await _announce(result);
    if (!mounted) return;

    setState(() {
      _result = result;
      _working = false;
    });
    _clearResult?.cancel();
    _clearResult = Timer(_showFor, () {
      if (mounted) setState(() => _result = null);
    });
  }

  /// Staff are usually looking at the member, not the screen.
  Future<void> _announce(ScanResult result) async {
    if (result.recorded) {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } else {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out this device?'),
        content: const Text(
          'The desk will stop recording check-ins until somebody signs in '
          'again with the gym account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true) await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camera,
            onDetect: _onDetect,
            errorBuilder: (context, error) => _CameraProblem(error: error),
          ),
          // Dim the picture so the white cards stay readable.
          const DecoratedBox(
            decoration: BoxDecoration(color: Colors.black38),
            child: SizedBox.expand(),
          ),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: IconButton(
                    icon: const Icon(Icons.logout_rounded, color: Colors.white),
                    tooltip: 'Sign out',
                    onPressed: _signOut,
                  ),
                ),
                const Spacer(),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: _result == null
                      ? _Waiting(working: _working)
                      : _ResultCard(result: _result!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Waiting extends StatelessWidget {
  const _Waiting({required this.working});

  final bool working;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (working)
          const SizedBox(
            height: 28,
            width: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        else
          const Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 40),
        const SizedBox(height: 12),
        Text(
          working ? 'Checking…' : 'Hold your code up to the camera',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 17),
        ),
      ],
    );
  }
}

/// The card the desk actually reads: a face, a name, and what happened.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(result);
    final member = result.member;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: look.colour, width: 3),
      ),
      child: Row(
        children: [
          _Face(photoUrl: member?.photoUrl ?? '', colour: look.colour),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  member?.name.isNotEmpty == true ? member!.name : 'Unknown',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(look.icon, size: 18, color: look.colour),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        look.headline,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: look.colour,
                        ),
                      ),
                    ),
                  ],
                ),
                if (look.detail != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    look.detail!,
                    style: const TextStyle(fontSize: 13.5, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.photoUrl, required this.colour});

  final String photoUrl;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    const double size = 72;
    final fallback = Container(
      height: size,
      width: size,
      color: colour.withValues(alpha: 0.12),
      child: Icon(Icons.person_rounded, size: 36, color: colour),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: photoUrl.isEmpty
          ? fallback
          : CachedNetworkImage(
              imageUrl: photoUrl,
              height: size,
              width: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => fallback,
              errorWidget: (_, __, ___) => fallback,
            ),
    );
  }
}

/// How one outcome should look and read.
class _Look {
  const _Look(this.colour, this.icon, this.headline, [this.detail]);

  final Color colour;
  final IconData icon;
  final String headline;
  final String? detail;

  static _Look of(ScanResult result) {
    final time = result.at == null
        ? null
        : DateFormat('h:mm a').format(result.at!);

    switch (result.outcome) {
      case ScanOutcome.checkedIn:
        return _Look(const Color(0xFF15803D), Icons.login_rounded,
            'Checked in', time == null ? null : 'Arrived at $time');
      case ScanOutcome.checkedOut:
        return _Look(const Color(0xFF1D4ED8), Icons.logout_rounded,
            'Checked out', time == null ? null : 'Left at $time');
      case ScanOutcome.expired:
        return const _Look(Color(0xFFB91C1C), Icons.block_rounded,
            'Membership expired', 'Renew the plan before letting them in.');
      case ScanOutcome.unknown:
        return const _Look(Color(0xFFB91C1C), Icons.help_outline_rounded,
            'Code not recognised', 'This code has been replaced or removed.');
      case ScanOutcome.tooSoon:
        return _Look(const Color(0xFFB45309), Icons.history_rounded,
            'Already recorded',
            time == null ? null : 'Last scanned at $time');
      case ScanOutcome.failed:
        return const _Look(Color(0xFFB91C1C), Icons.wifi_off_rounded,
            'Could not save', 'Check the connection and scan again.');
      case ScanOutcome.notOurs:
        return const _Look(Color(0xFFB45309), Icons.qr_code_rounded,
            'Not a member code');
    }
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.error});

  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_rounded,
                  color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'Camera access is off for this app. Turn it on in '
                        'Android Settings, then reopen the app.'
                    : 'The camera could not start. Close the app and open '
                        'it again.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
