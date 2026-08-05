class LeadModel {
  final String id;
  final String name;
  final String contact;
  final String status;
  final List<String> favUids; // 🚀 NAYA: To track favorites
  final Map<String, dynamic> rawData; 

  LeadModel({
    required this.id,
    required this.name,
    required this.contact,
    required this.status,
    required this.favUids,
    required this.rawData,
  });

  // Firebase se data read karne ke liye
  factory LeadModel.fromMap(Map<String, dynamic> data, String documentId) {
    return LeadModel(
      id: documentId,
      name: data['name'] ?? data['fullName'] ?? 'Unknown',
      // Ab whatsapp ya contact2 me se koi ek yahan dikhega
      contact: data['whatsapp'] ?? data['contact1'] ?? data['contact2'] ?? 'No Contact',
      status: data['status'] ?? 'Cold',
      favUids: List<String>.from(data['favUids'] ?? []),
      rawData: data, // <-- Saare fields automatically yahan aa jayenge
    );
  }
}
