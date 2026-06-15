class Place {
  const Place({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.state,
    required this.country,
    required this.pointsValue,
    required this.radiusM,
    this.category = 'landmark',
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String district;
  final String state;
  final String country;
  final int pointsValue;
  final int radiusM;
  final String category;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
        'district': district,
        'state': state,
        'country': country,
        'pointsValue': pointsValue,
        'radiusM': radiusM,
        'category': category,
      };

  factory Place.fromJson(Map<String, dynamic> json) => Place(
        id: json['id'] as String,
        name: json['name'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        district: json['district'] as String,
        state: json['state'] as String,
        country: json['country'] as String,
        pointsValue: json['pointsValue'] as int,
        radiusM: json['radiusM'] as int,
        category: json['category'] as String? ?? 'landmark',
      );
}
