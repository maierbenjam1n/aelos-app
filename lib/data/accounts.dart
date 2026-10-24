import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/models/account.dart';
import '../domain/models/event_report.dart';
import 'instrument_data.dart';
import 'instruments_notifier.dart';

/// The demo's fixed cast. No backend: sign-in just picks one of these.
abstract final class DemoDirectory {
  static const brunner = Luthier(
    id: 'atelier-brunner',
    workshop: 'Atelier Brunner',
    master: 'Martin Brunner',
    city: 'Luzern',
    phone: '+41 41 210 18 90',
    email: 'atelier@brunner-geigenbau.ch',
  );

  static const owner = Account(id: 'elena-brandt', name: 'Elena Brandt', role: AccountRole.owner);
  static const renter = Account(
    id: 'noah-keller',
    name: 'Noah Keller',
    role: AccountRole.renter,
    luthierId: 'atelier-brunner',
  );
  static const luthier = Account(
    id: 'martin-brunner',
    name: 'Martin Brunner',
    role: AccountRole.luthier,
    luthierId: 'atelier-brunner',
  );

  static const luthiers = [brunner];

  static Account accountFor(AccountRole role) => switch (role) {
        AccountRole.owner => owner,
        AccountRole.renter => renter,
        AccountRole.luthier => luthier,
      };

  static Luthier? luthierById(String? id) =>
      luthiers.where((l) => l.id == id).firstOrNull;

  /// Instruments held by luthiers. Everything else belongs to the owner.
  static final rentals = [
    Rental(
      instrumentId: 'cello-mirecourt',
      luthierId: brunner.id,
      renterId: renter.id,
      renterName: renter.name,
      since: DateTime.utc(2026, 9, 1),
      plan: 'Monthly rental · purchase option',
    ),
    Rental(
      instrumentId: 'viola-cremona',
      luthierId: brunner.id,
      renterId: 'lea-meier',
      renterName: 'Lea Meier',
      since: DateTime.utc(2026, 8, 15),
      plan: 'Monthly rental',
    ),
  ];
}

final accountProvider = NotifierProvider<AccountNotifier, Account?>(AccountNotifier.new);

/// Who is signed in; null shows the sign-in screen.
class AccountNotifier extends Notifier<Account?> {
  @override
  Account? build() => null;

  void signIn(AccountRole role) => state = DemoDirectory.accountFor(role);

  void signOut() => state = null;
}

final rentalsProvider = NotifierProvider<RentalsNotifier, List<Rental>>(RentalsNotifier.new);

/// Which instruments luthiers hold and who rents them; editable by the
/// luthier in the demo.
class RentalsNotifier extends Notifier<List<Rental>> {
  @override
  List<Rental> build() => DemoDirectory.rentals;

  Rental? forInstrument(String instrumentId) =>
      state.where((r) => r.instrumentId == instrumentId).firstOrNull;

  void assign(String instrumentId, {required String renterId, required String renterName}) =>
      _update(instrumentId, (r) => r.assignTo(renterId, renterName, DateTime.now().toUtc()));

  void returnToWorkshop(String instrumentId) => _update(instrumentId, (r) => r.returnToWorkshop());

  void _update(String instrumentId, Rental Function(Rental) change) => state = [
        for (final r in state) r.instrumentId == instrumentId ? change(r) : r,
      ];
}

/// The instruments the signed-in account sees: an owner's own, a renter's
/// rentals, or a luthier's whole fleet (rented out and in the workshop).
final visibleInstrumentsProvider = Provider<List<InstrumentData>>((ref) {
  final all = ref.watch(instrumentsProvider).value ?? const [];
  final account = ref.watch(accountProvider);
  final rentals = ref.watch(rentalsProvider);
  if (account == null) return const [];
  bool keep(InstrumentData i) {
    final rental = rentals.where((r) => r.instrumentId == i.id).firstOrNull;
    return switch (account.role) {
      AccountRole.owner => rental == null,
      AccountRole.renter => rental?.renterId == account.id,
      AccountRole.luthier => rental?.luthierId == account.luthierId,
    };
  }

  return [for (final i in all) if (keep(i)) i];
});

/// The instrument whose sensor the demo streams live: the owner's violin,
/// the renter's first rental, or for a luthier the first instrument rented
/// out (a real luthier would see it through a backend; here it is the same
/// phone, so switching roles keeps one live sensor in the story).
final liveInstrumentIdProvider = Provider<String?>((ref) {
  final account = ref.watch(accountProvider);
  return switch (account?.role) {
    AccountRole.owner => 'violin-mittenwald',
    AccountRole.renter => ref
        .watch(rentalsProvider)
        .where((r) => r.renterId == account!.id)
        .firstOrNull
        ?.instrumentId,
    AccountRole.luthier => ref
        .watch(rentalsProvider)
        .where((r) => r.luthierId == account!.luthierId && !r.inWorkshop)
        .firstOrNull
        ?.instrumentId,
    null => null,
  };
});

final eventReportsProvider =
    NotifierProvider<EventReportsNotifier, List<EventReport>>(EventReportsNotifier.new);

/// Documented events, newest first. Starts with one report from another
/// renter so the luthier's inbox isn't empty.
class EventReportsNotifier extends Notifier<List<EventReport>> {
  @override
  List<EventReport> build() => [
        EventReport(
          id: 'report-viola-fall',
          instrumentId: 'viola-cremona',
          eventSeq: null,
          eventTitle: 'Drop recorded · 230 ms',
          eventTime: DateTime.utc(2026, 10, 18, 16, 31, 7),
          explanation: 'The case slipped off the music stand trolley after rehearsal and '
              'landed on its side. The instrument stayed in the case.',
          causes: const ['Case was dropped'],
          photos: [
            ReportPhoto(
              angle: PhotoAngle.front,
              takenAt: DateTime.utc(2026, 10, 18, 17, 2),
              assetPath: 'assets/photos/viola.jpg',
            ),
          ],
          authorId: 'lea-meier',
          authorName: 'Lea Meier',
          createdAt: DateTime.utc(2026, 10, 18, 17, 5),
          luthierId: DemoDirectory.brunner.id,
        ),
      ];

  void submit(EventReport report) => state = [report, ...state];

  void updateStatus(String id, ReportStatus status, {String? note}) => state = [
        for (final r in state) r.id == id ? r.copyWith(status: status, luthierNote: note) : r,
      ];

  List<EventReport> forInstrument(String instrumentId) =>
      [for (final r in state) if (r.instrumentId == instrumentId) r];
}
