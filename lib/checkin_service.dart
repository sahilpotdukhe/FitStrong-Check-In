import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitstrong_core/fitstrong_core.dart';
import 'package:flutter/foundation.dart';

/// What the desk should show after a code was held up.
enum ScanOutcome {
  checkedIn,
  checkedOut,

  /// Not one of our codes at all: a payment QR, a Wi-Fi code, a poster.
  notOurs,

  /// Our format, but no member has this token. A revoked or deleted code.
  unknown,

  /// Found them, but their plan has run out.
  expired,

  /// The camera reading the same code again moments later.
  tooSoon,

  failed,
}

class ScanResult {
  const ScanResult(this.outcome, {this.member, this.at});

  final ScanOutcome outcome;
  final ScannedMember? member;
  final DateTime? at;

  bool get recorded =>
      outcome == ScanOutcome.checkedIn || outcome == ScanOutcome.checkedOut;
}

/// Turns a scanned string into an attendance record.
///
/// Every query runs under this gym's own document, so a code from another
/// gym is simply never found.
class CheckinService {
  CheckinService({required this.gymId, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String gymId;
  final FirebaseFirestore _db;

  /// What a scan means, given everything already looked up.
  ///
  /// Kept apart from the database so every branch the desk can hit is
  /// covered by tests without a Firestore standing in.
  @visibleForTesting
  static ScanOutcome decide({
    required String? token,
    required ScannedMember? member,
    required Attendance? last,
    required DateTime now,
  }) {
    if (token == null) return ScanOutcome.notOurs;
    if (member == null) return ScanOutcome.unknown;
    if (member.isExpiredAt(now)) return ScanOutcome.expired;
    if (CheckinRules.isRepeatScan(last, now)) return ScanOutcome.tooSoon;

    return CheckinRules.nextType(last) == CheckinType.checkIn
        ? ScanOutcome.checkedIn
        : ScanOutcome.checkedOut;
  }

  Future<ScanResult> handle(String raw) async {
    // Costs nothing, and throws out every other QR at the desk before it
    // reaches the database.
    final token = CheckinCode.decode(raw);
    if (token == null) return const ScanResult(ScanOutcome.notOurs);

    try {
      final member = await _memberWithToken(token);
      final last =
          member == null ? null : await _lastScanToday(member.id);
      final now = DateTime.now();

      final outcome =
          decide(token: token, member: member, last: last, now: now);

      if (outcome != ScanOutcome.checkedIn &&
          outcome != ScanOutcome.checkedOut) {
        return ScanResult(
          outcome,
          member: member,
          at: outcome == ScanOutcome.tooSoon ? last?.at : null,
        );
      }

      final type = CheckinRules.nextType(last);
      await _attendance.add(Attendance.newRecord(
        memberId: member!.id,
        memberName: member.name,
        type: type,
        source: AttendanceSource.scanner,
      ));

      // The stored time comes from the server; this is only what the desk
      // shows for a moment, so the device clock is good enough.
      return ScanResult(outcome, member: member, at: now);
    } catch (error) {
      debugPrint('Scan failed: $error');
      return const ScanResult(ScanOutcome.failed);
    }
  }

  Future<ScannedMember?> _memberWithToken(String token) async {
    final snapshot = await _members
        .where(MemberFields.checkinToken, isEqualTo: token)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ScannedMember.fromDoc(doc.id, doc.data());
  }

  Future<Attendance?> _lastScanToday(String memberId) async {
    final dayStart = CheckinRules.startOfDay(DateTime.now());
    final snapshot = await _attendance
        .where(AttendanceFields.memberId, isEqualTo: memberId)
        .where(AttendanceFields.at,
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .orderBy(AttendanceFields.at, descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Attendance.fromDoc(doc.id, doc.data());
  }

  DocumentReference<Map<String, dynamic>> get _gym =>
      _db.collection(MemberFields.gyms).doc(gymId);

  CollectionReference<Map<String, dynamic>> get _members =>
      _gym.collection(MemberFields.collection);

  CollectionReference<Map<String, dynamic>> get _attendance =>
      _gym.collection(MemberFields.attendance);
}
