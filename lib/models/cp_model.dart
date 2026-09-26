class CPModel {
  final String id;
  final String cpName;
  final String profession;
  final String contactNo;
  final String location;
  final String officeRef;
  final String advisorReachedBy;
  final String callerRef;
  final String status;
  final String reraId;
  final String? parentUid; 
  final String? addedBy;   
  final String referralCode; // 🚀 NAYA
  final bool isApproved;     // 🚀 NAYA
  final bool isProfileComplete; // 🚀 NAYA
  final bool isDeleted; // 🚀 NAYA
  final Map<String, dynamic> rawData;

  String get fullName {
    final String name = cpName.trim();
    final String surname = (rawData['surname'] ?? '').toString().trim();
    return surname.isNotEmpty ? '$name $surname' : name;
  }

  List<String> get companyNames {
    if (rawData['companyNames'] is List) {
      return List<String>.from(rawData['companyNames']);
    }
    final single = (rawData['companyName'] ?? '').toString().trim();
    return single.isNotEmpty ? [single] : [];
  }

  CPModel({
    required this.id,
    required this.cpName,
    required this.profession,
    required this.contactNo,
    required this.location,
    required this.officeRef,
    required this.advisorReachedBy,
    required this.callerRef,
    required this.status,
    required this.reraId,
    this.parentUid,
    this.addedBy,
    required this.referralCode,
    required this.isApproved,
    required this.isProfileComplete,
    this.isDeleted = false, // 🚀 NAYA
    required this.rawData,
  });

  factory CPModel.fromMap(Map<String, dynamic> data, String documentId) {
    return CPModel(
      id: documentId,
      cpName: data['cpName'] ?? 'Unknown CP',
      profession: data['profession'] ?? '',
      contactNo: data['contactNo'] ?? '',
      location: data['location'] ?? '',
      officeRef: data['officeRef'] ?? '',
      advisorReachedBy: data['advisorReachedBy'] ?? '',
      callerRef: data['callerRef'] ?? '',
      status: data['status'] ?? 'Pending',
      reraId: data['reraId'] ?? 'N/A',
      parentUid: data['parentUid'],
      addedBy: data['addedBy'],
      referralCode: data['referralCode'] ?? '',
      isApproved: data['isApproved'] == true || data['isApproved'] == 1,
      isProfileComplete: data['isProfileComplete'] == true || data['isProfileComplete'] == 1,
      isDeleted: data['isDeleted'] == true, // 🚀 NAYA
      rawData: data,
    );
  }
}
