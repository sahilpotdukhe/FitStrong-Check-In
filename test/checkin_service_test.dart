import 'package:fitstrong_core/fitstrong_core.dart';
import 'package:fitstrongcheckin/checkin_service.dart';
import 'package:flutter_test/flutter_test.dart';

final now = DateTime(2026, 3, 9, 7, 5);

ScannedMember member({Duration expiresIn = const Duration(days: 30)}) {
  return ScannedMember(
    id: 'm1',
    name: 'Asha',
    photoUrl: '',
    expiryDate: now.add(expiresIn),
  );
}

Attendance scan(DateTime at) {
  return Attendance(
    id: 'a1',
    memberId: 'm1',
    memberName: 'Asha',
    at: at,
    source: AttendanceSource.scanner,
  );
}

/// Defaults to a member in good standing, so each test names only the one
/// thing it is about.
ScanOutcome decide({
  String? token = 'tok-1',
  ScannedMember? who,
  Attendance? last,
}) {
  return CheckinService.decide(
    token: token,
    member: who,
    last: last,
    now: now,
  );
}

void main() {
  group('a QR that is not ours', () {
    test('is ignored before anybody is looked up', () {
      // A payment or Wi-Fi code held up at the desk should not flash a red
      // card, and should never cost a database read.
      expect(decide(token: null, who: member()), ScanOutcome.notOurs);
    });
  });

  group('a code nobody holds', () {
    test('is not recognised', () {
      // Revoked, or the member was deleted. Either way nobody matches.
      expect(decide(who: null), ScanOutcome.unknown);
    });
  });

  group('an expired membership', () {
    test('is turned away', () {
      expect(
        decide(who: member(expiresIn: const Duration(days: -1))),
        ScanOutcome.expired,
      );
    });

    test('is checked before the in/out rule, so no record is written', () {
      // Even mid-session, an expired plan must not produce a check out that
      // implies the visit was allowed.
      expect(
        decide(
          who: member(expiresIn: const Duration(days: -1)),
          last: scan(now.subtract(const Duration(hours: 2))),
        ),
        ScanOutcome.expired,
      );
    });

    test('a member with no readable expiry is refused', () {
      const broken = ScannedMember(
        id: 'm1',
        name: 'Asha',
        photoUrl: '',
        expiryDate: null,
      );
      expect(decide(who: broken), ScanOutcome.expired);
    });
  });

  group('a good code', () {
    test('checks a member in when they have not been in today', () {
      expect(decide(who: member()), ScanOutcome.checkedIn);
    });


  });

  group('a check-in that has not reached the server yet', () {
    test('counts as recorded, so the desk gives the normal happy signal', () {
      // The member is standing there and has been let in. The record is on
      // the tablet's disk and will send itself. Buzzing an error at staff
      // would send them to scan again and create a duplicate.
      const queued = ScanResult(ScanOutcome.queued);
      expect(queued.recorded, isTrue);
    });

    test('a refused write is not treated as recorded', () {
      // The server answered and said no. Nothing is waiting to sync.
      const failed = ScanResult(ScanOutcome.failed);
      expect(failed.recorded, isFalse);
    });

    test('a normal check-in is still recorded', () {
      expect(const ScanResult(ScanOutcome.checkedIn).recorded, isTrue);
    });

    test('nothing else counts as a record', () {
      for (final outcome in [
        ScanOutcome.notOurs,
        ScanOutcome.unknown,
        ScanOutcome.expired,
        ScanOutcome.alreadyIn,
      ]) {
        expect(ScanResult(outcome).recorded, isFalse, reason: '\$outcome');
      }
    });
  });

  group('a member who is already marked present', () {
    test('a second scan records nothing', () {
      // Also covers the camera reading the same code many times a second
      // while it is held up to the lens.
      expect(
        decide(
          who: member(),
          last: scan(now.subtract(const Duration(seconds: 2))),
        ),
        ScanOutcome.alreadyIn,
      );
    });

    test('still nothing hours later on the same day', () {
      expect(
        decide(
          who: member(),
          last: scan(now.subtract(const Duration(hours: 6))),
        ),
        ScanOutcome.alreadyIn,
      );
    });
  });
}
