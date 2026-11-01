import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fitstrong_core/fitstrong_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import 'checkin_service.dart';
import 'developer_credit.dart';

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
    // The tablet sits facing the member across the desk, so the screen-side
    // camera is the one pointing at them. Switchable for a desk laid out the
    // other way round.
    facing: CameraFacing.front,
  );

  /// How long a result stays up before the desk is ready for the next person.
  static const Duration _showFor = Duration(seconds: 3);

  ScanResult? _result;
  bool _working = false;
  Timer? _clearResult;

  @override
  void initState() {
    super.initState();
    // Pulls this gym's members onto the tablet and keeps them there, so a
    // scan still finds the right person when the Wi-Fi is down.
    _service.start();
  }

  @override
  void dispose() {
    _clearResult?.cancel();
    _service.dispose();
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
  ///
  /// Three sounds, not two, so the desk can tell what happened without
  /// looking up: one click means in and paid, two clicks mean in but money
  /// is owed, and the alert buzz means turned away.
  Future<void> _announce(ScanResult result) async {
    // Checked first: a member owing money is also a recorded arrival, and
    // the two beeps are the whole point of telling them apart.
    if (result.outcome == ScanOutcome.paymentDue) {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.click);
      await Future<void>.delayed(const Duration(milliseconds: 160));
      await SystemSound.play(SystemSoundType.click);
      return;
    }

    if (result.recorded) {
      await HapticFeedback.mediumImpact();
      await SystemSound.play(SystemSoundType.click);
    } else {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    }
  }

  Future<void> _switchCamera() async {
    try {
      await _camera.switchCamera();
    } catch (error) {
      debugPrint('Could not switch camera: $error');
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
                Row(
                  children: [
                    Expanded(child: _PendingChip(service: _service)),
                    IconButton(
                      icon: const Icon(Icons.info_outline_rounded,
                          color: Colors.white),
                      tooltip: 'About this app',
                      onPressed: () => showDeveloperSheet(context),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cameraswitch_rounded,
                          color: Colors.white),
                      tooltip: 'Switch camera',
                      onPressed: _switchCamera,
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.logout_rounded, color: Colors.white),
                      tooltip: 'Sign out',
                      onPressed: _signOut,
                    ),
                  ],
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Center(
                      child: _result == null
                          ? _Waiting(working: _working)
                          : _ResultCard(result: _result!),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Quietly says how many check-ins are saved here but not yet sent.
///
/// Staff need to know the desk is behind without being alarmed by it — the
/// records are safe, they are just waiting. It disappears entirely when
/// there is nothing queued, which is almost always.
class _PendingChip extends StatelessWidget {
  const _PendingChip({required this.service});

  final CheckinService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: service.pendingCount(),
      builder: (context, snapshot) {
        final waiting = snapshot.data ?? 0;
        if (waiting == 0) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFB45309),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off_rounded,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '$waiting waiting to sync',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
            height: 44,
            width: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation(Colors.white),
            ),
          )
        else
          const Icon(Icons.qr_code_2_rounded, color: Colors.white70, size: 72),
        const SizedBox(height: 18),
        Text(
          working ? 'Checking…' : 'Hold your code up to the camera',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The card the desk actually reads. Deliberately large: staff glance at it
/// from a step away while the member is still walking past.
class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final look = _Look.of(result);
    final member = result.member;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: look.colour, width: 5),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 30, spreadRadius: 4),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Face(photoUrl: member?.photoUrl ?? '', colour: look.colour),
          const SizedBox(height: 20),
          Text(
            member?.name.isNotEmpty == true ? member!.name : 'Unknown',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          // The status reads as a band of colour, so the outcome is clear
          // before anybody has read a word of it.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: look.colour.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(look.icon, size: 26, color: look.colour),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    look.headline,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: look.colour,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (look.detail != null) ...[
            const SizedBox(height: 12),
            Text(
              look.detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 17, color: Colors.black54),
            ),
          ],
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
    const double size = 150;
    final fallback = Container(
      height: size,
      width: size,
      color: colour.withValues(alpha: 0.12),
      child: Icon(Icons.person_rounded, size: 76, color: colour),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
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
      case ScanOutcome.paymentDue:
        // Amber, not red: the member is in. The desk's job is to ask for the
        // money, not to stop them at the door.
        return _Look(
          const Color(0xFFB45309),
          Icons.payments_outlined,
          'Payment due',
          'Checked in. ${_overdue(result.member)}',
        );
      case ScanOutcome.checkedIn:
        return _Look(const Color(0xFF15803D), Icons.check_circle_rounded,
            'Checked in', time == null ? null : 'Marked present at $time');
      case ScanOutcome.queued:
        // Green like a normal check-in, because to the member it is one:
        // they are in, and the record is safe. Only the wording differs.
        return _Look(const Color(0xFF15803D), Icons.cloud_off_rounded,
            'Checked in', 'Saved on this tablet. It will sync when the '
                'internet is back.');
      case ScanOutcome.expired:
        return _Look(
          const Color(0xFFB91C1C),
          Icons.block_rounded,
          'Membership expired',
          '${_endedLabel(result.member)} The time to pay has run out — '
              'renew the plan before letting them in.',
        );
      case ScanOutcome.unknown:
        return const _Look(Color(0xFFB91C1C), Icons.help_outline_rounded,
            'Code not recognised', 'This code has been replaced or removed.');
      case ScanOutcome.alreadyIn:
        // The payment is repeated here because the desk may have missed it
        // on the first scan of the day, and this is the only other card a
        // member who owes money can land on.
        final seen = time == null ? null : 'Marked present at $time';
        final owes = _isPaymentDue(result.member);
        return _Look(
          const Color(0xFFB45309),
          Icons.check_circle_outline,
          owes ? 'Already in · payment due' : 'Already checked in',
          owes
              ? [if (seen != null) seen, _overdue(result.member)].join(' · ')
              : seen,
        );
      case ScanOutcome.failed:
        return const _Look(Color(0xFFB91C1C), Icons.wifi_off_rounded,
            'Could not save', 'Check the connection and scan again.');
      case ScanOutcome.notOurs:
        return const _Look(Color(0xFFB45309), Icons.qr_code_rounded,
            'Not a member code');
    }
  }

  static bool _isPaymentDue(ScannedMember? member) =>
      member != null &&
      member.accessAt(DateTime.now()) == MembershipAccess.paymentDue;

  /// "Plan ended 3 days ago." — or today, or yesterday, said the way the
  /// desk would say it out loud.
  static String _endedLabel(ScannedMember? member) {
    final expiry = member?.expiryDate;
    if (expiry == null) return 'This membership has no end date on record.';

    final days = CheckinRules.daysSinceExpiry(expiry, DateTime.now());
    if (days <= 0) return 'Plan ended today.';
    if (days == 1) return 'Plan ended yesterday.';
    return 'Plan ended $days days ago.';
  }

  /// How far past the end they are, and how long is left to settle up.
  static String _overdue(ScannedMember? member) {
    final expiry = member?.expiryDate;
    if (expiry == null) return 'Payment is due.';

    final left = CheckinRules.graceDaysLeft(expiry, DateTime.now());
    final days = left == 1 ? '1 day' : '$left days';
    return '${_endedLabel(member)} $days left to renew.';
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
