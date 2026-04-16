import {injectable, BindingScope} from '@loopback/core';
import {Request} from '@loopback/rest';
import {writeFile, unlink, mkdir} from 'fs/promises';
import {join, extname} from 'path';
import {createReadStream} from 'fs';
import {randomUUID} from 'crypto';
import Busboy from 'busboy';
import sharp from 'sharp';

export interface UploadResult {
  projectId: string;
  type: string;
  fileName: string;
  storagePath: string;
  url: string;
  fileSize: number;
  mimeType: string;
  width?: number;
  height?: number;
  tags?: string[];
  metadata?: any;
}

@injectable({scope: BindingScope.TRANSIENT})
export class AssetStorageService {
  private storageDir: string;
  private baseUrl: string;
  private maxFileSize: number;
  private allowedTypes: string[];

  constructor() {
    this.storageDir = process.env.ASSET_STORAGE_DIR || '/tmp/water-muse-assets';
    this.baseUrl = process.env.BASE_URL || 'http://localhost:3000';
    this.maxFileSize = parseInt(process.env.MAX_FILE_SIZE || '10485760'); // 10MB default
    this.allowedTypes = [
      'image/jpeg',
      'image/jpg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/svg+xml',
      'font/ttf',
      'font/otf',
      'font/woff',
      'font/woff2',
      'application/font-woff',
      'application/font-woff2',
    ];
  }

  async handleUpload(req: Request): Promise<UploadResult> {
    return new Promise((resolve, reject) => {
      const busboy = Busboy({headers: req.headers as any});
      let uploadResult: Partial<UploadResult> = {};
      let fileBuffer: Buffer;
      let fileName: string;
      let mimeType: string;

      busboy.on('field', (fieldname, value) => {
        if (fieldname === 'projectId') uploadResult.projectId = value;
        if (fieldname === 'type') uploadResult.type = value;
        if (fieldname === 'tags') uploadResult.tags = JSON.parse(value);
      });

      busboy.on('file', async (fieldname, file, info) => {
        const {filename, encoding, mimeType: mime} = info;
        fileName = filename;
        mimeType = mime;

        if (!this.allowedTypes.includes(mime)) {
          reject(new Error(`File type not allowed: ${mime}`));
          return;
        }

        const chunks: Buffer[] = [];
        let totalSize = 0;

        file.on('data', (chunk: Buffer) => {
          totalSize += chunk.length;
          if (totalSize > this.maxFileSize) {
            file.resume(); // Drain the stream
            reject(new Error(`File size exceeds maximum: ${this.maxFileSize} bytes`));
            return;
          }
          chunks.push(chunk);
        });

        file.on('end', async () => {
          fileBuffer = Buffer.concat(chunks);

          try {
            // Generate unique filename
            const ext = extname(fileName);
            const uniqueName = `${randomUUID()}${ext}`;
            const storagePath = join(this.storageDir, uniqueName);

            // Ensure storage directory exists
            await mkdir(this.storageDir, {recursive: true});

            // Extract metadata for images
            if (mime.startsWith('image/')) {
              const metadata = await this.extractImageMetadata(fileBuffer);
              uploadResult.width = metadata.width;
              uploadResult.height = metadata.height;
              uploadResult.metadata = metadata;

              // Generate thumbnail if image
              await this.generateThumbnail(fileBuffer, storagePath);
            }

            // Save file
            await writeFile(storagePath, fileBuffer);

            uploadResult.fileName = fileName;
            uploadResult.storagePath = storagePath;
            uploadResult.url = `${this.baseUrl}/assets/${uniqueName}`;
            uploadResult.fileSize = fileBuffer.length;
            uploadResult.mimeType = mimeType;
          } catch (error) {
            reject(error);
          }
        });
      });

      busboy.on('finish', () => {
        if (!uploadResult.projectId) {
          reject(new Error('projectId is required'));
          return;
        }
        resolve(uploadResult as UploadResult);
      });

      busboy.on('error', reject);

      req.pipe(busboy);
    });
  }

  private async extractImageMetadata(buffer: Buffer): Promise<any> {
    try {
      const image = sharp(buffer);
      const metadata = await image.metadata();

      return {
        width: metadata.width,
        height: metadata.height,
        format: metadata.format,
        space: metadata.space,
        channels: metadata.channels,
        depth: metadata.depth,
        density: metadata.density,
        hasAlpha: metadata.hasAlpha,
        orientation: metadata.orientation,
      };
    } catch (error) {
      console.error('Error extracting image metadata:', error);
      return {};
    }
  }

  private async generateThumbnail(buffer: Buffer, originalPath: string): Promise<void> {
    try {
      const thumbnailPath = originalPath.replace(/(\.\w+)$/, '_thumb$1');

      await sharp(buffer)
        .resize(200, 200, {
          fit: 'inside',
          withoutEnlargement: true,
        })
        .toFile(thumbnailPath);
    } catch (error) {
      console.error('Error generating thumbnail:', error);
    }
  }

  async deleteFile(storagePath: string): Promise<void> {
    try {
      await unlink(storagePath);

      // Delete thumbnail if exists
      const thumbnailPath = storagePath.replace(/(\.\w+)$/, '_thumb$1');
      try {
        await unlink(thumbnailPath);
      } catch (error) {
        // Thumbnail might not exist, ignore error
      }
    } catch (error) {
      console.error('Error deleting file:', error);
      throw error;
    }
  }

  async getFileStream(storagePath: string): Promise<NodeJS.ReadableStream> {
    return createReadStream(storagePath);
  }

  async getFile(storagePath: string): Promise<Buffer> {
    const {readFile} = await import('fs/promises');
    return readFile(storagePath);
  }
}
