import '../utils/schedule_parser.dart';

class Parish {
  final String name;
  final String? parishId;
  final String address;
  final String city;
  final String zipCode;
  final String phone;
  final String website;
  final List<ScheduleEntry> massTimes;
  final List<ScheduleEntry> confTimes;
  final List<ScheduleEntry> adoration;

  /// True when the parish offers perpetual (24/7) adoration. When set,
  /// [adoration] is typically empty — render a single "Perpetual" card.
  final bool adorationIsPerpetual;
  final String? eventsSummary;
  final String? contactInfo;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? bulletinUrl;
  final DateTime? lastUpdated;

  Parish({
    required this.name,
    this.parishId,
    required this.address,
    required this.city,
    required this.zipCode,
    required this.phone,
    required this.website,
    required this.massTimes,
    required this.confTimes,
    this.adoration = const [],
    this.adorationIsPerpetual = false,
    this.eventsSummary,
    this.contactInfo,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.bulletinUrl,
    this.lastUpdated,
  });

  /// True if the parish has any adoration to show (timed slots or perpetual).
  bool get hasAdoration => adorationIsPerpetual || adoration.isNotEmpty;

  factory Parish.fromJson(Map<String, dynamic> json) {
    // Handle zipCode as either int or String
    final zipCodeString =
        json['zip_code'] != null ? json['zip_code'].toString() : '';

    // Structured schedules: { mass: [...], confession: [...], adoration: {...} }
    final schedules =
        json['schedules'] is Map<String, dynamic> ? json['schedules'] as Map<String, dynamic> : const {};

    final adorationJson = schedules['adoration'];
    bool perpetual = false;
    List<ScheduleEntry> adorationEntries = [];
    if (adorationJson is Map<String, dynamic>) {
      perpetual = adorationJson['is_perpetual'] == true;
      adorationEntries = ScheduleEntry.listFromJson(adorationJson['times']);
    }

    return Parish(
      name: json['name'] ?? 'Unknown',
      parishId: json['parish_id'],
      address: json['address'] ?? 'No address provided',
      city: json['city'] ?? 'Unknown city',
      zipCode: zipCodeString,
      phone: json['phone'] ?? 'No Phone Listed',
      website: json['website'] ?? 'No Website',
      contactInfo: json['contact_info'] ?? 'See parish website',
      massTimes: ScheduleEntry.listFromJson(schedules['mass']),
      confTimes: ScheduleEntry.listFromJson(schedules['confession']),
      adoration: adorationEntries,
      adorationIsPerpetual: perpetual,
      eventsSummary: json['events_summary'],
      latitude: _parseCoord(json['latitude']),
      longitude: _parseCoord(json['longitude']),
      imageUrl: json['image_url'],
      bulletinUrl: json['bulletin_url'],
      lastUpdated: _parseTimestamp(json['timestamp']),
    );
  }

  /// Parse timestamp from YYYY-MM-DD format
  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null || value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Parse a nullable numeric coordinate.
  static double? _parseCoord(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
