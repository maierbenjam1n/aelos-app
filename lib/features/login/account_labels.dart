import '../../data/accounts.dart';
import '../../domain/models/account.dart';

extension AccountRoleTitle on AccountRole {
  /// One word for the role, e.g. in the account menu.
  String get title => switch (this) {
        AccountRole.owner => 'Owner',
        AccountRole.renter => 'Renter',
        AccountRole.luthier => 'Luthier',
      };
}

extension AccountSummary on Account {
  Luthier? get luthier => DemoDirectory.luthierById(luthierId);

  /// "Renter · Atelier Brunner, Luzern".
  String get roleLine {
    final workshop = luthier;
    return switch (role) {
      AccountRole.owner => 'Owner · private collection',
      AccountRole.renter when workshop != null =>
        'Renter · ${workshop.workshop}, ${workshop.city}',
      AccountRole.luthier when workshop != null =>
        'Luthier · ${workshop.workshop}, ${workshop.city}',
      _ => role.title,
    };
  }
}

const _months = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];

/// "1 September 2026".
String formatDay(DateTime day) =>
    '${day.day} ${_months[day.month - 1]} ${day.year}';
