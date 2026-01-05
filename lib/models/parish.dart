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
      latitude: json['latitude'] != null
          ? json['latitude'].toDouble()
          : null,
      longitude: json['longitude'] != null
          ? json['longitude'].toDouble()
          : null,
      imageUrl: json['image_url'],
    );
  }
}
