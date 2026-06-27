class ProjectModel {
  final String id;
  final String projectName;
  final String reraId;
  final String legality;
  final String propertyType; // Flat, Plot, or Bungalow
  final String contactPerson;
  final String contactNumber;
  final Map<String, dynamic> propertyDetails; // Isme dynamic fields aayenge
  final Map<String, dynamic> rawData;

  ProjectModel({
    required this.id,
    required this.projectName,
    required this.reraId,
    required this.legality,
    required this.propertyType,
    required this.contactPerson,
    required this.contactNumber,
    required this.propertyDetails,
    required this.rawData,
  });

  factory ProjectModel.fromMap(Map<String, dynamic> data, String documentId) {
    return ProjectModel(
      id: documentId,
      projectName: data['projectName'] ?? 'Unknown Project',
      reraId: data['reraId'] ?? 'N/A',
      legality: data['legality'] ?? 'N/A',
      propertyType: data['propertyType'] ?? 'Flat',
      contactPerson: data['contactPerson'] ?? '',
      contactNumber: data['contactNumber'] ?? '',
      propertyDetails: data['propertyDetails'] ?? {},
      rawData: data,
    );
  }
}