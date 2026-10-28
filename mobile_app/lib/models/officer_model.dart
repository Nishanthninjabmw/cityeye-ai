class Officer {
  final String officerId;
  final String name;
  final String department;
  final String dob;
  final int age;
  final String phone;
  final String? govIdProof;
  final String? token;

  Officer({
    required this.officerId,
    required this.name,
    required this.department,
    required this.dob,
    required this.age,
    required this.phone,
    this.govIdProof,
    this.token,
  });

  factory Officer.fromJson(Map<String, dynamic> json) {
    return Officer(
      officerId: json['officer_id'] ?? json['officerId'] ?? 'OFFICER-701',
      name: json['name'] ?? 'Officer',
      department: json['department'] ?? 'Smoke Detection',
      dob: json['dob'] ?? '1995-05-15',
      age: json['age'] is int ? json['age'] : (int.tryParse('${json['age']}') ?? 29),
      phone: json['phone'] ?? '+91 9876543210',
      govIdProof: json['gov_id_proof'] ?? json['govIdProof'],
      token: json['token'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'officer_id': officerId,
      'name': name,
      'department': department,
      'dob': dob,
      'age': age,
      'phone': phone,
      'gov_id_proof': govIdProof,
      'token': token,
    };
  }

  static Officer demoOfficer() {
    return Officer(
      officerId: 'OFFICER-701',
      name: 'Inspector Sharma',
      department: 'Smoke Detection',
      dob: '1995-05-15',
      age: 29,
      phone: '+91 9876543210',
      govIdProof: 'badge_id_proof.pdf',
      token: 'demo_token_701',
    );
  }
}
