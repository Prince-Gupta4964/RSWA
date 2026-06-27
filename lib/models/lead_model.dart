class LeadModel {
  final String id;
  final String name;
  final String contact;
  final String status;
  final Map<String, dynamic> rawData; // <-- NAYA FIELD: Pura Firebase data pakadne ke liye

  LeadModel({
    required this.id,
    required this.name,
    required this.contact,
    required this.status,
    required this.rawData,
  });

  // Firebase se data read karne ke liye
  factory LeadModel.fromMap(Map<String, dynamic> data, String documentId) {
    return LeadModel(
      id: documentId,
      name: data['name'] ?? 'Unknown',
      // Ab whatsapp ya contact2 me se koi ek yahan dikhega
      contact: data['whatsapp'] ?? data['contact2'] ?? 'No Contact',
      status: data['status'] ?? 'Cold',
      rawData: data, // <-- Saare 30 fields automatically yahan aa jayenge
    );
  }
}