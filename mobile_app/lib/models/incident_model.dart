class IncidentModel {
  final int id;
  final String incidentId;
  final String type; // 'Smoke', 'Fire', 'Accident', etc.
  final String severity; // 'Low', 'Medium', 'High', 'Critical'
  String status; // 'Open', 'Investigating', 'Resolved'
  final String cameraId;
  final String cameraName;
  final double confidence;
  final String description;
  final String timestamp;
  final String? resolvedAt;

  IncidentModel({
    required this.id,
    required this.incidentId,
    required this.type,
    required this.severity,
    required this.status,
    required this.cameraId,
    required this.cameraName,
    required this.confidence,
    required this.description,
    required this.timestamp,
    this.resolvedAt,
  });

  factory IncidentModel.fromJson(Map<String, dynamic> json) {
    return IncidentModel(
      id: json['id'] is int ? json['id'] : (int.tryParse('${json['id']}') ?? 1),
      incidentId: json['incident_id'] ?? json['incidentId'] ?? 'INC-001',
      type: json['type'] ?? 'Smoke',
      severity: json['severity'] ?? 'High',
      status: json['status'] ?? 'Open',
      cameraId: json['camera_id'] ?? json['cameraId'] ?? 'CAM-01',
      cameraName: json['camera_name'] ?? json['cameraName'] ?? 'Laptop Webcam',
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 92.0,
      description: json['description'] ?? 'Automated visual detection alert',
      timestamp: json['timestamp'] ?? DateTime.now().toIso8601String(),
      resolvedAt: json['resolved_at'] ?? json['resolvedAt'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'incident_id': incidentId,
      'type': type,
      'severity': severity,
      'status': status,
      'camera_id': cameraId,
      'camera_name': cameraName,
      'confidence': confidence,
      'description': description,
      'timestamp': timestamp,
      'resolved_at': resolvedAt,
    };
  }

  static List<IncidentModel> defaultIncidents() {
    return [
      IncidentModel(
        id: 1,
        incidentId: 'INC-2026-081',
        type: 'Smoke',
        severity: 'Critical',
        status: 'Open',
        cameraId: 'CAM-01',
        cameraName: 'Laptop Webcam',
        confidence: 94.8,
        description: 'Persistent dense grey plume detected in quadrant B',
        timestamp: 'Today, 09:42 AM',
      ),
      IncidentModel(
        id: 2,
        incidentId: 'INC-2026-079',
        type: 'Accident',
        severity: 'High',
        status: 'Investigating',
        cameraId: 'CAM-01',
        cameraName: 'Laptop Webcam',
        confidence: 88.5,
        description: 'Two-vehicle collision near pedestrian crossway',
        timestamp: 'Today, 08:15 AM',
      ),
      IncidentModel(
        id: 3,
        incidentId: 'INC-2026-075',
        type: 'Fire',
        severity: 'Critical',
        status: 'Resolved',
        cameraId: 'CAM-SEC1-01',
        cameraName: 'Municipal Gateway 01',
        confidence: 96.1,
        description: 'Combustion signature detected along roadside waste bin',
        timestamp: 'Yesterday, 04:30 PM',
        resolvedAt: 'Yesterday, 05:12 PM',
      ),
    ];
  }
}
