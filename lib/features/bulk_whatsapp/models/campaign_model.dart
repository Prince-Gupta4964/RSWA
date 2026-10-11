class CampaignModel {
  final String id;
  final String name;
  final String status; // 'Running', 'Completed', 'Paused', 'Failed'
  final int total;
  final int sent;
  final int pending;
  final int failed;
  final String createdByUid;
  final String createdByName;
  final DateTime createdAt;
  final Map<String, dynamic> rawData;

  double get progress {
    if (total == 0) return 0.0;
    return (sent + failed) / total;
  }

  CampaignModel({
    required this.id,
    required this.name,
    required this.status,
    required this.total,
    required this.sent,
    required this.pending,
    required this.failed,
    required this.createdByUid,
    required this.createdByName,
    required this.createdAt,
    this.rawData = const {},
  });

  factory CampaignModel.fromMap(Map<String, dynamic> data, String id) {
    return CampaignModel(
      id: id,
      name: data['name'] ?? 'Unnamed Campaign',
      status: data['status'] ?? 'Pending',
      total: data['total'] ?? 0,
      sent: data['sent'] ?? 0,
      pending: data['pending'] ?? 0,
      failed: data['failed'] ?? 0,
      createdByUid: data['createdByUid'] ?? '',
      createdByName: data['createdByName'] ?? 'User',
      createdAt: data['createdAt'] != null ? data['createdAt'].toDate() : DateTime.now(),
      rawData: data,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'status': status,
      'total': total,
      'sent': sent,
      'pending': pending,
      'failed': failed,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': createdAt,
    };
  }
}
