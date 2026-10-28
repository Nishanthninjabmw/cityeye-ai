class DetectionStatusModel {
  final String status; // 'NORMAL' or 'ALERT'
  final String detectionType; // 'None', 'Smoke', 'Fire', 'Accident'
  final double confidence;
  final String message;
  final String timestamp;
  final String cameraId;
  final int? incidentId;

  DetectionStatusModel({
    required this.status,
    required this.detectionType,
    required this.confidence,
    required this.message,
    required this.timestamp,
    required this.cameraId,
    this.incidentId,
  });

  bool get isAlert => status.toUpperCase() == 'ALERT';

  factory DetectionStatusModel.fromJson(Map<String, dynamic> json, {String defaultType = 'None'}) {
    return DetectionStatusModel(
      status: (json['status'] ?? 'NORMAL').toString().toUpperCase(),
      detectionType: json['detection_type'] ?? json['type'] ?? defaultType,
      confidence: (json['confidence'] is num) ? (json['confidence'] as num).toDouble() : 0.0,
      message: json['message'] ?? 'No visual hazards detected in this frame.',
      timestamp: json['timestamp'] ?? DateTime.now().toString(),
      cameraId: json['camera_id'] ?? json['cameraId'] ?? 'CAM-01',
      incidentId: json['incident_id'] ?? json['incidentId'],
    );
  }

  factory DetectionStatusModel.smokeNormal() {
    final now = DateTime.now();
    final timeStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    return DetectionStatusModel(
      status: 'NORMAL',
      detectionType: 'None',
      confidence: 0.0,
      message: 'No fire or smoke detected in this frame.',
      timestamp: timeStr,
      cameraId: 'CAM-01',
    );
  }

  factory DetectionStatusModel.accidentNormal() {
    final now = DateTime.now();
    final timeStr = "${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
    return DetectionStatusModel(
      status: 'NORMAL',
      detectionType: 'None',
      confidence: 0.0,
      message: 'No road collision or vehicle hazard detected in this frame.',
      timestamp: timeStr,
      cameraId: 'CAM-01',
    );
  }

  factory DetectionStatusModel.normal() => DetectionStatusModel.smokeNormal();
}
