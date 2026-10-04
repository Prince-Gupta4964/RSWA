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
  final double avgRating;
  final int ratingCount;

  String get displayLocation {
    final details = propertyDetails;
    final loc = (details['nearestStation'] ?? rawData['nearestStation'] ??
                 details['areaName'] ?? details['location'] ?? details['googleLocation'] ?? details['address'] ?? details['city'] ?? details['microMarket'] ?? details['subLocation'] ?? details['place'] ?? details['locality'] ??
                 rawData['areaName'] ?? rawData['location'] ?? rawData['googleLocation'] ?? rawData['address'] ?? rawData['city'] ?? rawData['microMarket'] ?? rawData['subLocation'] ?? rawData['place'] ?? rawData['locality'] ?? '')
                .toString().trim();
    return loc.isNotEmpty && loc != 'null' ? loc : 'Location N/A';
  }

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
    this.avgRating = 0.0,
    this.ratingCount = 0,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> data, String documentId) {
    final dynamic cb = data['createdBy'];
    final String? cbUid = cb is Map ? cb['uid']?.toString() : (cb is String ? cb : null);

    final pd = data['propertyDetails'] is Map ? Map<String, dynamic>.from(data['propertyDetails'] as Map) : <String, dynamic>{};
    
    final bool rawApproved = data['isApproved'] == 'Yes' || 
        data['isApproved'] == true || 
        data['isApproved'] == 'Approved' ||
        data['approvalStatus'] == 'Approved' ||
        data['approvalStatus'] == 'Yes';

    final bool pdApproved = pd['isApproved'] == 'Yes' || 
        pd['isApproved'] == true || 
        pd['isApproved'] == 'Approved' ||
        pd['approvalStatus'] == 'Approved' ||
        pd['approvalStatus'] == 'Yes';

    final bool isApprovedFinal = rawApproved || pdApproved;

    final double avg = double.tryParse(data['avgRating']?.toString() ?? '') ?? double.tryParse(pd['avgRating']?.toString() ?? '') ?? 0.0;
    final int count = int.tryParse(data['ratingCount']?.toString() ?? '') ?? int.tryParse(pd['ratingCount']?.toString() ?? '') ?? 0;

    return ProjectModel(
      id: documentId,
      projectName: data['projectName'] ?? 'Unknown Project',
      reraId: data['reraId'] ?? 'N/A',
      legality: data['legality'] ?? 'N/A',
      propertyType: data['propertyType'] ?? 'Flat',
      contactPerson: data['contactPerson'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      propertyDetails: pd,
      builderIds: (data['builderIds'] is Iterable) ? List<String>.from(data['builderIds']) : [],
      isHot: data['isHot'] == true,
      isApproved: isApprovedFinal,
      isDeleted: data['isDeleted'] == true,
      createdByUid: data['createdByUid']?.toString() ?? cbUid,
      rawData: data,
      coverImage: (data['coverImage'] ?? pd['coverImage'])?.toString(),
      avgRating: avg,
      ratingCount: count,
    );
  }
}
