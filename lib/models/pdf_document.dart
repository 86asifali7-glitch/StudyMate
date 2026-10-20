class PdfDocument {
  final String id;
  final String name;
  final String originalFileName;
  final String storedFileName;
  final int fileSizeBytes;
  final DateTime importDate;
  final bool isFavorite;
  final String? localPath;
  final String? webDataKey;

  const PdfDocument({
    required this.id,
    required this.name,
    required this.originalFileName,
    String? storedFileName,
    required this.fileSizeBytes,
    required this.importDate,
    this.isFavorite = false,
    this.localPath,
    this.webDataKey,
  }) : storedFileName = storedFileName ?? '$id.pdf';

  PdfDocument copyWith({
    String? id,
    String? name,
    String? originalFileName,
    String? storedFileName,
    int? fileSizeBytes,
    DateTime? importDate,
    bool? isFavorite,
    String? localPath,
    String? webDataKey,
  }) {
    return PdfDocument(
      id: id ?? this.id,
      name: name ?? this.name,
      originalFileName: originalFileName ?? this.originalFileName,
      storedFileName: storedFileName ?? this.storedFileName,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      importDate: importDate ?? this.importDate,
      isFavorite: isFavorite ?? this.isFavorite,
      localPath: localPath ?? this.localPath,
      webDataKey: webDataKey ?? this.webDataKey,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'originalFileName': originalFileName,
        'storedFileName': storedFileName,
        'fileSizeBytes': fileSizeBytes,
        'importDate': importDate.toIso8601String(),
        'isFavorite': isFavorite,
        'localPath': localPath,
        'webDataKey': webDataKey,
      };

  factory PdfDocument.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    final origName =
        json['originalFileName'] as String? ?? json['name'] as String? ?? 'document.pdf';
    final lPath = json['localPath'] as String?;
    final defaultStored = lPath != null
        ? lPath.split(RegExp(r'[\\/]')).last
        : '$id.pdf';
    return PdfDocument(
      id: id,
      name: json['name'] as String? ?? origName,
      originalFileName: origName,
      storedFileName: json['storedFileName'] as String? ?? defaultStored,
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      importDate: json['importDate'] != null
          ? DateTime.tryParse(json['importDate'] as String) ?? DateTime.now()
          : DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      localPath: lPath,
      webDataKey: json['webDataKey'] as String?,
    );
  }

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${months[importDate.month - 1]} ${importDate.day}, ${importDate.year}';
  }
}
