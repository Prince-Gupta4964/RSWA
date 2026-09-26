class BuilderModel {
  final String id;
  final String name;
  final List<String> companyNames;
  final String contact;
  final String email;
  final String address;
  final List<String> linkedProjectIds;
  final String sourceCollection; // 🚀 NAYA: 'builders' or 'cps'
  final Map<String, dynamic> rawData;

  String get companyName => companyNames.isNotEmpty ? companyNames.first : '';

  BuilderModel({
    required this.id,
    required this.name,
    required this.companyNames,
    required this.contact,
    required this.email,
    required this.address,
    this.linkedProjectIds = const [],
    this.sourceCollection = 'builders',
    required this.rawData,
  });

  factory BuilderModel.fromMap(Map<String, dynamic> data, String documentId, {String collection = 'builders'}) {
    List<String> loadedCompanies = [];
    if (data['companyNames'] is List) {
      loadedCompanies = List<String>.from(data['companyNames']);
    } else if (data['companyName'] != null && data['companyName'].toString().isNotEmpty) {
      loadedCompanies = [data['companyName'].toString().trim()];
    }

    return BuilderModel(
      id: documentId,
      name: collection == 'cps' ? (data['cpName'] ?? data['name'] ?? 'Unknown Builder') : (data['name'] ?? 'Unknown Builder'),
      companyNames: loadedCompanies,
      contact: collection == 'cps' ? (data['contactNo'] ?? '') : (data['contact'] ?? ''),
      email: data['email'] ?? '',
      address: data['address'] ?? '',
      linkedProjectIds: List<String>.from(data['linkedProjectIds'] ?? []),
      sourceCollection: collection,
      rawData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'companyNames': companyNames,
      'companyName': companyName,
      'contact': contact,
      'email': email,
      'address': address,
      'linkedProjectIds': linkedProjectIds,
    };
  }
}
