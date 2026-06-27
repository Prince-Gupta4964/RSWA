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
  final String reraId; // <-- NAYA: RERA ID add kiya
  final Map<String, dynamic> rawData; // <-- NAYA: Leads track karne ke liye zaroori hai

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
      reraId: data['reraId'] ?? 'N/A', // <-- NAYA: Default value 'N/A' set ki hai
      rawData: data,
    );
  }
}