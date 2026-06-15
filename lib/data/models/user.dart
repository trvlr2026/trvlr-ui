class User {
  const User({
    required this.id,
    required this.displayName,
    required this.email,
    required this.homeDistrict,
    required this.homeState,
  });

  final String id;
  final String displayName;
  final String email;
  final String homeDistrict;
  final String homeState;

  Map<String, dynamic> toJson() => {
        'id': id,
        'displayName': displayName,
        'email': email,
        'homeDistrict': homeDistrict,
        'homeState': homeState,
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        displayName: json['displayName'] as String,
        email: json['email'] as String,
        homeDistrict: json['homeDistrict'] as String,
        homeState: json['homeState'] as String,
      );
}
