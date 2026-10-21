enum VaultCategory {
  image,
  video,
  audio,
  pdfNotes,
}

extension VaultCategoryExtension on VaultCategory {
  String get displayName {
    switch (this) {
      case VaultCategory.image:
        return 'Images';
      case VaultCategory.video:
        return 'Videos';
      case VaultCategory.audio:
        return 'Audio & Music';
      case VaultCategory.pdfNotes:
        return 'PDFs & Notes';
    }
  }

  String get idString {
    switch (this) {
      case VaultCategory.image:
        return 'image';
      case VaultCategory.video:
        return 'video';
      case VaultCategory.audio:
        return 'audio';
      case VaultCategory.pdfNotes:
        return 'pdfNotes';
    }
  }

  static VaultCategory fromString(String val) {
    switch (val.toLowerCase()) {
      case 'image':
        return VaultCategory.image;
      case 'video':
        return VaultCategory.video;
      case 'audio':
      case 'music':
        return VaultCategory.audio;
      case 'pdfnotes':
      case 'pdf':
      case 'notes':
        return VaultCategory.pdfNotes;
      default:
        return VaultCategory.image;
    }
  }
}

class VaultItem {
  final String id;
  final String name;
  final VaultCategory category;
  final String originalFileName;
  final String storedFileName;
  final int fileSizeBytes;
  final DateTime importDate;
  final bool isFavorite;
  final String? localPath;
  final String? webDataKey;
  final bool isNote;
  final String? noteSnippet;

  const VaultItem({
    required this.id,
    required this.name,
    required this.category,
    required this.originalFileName,
    required this.storedFileName,
    required this.fileSizeBytes,
    required this.importDate,
    this.isFavorite = false,
    this.localPath,
    this.webDataKey,
    this.isNote = false,
    this.noteSnippet,
  });

  String get formattedSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  String get formattedDate {
    final y = importDate.year;
    final m = importDate.month.toString().padLeft(2, '0');
    final d = importDate.day.toString().padLeft(2, '0');
    final h = importDate.hour.toString().padLeft(2, '0');
    final min = importDate.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }

  VaultItem copyWith({
    String? name,
    bool? isFavorite,
    String? localPath,
    String? webDataKey,
    String? noteSnippet,
  }) {
    return VaultItem(
      id: id,
      name: name ?? this.name,
      category: category,
      originalFileName: originalFileName,
      storedFileName: storedFileName,
      fileSizeBytes: fileSizeBytes,
      importDate: importDate,
      isFavorite: isFavorite ?? this.isFavorite,
      localPath: localPath ?? this.localPath,
      webDataKey: webDataKey ?? this.webDataKey,
      isNote: isNote,
      noteSnippet: noteSnippet ?? this.noteSnippet,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category.idString,
      'originalFileName': originalFileName,
      'storedFileName': storedFileName,
      'fileSizeBytes': fileSizeBytes,
      'importDate': importDate.toIso8601String(),
      'isFavorite': isFavorite,
      'localPath': localPath,
      'webDataKey': webDataKey,
      'isNote': isNote,
      'noteSnippet': noteSnippet,
    };
  }

  factory VaultItem.fromJson(Map<String, dynamic> json) {
    return VaultItem(
      id: json['id'] as String,
      name: json['name'] as String,
      category: VaultCategoryExtension.fromString(json['category'] as String? ?? 'image'),
      originalFileName: json['originalFileName'] as String? ?? 'file.bin',
      storedFileName: json['storedFileName'] as String? ?? '${json['id']}.enc',
      fileSizeBytes: (json['fileSizeBytes'] as num?)?.toInt() ?? 0,
      importDate: DateTime.tryParse(json['importDate'] as String? ?? '') ?? DateTime.now(),
      isFavorite: json['isFavorite'] as bool? ?? false,
      localPath: json['localPath'] as String?,
      webDataKey: json['webDataKey'] as String?,
      isNote: json['isNote'] as bool? ?? false,
      noteSnippet: json['noteSnippet'] as String?,
    );
  }

  @override
  String toString() => 'VaultItem(id: $id, name: $name, category: $category)';
}
