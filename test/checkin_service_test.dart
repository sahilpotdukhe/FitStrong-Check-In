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

Attendance scan(CheckinType type, DateTime at) {
  return Attendance(
    id: 'a1',
    memberId: 'm1',
    memberName: 'Asha',
    at: at,
    type: type,
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
          last: scan(CheckinType.checkIn, now.subtract(const Duration(hours: 2))),
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

    test('checks them out when they are already in', () {
      expect(
        decide(
          who: member(),
          last: scan(CheckinType.checkIn, now.subtract(const Duration(hours: 2))),
        ),
        ScanOutcome.checkedOut,
      );
    });

    test('checks them back in after they have left', () {
      expect(
        decide(
          who: member(),
          last: scan(
              CheckinType.checkOut, now.subtract(const Duration(hours: 2))),
        ),
        ScanOutcome.checkedIn,
      );
    });
  });

  group('the camera reading the same code twice', () {
    test('the repeat is refused', () {
      // Without this the next frame would check the member straight back
      // out, and they would walk in already marked gone.
      expect(
        decide(
          who: member(),
          last: scan(
              CheckinType.checkIn, now.subtract(const Duration(seconds: 2))),
        ),
        ScanOutcome.tooSoon,
      );
    });

    test('a real scan later in the day still counts', () {
      expect(
        decide(
          who: member(),
          last: scan(
              CheckinType.checkIn, now.subtract(const Duration(minutes: 90))),
        ),
        ScanOutcome.checkedOut,
      );
    });
  });
}
