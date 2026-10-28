class CameraModel {
  final String cameraId;
  final String name;
  final String location;
  final String status; // 'ONLINE' or 'DISCONNECTED'
  final String feedUrl;
  final String? lastUpdated;

  CameraModel({
    required this.cameraId,
    required this.name,
    required this.location,
    required this.status,
    required this.feedUrl,
    this.lastUpdated,
  });

  bool get isOnline => status.toUpperCase() == 'ONLINE';

  factory CameraModel.fromJson(Map<String, dynamic> json) {
    return CameraModel(
      cameraId: json['camera_id'] ?? json['cameraId'] ?? 'CAM-01',
      name: json['name'] ?? 'Surveillance Camera',
      location: json['location'] ?? 'Municipal Sector',
      status: (json['status'] ?? 'DISCONNECTED').toString().toUpperCase(),
      feedUrl: json['feed_url'] ?? json['feedUrl'] ?? '/video_feed',
      lastUpdated: json['last_updated'] ?? json['created_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'camera_id': cameraId,
      'name': name,
      'location': location,
      'status': status,
      'feed_url': feedUrl,
      'last_updated': lastUpdated,
    };
  }

  static List<CameraModel> defaultCameras() {
    return [
      CameraModel(
        cameraId: 'CAM-01',
        name: 'Laptop Webcam',
        location: 'Sector 4 - Control Room Node',
        status: 'ONLINE',
        feedUrl: '/video_feed',
        lastUpdated: 'Live Active',
      ),
      CameraModel(
        cameraId: 'CAM-SEC1-01',
        name: 'Municipal Gateway 01',
        location: 'Sector 1 - North Ring Road',
        status: 'DISCONNECTED',
        feedUrl: '',
        lastUpdated: 'Awaiting handshake',
      ),
    ];
  }
}
