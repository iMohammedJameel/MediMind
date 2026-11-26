/// User profile — covers both patient and caregiver shapes.
class ProfileModel {
  final String firstName;
  final String lastName;
  final String? phone;
  final String? bloodType; // patient only
  final String? emergencyName; // patient only
  final String? emergencyPhone; // patient only

  const ProfileModel({
    required this.firstName,
    required this.lastName,
    this.phone,
    this.bloodType,
    this.emergencyName,
    this.emergencyPhone,
  });

  String get fullName => '$firstName $lastName'.trim();

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Response may be the profile itself or wrapped in {profile: {...}}.
    final data = json['profile'] is Map ? json['profile'] as Map<String, dynamic> : json;
    final emergency = data['emergencyContact'];
    final emergencyMap =
        emergency is List && emergency.isNotEmpty && emergency.first is Map
            ? emergency.first as Map<String, dynamic>
            : (emergency is Map ? emergency as Map<String, dynamic> : null);

    return ProfileModel(
      firstName: (data['firstName'] ?? '').toString(),
      lastName: (data['lastName'] ?? '').toString(),
      phone: data['phone']?.toString(),
      bloodType: data['bloodType']?.toString(),
      emergencyName: emergencyMap?['name']?.toString(),
      emergencyPhone: emergencyMap?['phone']?.toString(),
    );
  }

  ProfileModel copyWith({
    String? firstName,
    String? lastName,
    String? phone,
    String? bloodType,
    String? emergencyName,
    String? emergencyPhone,
  }) =>
      ProfileModel(
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone,
        bloodType: bloodType ?? this.bloodType,
        emergencyName: emergencyName ?? this.emergencyName,
        emergencyPhone: emergencyPhone ?? this.emergencyPhone,
      );
}
