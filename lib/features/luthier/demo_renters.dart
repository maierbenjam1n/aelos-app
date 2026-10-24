/// A renter's contact card. Demo people only; the workshop's address book
/// would come from a backend.
final class RenterContact {
  const RenterContact({
    required this.id,
    required this.name,
    required this.note,
    required this.email,
    required this.phone,
  });

  final String id;
  final String name;

  /// E.g. "Student, Musikschule Luzern".
  final String note;
  final String email;
  final String phone;
}

abstract final class DemoRenters {
  static const all = [
    RenterContact(
      id: 'noah-keller',
      name: 'Noah Keller',
      note: 'Cellist, Luzerner Sinfonieorchester academy',
      email: 'noah.keller@bluewin.ch',
      phone: '+41 79 402 18 77',
    ),
    RenterContact(
      id: 'lea-meier',
      name: 'Lea Meier',
      note: 'Violist, string quartet',
      email: 'lea.meier@gmx.ch',
      phone: '+41 78 615 30 12',
    ),
    RenterContact(
      id: 'sofia-bianchi',
      name: 'Sofia Bianchi',
      note: 'Student, Musikschule Luzern · age 11',
      email: 'familie.bianchi@sunrise.ch',
      phone: '+41 76 330 41 09',
    ),
    RenterContact(
      id: 'jonas-frei',
      name: 'Jonas Frei',
      note: 'Cellist, Hochschule Luzern',
      email: 'jonas.frei@hslu.ch',
      phone: '+41 79 888 06 54',
    ),
    RenterContact(
      id: 'anna-roth',
      name: 'Anna Roth',
      note: 'Amateur violinist, Kriens',
      email: 'anna.roth@hispeed.ch',
      phone: '+41 77 214 59 30',
    ),
    RenterContact(
      id: 'luca-steiner',
      name: 'Luca Steiner',
      note: 'Student, Kantonsschule Alpenquai',
      email: 'luca.steiner@edulu.ch',
      phone: '+41 78 902 77 41',
    ),
    RenterContact(
      id: 'clara-wyss',
      name: 'Clara Wyss',
      note: 'Freelance violinist, Zürich',
      email: 'clara@wyss-music.ch',
      phone: '+41 79 551 23 60',
    ),
  ];

  static RenterContact? byId(String? id) => all.where((r) => r.id == id).firstOrNull;
}
