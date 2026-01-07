class Parish {
  final String name;
  final String? parishId;
  final String address;
  final String city;
  final String zipCode;
  final String phone;
  final String website;
  final List<String> massTimes;
  final List<String> confTimes;
  final List<String> adoration;
  final String? eventsSummary;
  final String? contactInfo;
  final double? latitude;
  final double? longitude;
  final String? imageUrl;
  final String? bulletinUrl;

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
    this.eventsSummary,
    this.contactInfo,
    this.latitude,
    this.longitude,
    this.imageUrl,
    this.bulletinUrl,
  });

  factory Parish.fromJson(Map<String, dynamic> json) {
    // Handle zipCode as either int or String
    String zipCodeString;
    if (json['zip_code'] != null) {
      zipCodeString = json['zip_code'].toString();
    } else {
      zipCodeString = '';
    }

    return Parish(
      name: json['name'] ?? 'Unknown',
      parishId: json['parish_id'],
      address: json['address'] ?? 'No address provided',
      city: json['city'] ?? 'Unknown city',
      zipCode: zipCodeString,
      phone: json['phone'] ?? 'No Phone Listed',
      // Support both 'website' (new) and 'www' (legacy) keys
      website: json['website'] ?? json['www'] ?? 'No Website',
      contactInfo: json['contact_info'] ?? 'See parish website',
      massTimes: json['mass_times'] != null
          ? List<String>.from(json['mass_times'])
          : [],
      // Support both 'confessions' (new) and 'conf_times' (legacy) keys
      confTimes: json['confessions'] != null
          ? List<String>.from(json['confessions'])
          : (json['conf_times'] != null
              ? List<String>.from(json['conf_times'])
              : []),
      adoration: json['adoration'] != null
          ? List<String>.from(json['adoration'])
          : [],
      eventsSummary: json['events_summary'],
      latitude: _parseLatitude(json),
      longitude: _parseLongitude(json),
      imageUrl: json['image_url'],
      bulletinUrl: json['bulletin_url'],
    );
  }

  /// Parse latitude from either 'latitude' field or 'lonlat' string
  static double? _parseLatitude(Map<String, dynamic> json) {
    if (json['latitude'] != null) {
      return json['latitude'].toDouble();
    }
    // Parse from lonlat format: "longitude,latitude"
    if (json['lonlat'] != null && json['lonlat'] is String) {
      final parts = (json['lonlat'] as String).split(',');
      if (parts.length == 2) {
        return double.tryParse(parts[1].trim());
      }
    }
    return null;
  }

  /// Parse longitude from either 'longitude' field or 'lonlat' string
  static double? _parseLongitude(Map<String, dynamic> json) {
    if (json['longitude'] != null) {
      return json['longitude'].toDouble();
    }
    // Parse from lonlat format: "longitude,latitude"
    if (json['lonlat'] != null && json['lonlat'] is String) {
      final parts = (json['lonlat'] as String).split(',');
      if (parts.length == 2) {
        return double.tryParse(parts[0].trim());
      }
    }
    return null;
  }
}
