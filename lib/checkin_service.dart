import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fitstrong_core/fitstrong_core.dart';
import 'package:flutter/foundation.dart';

/// What the desk should show after a code was held up.
enum ScanOutcome {
  checkedIn,

  /// Recorded on the tablet, but the gym's Wi-Fi was down so it has not
  /// reached the server yet. It will send itself when the network is back.
  queued,

  /// Not one of our codes at all: a payment QR, a Wi-Fi code, a poster.
  notOurs,

  /// Our format, but no member has this token. A revoked or deleted code.
  unknown,

  /// Found them, but their plan has run out.
  expired,

  /// Already recorded today, so nothing was written.
  alreadyIn,

  failed,
}

class ScanResult {
  const ScanResult(this.outcome, {this.member, this.at});

  final ScanOutcome outcome;
  final ScannedMember? member;
  final DateTime? at;

  /// Whether an arrival was written down.
  ///
  /// A queued record counts: it is on the tablet's disk and will sync. The
  /// member was let in either way, so the desk gets the same happy chime.
  bool get recorded =>
      outcome == ScanOutcome.checkedIn || outcome == ScanOutcome.queued;
}

/// Turns a scanned string into an attendance record.
///
/// Every query runs under this gym's own document, so a code from another
/// gym is simply never found.
///
/// The desk has to keep working when the gym's Wi-Fi drops, so nothing here
/// waits on the network indefinitely. Firestore keeps its own on-disk queue
/// of writes and its own cache of what has been read; this class leans on
/// both, and gives up on the server quickly rather than freezing the screen.
class CheckinService {
  CheckinService({required this.gymId, FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final String gymId;
  final FirebaseFirestore _db;

  /// How long anything is allowed to wait on the server before the tablet
  /// falls back to what it already has. Long enough for a slow connection,
  /// short enough that staff are not left staring at a spinner.
  static const Duration serverWait = Duration(seconds: 4);

  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _memberCache;

  /// Starts keeping this gym's members in Firestore's own on-disk cache.
  ///
  /// Without this, an offline lookup only finds members who happen to have
  /// been scanned while the Wi-Fi was up, and everybody else is turned away
  /// with "code not recognised" — the worst possible answer to give a paying
  /// member. Keeping the list warm costs one read per member change.
  void start() {
    _memberCache ??= _members.snapshots().listen(
          (_) {},
          onError: (Object error) =>
              debugPrint('Could not keep the member list cached: $error'),
        );
  }

  void dispose() {
    _memberCache?.cancel();
    _memberCache = null;
  }

  /// How many of today's arrivals are written but not yet on the server.
  ///
  /// Reaches back a day as well, so a desk left running through a long
  /// overnight outage still shows what is waiting.
  Stream<int> pendingCount() {
    final from = CheckinRules.startOfDay(DateTime.now())
        .subtract(const Duration(days: 1));

    return _attendance
        .where(AttendanceFields.deviceAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        // Without this the stream only fires on data changes, and a record
        // finally syncing is a metadata change.
        .snapshots(includeMetadataChanges: true)
        .map((snapshot) =>
            snapshot.docs.where((d) => d.metadata.hasPendingWrites).length)
        .handleError((Object error) {
      debugPrint('Could not count queued check-ins: $error');
    });
  }

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
    if (CheckinRules.alreadyRecordedToday(last)) return ScanOutcome.alreadyIn;

    return ScanOutcome.checkedIn;
  }

  Future<ScanResult> handle(String raw) async {
    // Costs nothing, and throws out every other QR at the desk before it
    // reaches the database.
    final token = CheckinCode.decode(raw);
    if (token == null) return const ScanResult(ScanOutcome.notOurs);

    final ScannedMember? member;
    final Attendance? last;
    try {
      member = await _memberWithToken(token);
      last = member == null ? null : await _lastScanToday(member.id);
    } catch (error) {
      debugPrint('Scan lookup failed: $error');
      return const ScanResult(ScanOutcome.failed);
    }

    final now = DateTime.now();
    final outcome = decide(token: token, member: member, last: last, now: now);

    if (outcome != ScanOutcome.checkedIn) {
      return ScanResult(
        outcome,
        member: member,
        at: outcome == ScanOutcome.alreadyIn ? last?.at : null,
      );
    }

    return _record(member!, now);
  }

  /// Writes the arrival, without hanging the desk if the server is gone.
  ///
  /// Firestore only completes a write's future once the server has confirmed
  /// it, so awaiting one on a tablet with no Wi-Fi waits forever. The write
  /// is still safe — it is on disk and sends itself later — so after a short
  /// wait the desk is told it is queued rather than left on a spinner.
  Future<ScanResult> _record(ScannedMember member, DateTime now) async {
    final write = _attendance.add(Attendance.newRecord(
      memberId: member.id,
      memberName: member.name,
      source: AttendanceSource.scanner,
      now: now,
    ));

    // Watched on its own, so a write rejected long after the desk has moved
    // on is logged instead of surfacing as an unhandled error.
    unawaited(write.then(
      (_) {},
      onError: (Object error) =>
          debugPrint('A queued check-in was rejected: $error'),
    ));

    try {
      await write.timeout(serverWait);
      // The stored time comes from the server; this is only what the desk
      // shows for a moment, so the device clock is good enough.
      return ScanResult(ScanOutcome.checkedIn, member: member, at: now);
    } on TimeoutException {
      // Not a failure. Saying "could not save" here would send staff to scan
      // again, and the duplicate check would then have two records to
      // reconcile — so the honest answer is that it is saved and waiting.
      return ScanResult(ScanOutcome.queued, member: member, at: now);
    } catch (error) {
      // The server answered and refused: wrong rules, bad data. Retrying
      // will not help, so this one really is a failure.
      debugPrint('Check-in refused: $error');
      return const ScanResult(ScanOutcome.failed);
    }
  }

  Future<ScannedMember?> _memberWithToken(String token) async {
    final query =
        _members.where(MemberFields.checkinToken, isEqualTo: token).limit(1);

    final snapshot = await _fromServerOrCache(query);
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return ScannedMember.fromDoc(doc.id, doc.data());
  }

  /// The member's record for today, if they have been in.
  ///
  /// Keyed on the device clock rather than the server stamp on purpose: a
  /// write still sitting in the offline queue has no server stamp yet, so a
  /// server-keyed query cannot see it and the same member would be recorded
  /// twice on a tablet with no Wi-Fi.
  Future<Attendance?> _lastScanToday(String memberId) async {
    final dayStart = CheckinRules.startOfDay(DateTime.now());
    final query = _attendance
        .where(AttendanceFields.memberId, isEqualTo: memberId)
        .where(AttendanceFields.deviceAt,
            isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .orderBy(AttendanceFields.deviceAt, descending: true)
        .limit(1);

    final snapshot = await _fromServerOrCache(query);
    if (snapshot.docs.isEmpty) return null;
    final doc = snapshot.docs.first;
    return Attendance.fromDoc(doc.id, doc.data());
  }

  /// Asks the server, and settles for the tablet's own copy if it cannot be
  /// reached in time. A cache read also includes writes still queued here.
  Future<QuerySnapshot<Map<String, dynamic>>> _fromServerOrCache(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get().timeout(serverWait);
    } catch (error) {
      debugPrint('Falling back to the cached copy: $error');
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  DocumentReference<Map<String, dynamic>> get _gym =>
      _db.collection(MemberFields.gyms).doc(gymId);

  CollectionReference<Map<String, dynamic>> get _members =>
      _gym.collection(MemberFields.collection);

  CollectionReference<Map<String, dynamic>> get _attendance =>
      _gym.collection(MemberFields.attendance);
}
