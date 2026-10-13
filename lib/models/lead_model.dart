import '../utils/role_permissions.dart';

class LeadModel {
  final String id;
  final String name;
  final String contact;
  final String status;
  final List<String> favUids; // 🚀 NAYA: To track favorites
  final Map<String, dynamic> rawData; 

  String get fullName {
    final String firstName = name.trim();
    final String surname = (rawData['surname'] ?? '').toString().trim();
    return surname.isNotEmpty && !firstName.toLowerCase().contains(surname.toLowerCase())
        ? '$firstName $surname'
        : firstName;
  }

  bool get isPrivate {
    final v = rawData['isPrivate'];
    return v == true || v == 'Yes' || v == 'true';
  }

  String getDisplayContact(String? currentUserId, String? currentUserName, AppRole userRole) {
    if (!isPrivate) return contact;
    final String leadUserId = (rawData['userId'] ?? '').toString();
    final String leadCreatedBy = (rawData['createdBy'] ?? '').toString();
    final bool isCreator = (currentUserId != null && currentUserId.isNotEmpty && leadUserId == currentUserId) ||
                           (currentUserName != null && currentUserName.isNotEmpty && leadCreatedBy.toLowerCase() == currentUserName.toLowerCase());
    final bool isAdmin = userRole == AppRole.superAdmin || userRole == AppRole.admin;
    if (isCreator || isAdmin) return contact;
    return "••••••••••";
  }

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
      status: (data['status'] ?? 'Cold').toString(),
      favUids: (data['favUids'] is Iterable) ? List<String>.from(data['favUids']) : [],
      rawData: data, // <-- Saare fields automatically yahan aa jayenge
    );
  }
}
