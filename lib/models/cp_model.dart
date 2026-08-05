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
  final String? parentUid; // <-- NAYA: Kisne add kiya uski ID
  final String? addedBy;   // <-- NAYA: Kisne add kiya uska Naam
  final Map<String, dynamic> rawData;

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
      rawData: data,
    );
  }
}