/// Distributor Outlet (DO) — a retail outlet / sub-agency of the main
/// gas distributor.
///
/// Every [Customer] is linked to exactly one DO. `code` is a short unique
/// tag (e.g., "AA", "AB") used as a quick display chip in the UI and as
/// the primary key in the business sense.
class DistributorOutlet {
  final int id;
  final String code;
  final String ownerName;
  final String location;
  final bool isActive;
  final bool isDeleted;

  DistributorOutlet({
    required this.id,
    required this.code,
    required this.ownerName,
    required this.location,
    required this.isActive,
    this.isDeleted = false,
  });

  /// One-line label for dropdowns and typeahead results.
  String get display => '$code — $ownerName — $location';

  factory DistributorOutlet.fromJson(Map<String, dynamic> j) => DistributorOutlet(
        id: j['id'] as int,
        code: j['code'] as String? ?? '',
        ownerName: j['owner_name'] as String? ?? '',
        location: j['location'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? true,
        isDeleted: j['is_deleted'] as bool? ?? false,
      );

  /// Body for `POST /api/distributor-outlets`. Code is uppercased and
  /// trimmed so "aa " and "AA" both end up as "AA".
  Map<String, dynamic> toCreateJson() => {
        'code': code.trim().toUpperCase(),
        'owner_name': ownerName,
        'location': location,
        'is_active': isActive,
      };

  /// Body for `PUT /api/distributor-outlets/{id}`. Active flag is toggled
  /// via the dedicated `/active` endpoint instead of this update body.
  Map<String, dynamic> toUpdateJson() => {
        'code': code.trim().toUpperCase(),
        'owner_name': ownerName,
        'location': location,
      };
}
