import multer from 'multer';

/**
 * Configure multer for file upload handling
 */
export class FileParser {
  private static storage = multer.memoryStorage();

  static getMiddleware() {
    return multer({
      storage: this.storage,
      limits: {
        fileSize: 100 * 1024 * 1024, // 100MB
        files: 1, // Only accept one file at a time
      },
      fileFilter: (req, file, cb) => {
        // Accept only specific file types
        const allowedMimeTypes = [
          'image/jpeg',
          'image/png',
          'image/gif',
          'image/webp',
          'image/bmp',
          'image/tiff',
        ];

        if (allowedMimeTypes.includes(file.mimetype)) {
          cb(null, true);
        } else {
          cb(new Error(`File type ${file.mimetype} is not supported`));
        }
      },
    }).single('file');
  }
}
