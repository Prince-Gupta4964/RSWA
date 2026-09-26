class ProjectModel {
  final String id;
  final String projectName;
  final String reraId;
  final String legality;
  final String propertyType; // Flat, Plot, or Bungalow
  final String contactPerson;
  final String contactNumber;
  final Map<String, dynamic> propertyDetails;
  final List<String> builderIds;
  final bool isHot;
  final bool isApproved;
  final bool isDeleted; // 🚀 NAYA
  final String? createdByUid;
  final Map<String, dynamic> rawData;
  final String? coverImage;

  ProjectModel({
    required this.id,
    required this.projectName,
    required this.reraId,
    required this.legality,
    required this.propertyType,
    required this.contactPerson,
    required this.contactNumber,
    required this.propertyDetails,
    this.builderIds = const [],
    this.isHot = false,
    this.isApproved = false,
    this.isDeleted = false, // 🚀 NAYA
    this.createdByUid,
    required this.rawData,
    this.coverImage,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dynamic cb = data['createdBy'];
    final String? cbUid = cb is Map ? cb['uid']?.toString() : (cb is String ? cb : null);
    return ProjectModel(
      id: documentId,
      projectName: data['projectName'] ?? 'Unknown Project',
      reraId: data['reraId'] ?? 'N/A',
      legality: data['legality'] ?? 'N/A',
      propertyType: data['propertyType'] ?? 'Flat',
      contactPerson: data['contactPerson'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      propertyDetails: data['propertyDetails'] is Map ? data['propertyDetails'] : {},
      builderIds: (data['builderIds'] is Iterable) ? List<String>.from(data['builderIds']) : [],
      isHot: data['isHot'] == true,
      isApproved: data['isApproved'] == 'Yes' || data['isApproved'] == true,
      isDeleted: data['isDeleted'] == true, // 🚀 NAYA
      createdByUid: data['createdByUid']?.toString() ?? cbUid,
      rawData: data,
      coverImage: data['coverImage'],
    );
  }
}
