class FileUpload {
  const FileUpload({required this.uploadId, required this.expiresAt, required this.partSize, required this.maxParts, required this.totalBytes});
  final String uploadId;
  final DateTime expiresAt;
  final int partSize;
  final int maxParts;
  final int totalBytes;
  int get partCount => (totalBytes + partSize - 1) ~/ partSize;
  int expectedPartSize(int partNumber) {
    final start = (partNumber - 1) * partSize;
    final remaining = totalBytes - start;
    return remaining > partSize ? partSize : remaining;
  }
  factory FileUpload.fromJson(Map<String, dynamic> json) => FileUpload(
    uploadId: json['uploadId'] as String,
    expiresAt: DateTime.parse(json['expiresAt'] as String),
    partSize: (json['partSize'] as num).toInt(),
    maxParts: (json['maxParts'] as num).toInt(),
    totalBytes: int.parse(json['totalBytes'] as String),
  );
}
