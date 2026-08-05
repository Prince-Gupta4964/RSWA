class BuilderModel {
  final String id;
  final String name;
  final String companyName;
  final String contact;
  final String email;
  final String address;
  final List<String> linkedProjectIds;
  final Map<String, dynamic> rawData;

  BuilderModel({
    required this.id,
    required this.name,
    required this.companyName,
    required this.contact,
    required this.email,
    required this.address,
    this.linkedProjectIds = const [],
    required this.rawData,
  });

  factory BuilderModel.fromMap(Map<String, dynamic> data, String documentId) {
    return BuilderModel(
      id: documentId,
      name: data['name'] ?? 'Unknown Builder',
      companyName: data['companyName'] ?? '',
      contact: data['contact'] ?? '',
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      linkedProjectIds: List<String>.from(data['linkedProjectIds'] ?? []),
      rawData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyName': companyName,
      'contact': contact,
      'email': email,
      'address': address,
      'linkedProjectIds': linkedProjectIds,
    };
  }
}
