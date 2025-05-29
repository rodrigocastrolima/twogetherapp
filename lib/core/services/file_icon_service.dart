// FileIconService: Maps file extensions to PNG asset paths for file icons
class FileIconService {
  static String getIconAssetPath(String? extension) {
    final ext = (extension ?? '').toLowerCase();
    switch (ext) {
      case 'pdf':
        return 'icons/file_types/pdf.png';
      case 'doc':
      case 'docx':
        return 'icons/file_types/word.png';
      case 'xls':
      case 'xlsx':
        return 'icons/file_types/excel.png';
      case 'ppt':
      case 'pptx':
        return 'icons/file_types/powerpoint.png';
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
      case 'heic':
        return 'icons/file_types/image.png';
      default:
        return 'icons/file_types/file.png';
    }
  }
} 