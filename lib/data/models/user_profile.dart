class UserProfile {
  final String name;
  final String salesCode;
  final String branch;
  final String tsc;

  const UserProfile({
    required this.name,
    required this.salesCode,
    this.branch = 'XL SATU CILACAP',
    this.tsc = 'TSC PIPIN',
  });

  UserProfile copyWith({
    String? name,
    String? salesCode,
    String? branch,
    String? tsc,
  }) {
    return UserProfile(
      name: name ?? this.name,
      salesCode: salesCode ?? this.salesCode,
      branch: branch ?? this.branch,
      tsc: tsc ?? this.tsc,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': 1,
      'name': name,
      'sales_code': salesCode,
      'branch': branch,
      'tsc': tsc,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      name: (map['name'] as String?) ?? '',
      salesCode: (map['sales_code'] as String?) ?? '',
      branch: (map['branch'] as String?) ?? 'XL SATU CILACAP',
      tsc: (map['tsc'] as String?) ?? 'TSC PIPIN',
    );
  }

  bool get isConfigured => name.trim().isNotEmpty && salesCode.trim().isNotEmpty;
}
