/// How someone uses Aelos; chosen at sign-in.
enum AccountRole {
  /// Owns their instruments and manages them themselves.
  owner,

  /// Rents an instrument from a luthier, who provides and manages the sensor.
  renter,

  /// Manages a fleet of rental instruments and their renters.
  luthier;

  String get label => switch (this) {
        AccountRole.owner => 'I own my instrument',
        AccountRole.renter => 'I rent from a luthier',
        AccountRole.luthier => 'I am a luthier',
      };
}

/// A signed-in person. Demo accounts only: there is no backend.
final class Account {
  const Account({
    required this.id,
    required this.name,
    required this.role,
    this.luthierId,
  });

  final String id;
  final String name;
  final AccountRole role;

  /// Renter: the luthier they are assigned to. Luthier: their own workshop.
  final String? luthierId;
}

/// A workshop that rents out instruments with sensors.
final class Luthier {
  const Luthier({
    required this.id,
    required this.workshop,
    required this.master,
    required this.city,
    required this.phone,
    required this.email,
  });

  final String id;

  /// E.g. "Atelier Brunner".
  final String workshop;

  /// The luthier's own name, e.g. "Martin Brunner".
  final String master;
  final String city;
  final String phone;
  final String email;
}

/// An instrument held by a luthier: rented out to [renterId], or in the
/// workshop when [renterId] is null.
final class Rental {
  const Rental({
    required this.instrumentId,
    required this.luthierId,
    this.renterId,
    this.renterName,
    this.since,
    this.plan,
  });

  final String instrumentId;
  final String luthierId;
  final String? renterId;
  final String? renterName;

  /// Start of the current rental.
  final DateTime? since;

  /// E.g. "Monthly rental · purchase option".
  final String? plan;

  bool get inWorkshop => renterId == null;

  Rental assignTo(String renterId, String renterName, DateTime since) => Rental(
        instrumentId: instrumentId,
        luthierId: luthierId,
        renterId: renterId,
        renterName: renterName,
        since: since,
        plan: plan,
      );

  Rental returnToWorkshop() =>
      Rental(instrumentId: instrumentId, luthierId: luthierId, plan: plan);
}
