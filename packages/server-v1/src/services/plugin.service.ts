import { inject, Provider } from '@loopback/core';
import axios from 'axios';
import FormData from 'form-data';
import { PluginResult, CallbackPayload } from '../models/response/plugin-res';
import { Pool } from 'pg';
import {
  calculateTilePlacements,
  calculateSinglePlacement,
  calculateElementSize,
} from '@dam-plugin/shared';

// Database pool for spec queries
let dbPool: Pool | null = null;

function getDbPool(): Pool {
  if (!dbPool) {
    const dbConfig = {
      host: process.env.DB_HOST || 'localhost',
      port: parseInt(process.env.DB_PORT || '5432'),
      database: process.env.DB_DATABASE || 'dam_demo',
      user: process.env.DB_USER || 'postgres',
      password: process.env.DB_PASSWORD || 'postgres',
    };
    console.log('🗄️  [PLUGIN SERVICE] Creating database pool with config:', {
      host: dbConfig.host,
      port: dbConfig.port,
      database: dbConfig.database,
      user: dbConfig.user,
    });
    dbPool = new Pool(dbConfig);
  }
  return dbPool;
}

// Types matching the UI spec format
interface WatermarkLayer {
  id: string;
  name: string;
  type: 'text' | 'image';
  enabled: boolean;
  mode: 'tile' | 'single';
  size: {
    basis: string;
    percent: number;
    clampMinPx: number;
    clampMaxPx: number;
  };
  appearance: {
    opacity: number;
    color?: string;
    stroke?: {
      enabled: boolean;
      width: number;
      color: string;
    };
    blendMode: string;
  };
  text?: {
    content: string;
    transform: string;
  };
  single?: {
    anchor: string;
    positionNorm: { x: number; y: number };
    marginNorm: number;
    rotationDeg: number;
    keepInside: boolean;
  };
  tile?: {
    angleDeg: number;
    stepNorm: number;
    offsetNorm: { x: number; y: number };
    staggerRows: boolean;
  };
  image?: {
    resourceId: string;
  };
}

interface WatermarkSpec {
  schemaVersion: number;
  specId: string;
  specVersion: string;
  name: string;
  status: string;
  layers: WatermarkLayer[];
  resources: {
    font?: any;
    images: any[];
  };
}

/**
 * Main plugin service - implement your custom processing logic here
 */
export class PluginService implements Provider<PluginService> {
  constructor(
    @inject('config.apiKey', { optional: true })
    private apiKey?: string,
    @inject('config.externalApiUrl', { optional: true })
    private externalApiUrl?: string,
  ) {
    this.apiKey = apiKey || process.env.API_KEY || 'default-api-key';
    this.externalApiUrl = externalApiUrl || process.env.EXTERNAL_API_URL || '';
  }

  value(): PluginService {
    return this;
  }

  /**
   * Fetch active watermark spec from database
   * Queries the projects table for specs with status='published' (active)
   */
  private async getActiveWatermarkSpec(): Promise<WatermarkSpec | null> {
    console.log('🔍 [PLUGIN SERVICE] Querying database for active watermark spec...');
    try {
      const pool = getDbPool();
      
      // Query projects table for the active (published) watermark spec
      // The spec data is stored in the 'metadata' column as JSONB
      const query = `
        SELECT id, name, status, metadata 
        FROM projects 
        WHERE status = 'published'
        ORDER BY updatedat DESC
        LIMIT 1
      `;
      
      console.log('📝 [PLUGIN SERVICE] Executing query:', query.trim());
      const result = await pool.query(query);
      
      if (result.rows.length > 0) {
        const row = result.rows[0];
        const metadata = row.metadata as WatermarkSpec;
        console.log('✅ [PLUGIN SERVICE] Found active spec:', {
          id: row.id,
          name: row.name,
          status: row.status,
          specName: metadata?.name,
          layerCount: metadata?.layers?.length || 0,
          layers: metadata?.layers?.map((l: any) => ({ name: l.name, type: l.type, mode: l.mode })),
        });
        return metadata;
      }
      
      console.log('⚠️  [PLUGIN SERVICE] No active (published) watermark spec found in database');
      return null;
    } catch (error: any) {
      console.error('❌ [PLUGIN SERVICE] Database query failed:', error.message);
      console.error('📚 [PLUGIN SERVICE] Stack:', error.stack);
      return null;
    }
  }

  /**
   * Main processing method - adds watermark to images with "house" in filename
   * Uses active watermark spec from database if available, otherwise uses default
   * 
   * @param fileBuffer - The uploaded file as a Buffer
   * @param metadata - File metadata (filename, mimeType, size)
   * @returns PluginResult with tags and metadata
   */
  async processAsset(
    fileBuffer: Buffer,
    metadata: { filename: string; mimeType: string; size: number },
  ): Promise<PluginResult> {
    const startTime = Date.now();

    try {
      console.log('================================================================================');
      console.log('🎨 [PLUGIN SERVICE] Processing asset');
      console.log('--------------------------------------------------------------------------------');
      console.log('📁 [PLUGIN SERVICE] File details:', JSON.stringify({
        filename: metadata.filename,
        mimeType: metadata.mimeType,
        size: metadata.size,
        sizeInMB: (metadata.size / 1024 / 1024).toFixed(2) + ' MB',
        bufferLength: fileBuffer.length,
      }, null, 2));
      console.log('--------------------------------------------------------------------------------');

      // Check if filename contains "house" (case-insensitive)
      const shouldWatermark = /house/i.test(metadata.filename);
      const isImage = this.isImageFile(metadata.mimeType, metadata.filename);
      
      console.log(`📋 [PLUGIN SERVICE] Processing decision:`, JSON.stringify({
        shouldWatermark,
        isImage,
        willProcess: shouldWatermark && isImage,
        filenameCheck: metadata.filename,
      }, null, 2));

      let processedBuffer = fileBuffer;
      let watermarkApplied = false;
      let specUsed: string | null = null;

      // Apply watermark if conditions are met
      if (shouldWatermark && isImage) {
        console.log('🏠 [PLUGIN SERVICE] Filename contains "house" - applying watermark...');
        console.log(`🖼️  [PLUGIN SERVICE] Processing image: ${metadata.filename}`);
        
        try {
          // Try to get active spec from database
          const activeSpec = await this.getActiveWatermarkSpec();
          
          if (activeSpec && activeSpec.layers && activeSpec.layers.length > 0) {
            console.log('📋 [PLUGIN SERVICE] Using database spec:', {
              name: activeSpec.name,
              specId: activeSpec.specId,
              layerCount: activeSpec.layers.length,
            });
            processedBuffer = await this.applyWatermarkFromSpec(fileBuffer, activeSpec);
            specUsed = activeSpec.specId || activeSpec.name;
          } else {
            console.log('📋 [PLUGIN SERVICE] No active spec found, using default watermark');
            processedBuffer = await this.addDefaultWatermark(fileBuffer, 'WATERMARK');
            specUsed = 'default';
          }
          
          watermarkApplied = true;
          console.log('✅ [PLUGIN SERVICE] Watermark applied successfully');
          console.log(`📊 [PLUGIN SERVICE] Spec used: ${specUsed}`);
        } catch (error: any) {
          console.error('❌ [PLUGIN SERVICE] Watermark failed:', error.message);
          console.error('📚 [PLUGIN SERVICE] Stack:', error.stack);
          // Continue with original file if watermark fails
        }
      } else {
        if (!shouldWatermark) {
          console.log('⏭️  [PLUGIN SERVICE] Filename does not contain "house" - skipping watermark');
        } else if (!isImage) {
          console.log('⏭️  [PLUGIN SERVICE] File is not an image - skipping watermark');
        }
      }

      // Analyze the asset
      console.log('🔍 [PLUGIN SERVICE] Analyzing asset...');
      const analysisResult = await this.analyzeAsset(fileBuffer, metadata, watermarkApplied);
      console.log('📊 [PLUGIN SERVICE] Analysis result:', JSON.stringify(analysisResult, null, 2));

      // Transform results to DAM format
      console.log('📦 [PLUGIN SERVICE] Formatting result for DAM...');
      const result = this.formatResultForDAM(analysisResult);

      // Add processing information
      const processingTime = Date.now() - startTime;
      result.processingInfo = {
        processingTime,
        model: 'watermark-plugin-v1',
        version: '1.0.0',
        watermarkApplied,
      };

      // Include processed file if watermarked
      if (watermarkApplied) {
        const base64Length = Math.ceil(processedBuffer.length * 1.37);
        result.processedFile = processedBuffer.toString('base64');
        console.log(`📄 [PLUGIN SERVICE] Processed file included (base64 length: ${base64Length})`);
      }

      console.log('✅ [PLUGIN SERVICE] Processing complete');
      console.log(`⏱️  [PLUGIN SERVICE] Total processing time: ${processingTime}ms`);
      console.log('📊 [PLUGIN SERVICE] Result:', JSON.stringify(result, null, 2));
      console.log('================================================================================');

      return result;
    } catch (error: any) {
      console.error('❌ Error processing asset:', error.message);
      console.error('Stack:', error.stack);
      console.error('================================================================================');
      throw new Error(`Processing failed: ${error.message}`);
    }
  }

  /**
   * Analyze the asset and extract metadata
   * @param fileBuffer - The file buffer
   * @param metadata - File metadata
   * @param watermarkApplied - Whether watermark was applied
   */
  private async analyzeAsset(
    fileBuffer: Buffer,
    metadata: { filename: string; mimeType: string; size: number },
    watermarkApplied: boolean,
  ): Promise<any> {
    console.log('🔬 [PLUGIN SERVICE] Starting asset analysis...');
    
    const labels: Array<{ name: string; confidence: number }> = [];
    const additionalMetadata: any = {
      processedBy: 'watermark-plugin',
      timestamp: new Date().toISOString(),
      watermarkApplied,
    };

    // Add basic tags
    if (this.isImageFile(metadata.mimeType, metadata.filename)) {
      labels.push({ name: 'image', confidence: 1.0 });
      console.log('🏷️  [PLUGIN SERVICE] Added tag: image');

      // Try to get image dimensions using sharp
      try {
        const sharp = (await import('sharp')).default;
        const imageMetadata = await sharp(fileBuffer).metadata();
        additionalMetadata.width = imageMetadata.width;
        additionalMetadata.height = imageMetadata.height;
        additionalMetadata.format = imageMetadata.format;
        additionalMetadata.hasAlpha = imageMetadata.hasAlpha;

        console.log(`📐 [PLUGIN SERVICE] Image dimensions: ${imageMetadata.width}x${imageMetadata.height}`);
        console.log(`🎨 [PLUGIN SERVICE] Image format: ${imageMetadata.format}`);

        // Add dimension-based tags
        if (imageMetadata.width && imageMetadata.height) {
          const megapixels = (imageMetadata.width * imageMetadata.height) / 1000000;
          if (megapixels > 5) {
            labels.push({ name: 'high-resolution', confidence: 1.0 });
            console.log('🏷️  [PLUGIN SERVICE] Added tag: high-resolution');
          }

          // Orientation
          if (imageMetadata.width > imageMetadata.height) {
            labels.push({ name: 'landscape', confidence: 1.0 });
            console.log('🏷️  [PLUGIN SERVICE] Added tag: landscape');
          } else if (imageMetadata.height > imageMetadata.width) {
            labels.push({ name: 'portrait', confidence: 1.0 });
            console.log('🏷️  [PLUGIN SERVICE] Added tag: portrait');
          } else {
            labels.push({ name: 'square', confidence: 1.0 });
            console.log('🏷️  [PLUGIN SERVICE] Added tag: square');
          }
        }
      } catch (error: any) {
        console.error('⚠️  [PLUGIN SERVICE] Image analysis error:', error.message);
      }
    }

    // Check filename for "house"
    if (/house/i.test(metadata.filename)) {
      labels.push({ name: 'house', confidence: 1.0 });
      labels.push({ name: 'real-estate', confidence: 0.95 });
      additionalMetadata.category = 'real-estate';
      additionalMetadata.subject = 'house';
      console.log('🏷️  [PLUGIN SERVICE] Added tags: house, real-estate');
    }

    // Add watermark tag if applied
    if (watermarkApplied) {
      labels.push({ name: 'watermarked', confidence: 1.0 });
      additionalMetadata.watermark = 'HOUSE';
      console.log('🏷️  [PLUGIN SERVICE] Added tag: watermarked');
    }

    // File type tags
    const extension = metadata.filename.split('.').pop()?.toLowerCase();
    if (extension) {
      labels.push({ name: extension, confidence: 1.0 });
      console.log(`🏷️  [PLUGIN SERVICE] Added tag: ${extension}`);
    }

    console.log(`✅ [PLUGIN SERVICE] Analysis complete - ${labels.length} tags generated`);

    return {
      labels,
      metadata: additionalMetadata,
    };
  }

  /**
   * Apply watermark using the spec from database (matches UI rendering logic)
   */
  private async applyWatermarkFromSpec(
    imageBuffer: Buffer,
    spec: WatermarkSpec,
  ): Promise<Buffer> {
    console.log('🎨 [PLUGIN SERVICE] Applying watermark from spec...');
    console.log('📋 [PLUGIN SERVICE] Spec details:', {
      name: spec.name,
      specId: spec.specId,
      layerCount: spec.layers?.length || 0,
    });
    
    const sharp = (await import('sharp')).default;
    
    // Get image metadata
    const imgMeta = await sharp(imageBuffer).metadata();
    const width = imgMeta.width!;
    const height = imgMeta.height!;
    
    console.log(`📐 [PLUGIN SERVICE] Image size: ${width}x${height}`);
    
    // Build composite layers from spec
    const compositeOperations: any[] = [];
    
    for (const layer of spec.layers) {
      if (!layer.enabled) {
        console.log(`⏭️  [PLUGIN SERVICE] Skipping disabled layer: ${layer.name}`);
        continue;
      }
      
      console.log(`🔧 [PLUGIN SERVICE] Processing layer: ${layer.name} (${layer.type})`);
      
      if (layer.type === 'text' && layer.text) {
        const svgBuffer = this.createTextWatermarkSvg(layer, width, height);
        compositeOperations.push({
          input: svgBuffer,
          top: 0,
          left: 0,
        });
        console.log(`✅ [PLUGIN SERVICE] Added text layer: "${layer.text.content}"`);
      } else if (layer.type === 'image' && layer.image) {
        // Handle image layers (logos)
        const imageResource = spec.resources.images.find(
          r => r.id === layer.image!.resourceId
        );
        if (imageResource) {
          const logoBuffer = Buffer.from(imageResource.dataBase64, 'base64');
          const logoSvg = await this.createImageWatermarkSvg(layer, width, height, logoBuffer, imageResource);
          if (logoSvg) {
            compositeOperations.push({
              input: logoSvg,
              top: 0,
              left: 0,
            });
            console.log(`✅ [PLUGIN SERVICE] Added image layer: ${layer.name}`);
          }
        } else {
          console.log(`⚠️  [PLUGIN SERVICE] Image resource not found: ${layer.image.resourceId}`);
        }
      }
    }
    
    if (compositeOperations.length === 0) {
      console.log('⚠️  [PLUGIN SERVICE] No composite operations to apply, using default watermark');
      return this.addDefaultWatermark(imageBuffer, 'WATERMARK');
    }
    
    console.log(`🖌️  [PLUGIN SERVICE] Compositing ${compositeOperations.length} layers...`);
    
    const result = await sharp(imageBuffer)
      .composite(compositeOperations)
      .toBuffer();
    
    console.log(`✅ [PLUGIN SERVICE] Spec-based watermark applied (output: ${result.length} bytes)`);
    return result;
  }

  /**
   * Create SVG for text watermark layer
   * Uses shared calculateTilePlacements / calculateSinglePlacement from @dam-plugin/shared
   * so the server output matches the admin preview exactly.
   */
  private createTextWatermarkSvg(
    layer: WatermarkLayer,
    imageWidth: number,
    imageHeight: number,
  ): Buffer {
    const { size, appearance, text, mode, single, tile } = layer;
    
    // Calculate font size using the shared algorithm
    const fontSize = calculateElementSize(
      imageWidth,
      imageHeight,
      size.basis || 'percent-min-dimension',
      size.percent,
      size.clampMinPx || 12,
      size.clampMaxPx || 200,
    );
    
    console.log(`📏 [PLUGIN SERVICE] Text layer font size: ${fontSize}px (${size.percent}% of min dim)`);
    
    // Apply text transform
    let displayText = text?.content || 'WATERMARK';
    switch (text?.transform) {
      case 'uppercase':
        displayText = displayText.toUpperCase();
        break;
      case 'lowercase':
        displayText = displayText.toLowerCase();
        break;
      case 'capitalize':
        displayText = displayText.replace(/\b\w/g, c => c.toUpperCase());
        break;
    }
    
    const color = appearance.color || '#FFFFFF';
    const opacity = appearance.opacity || 0.7;
    const strokeEnabled = appearance.stroke?.enabled || false;
    const strokeColor = appearance.stroke?.color || '#000000';
    const strokeWidth = appearance.stroke?.width || 2;
    
    // Approximate text dimensions (server has no Canvas measureText)
    const textWidth = fontSize * displayText.length * 0.6;
    const textHeight = fontSize;
    
    // Build SVG with text placements using the SHARED tiling algorithm
    let textElements = '';
    
    if (mode === 'single' && single) {
      const placement = calculateSinglePlacement(
        imageWidth,
        imageHeight,
        textWidth,
        textHeight,
        single.anchor,
        single.positionNorm,
        single.marginNorm,
        single.rotationDeg || 0,
        single.keepInside,
      );
      
      textElements = `
        <text
          x="${placement.x}"
          y="${placement.y}"
          text-anchor="middle"
          dominant-baseline="middle"
          transform="rotate(${placement.rotation}, ${placement.x}, ${placement.y})"
          class="watermark"
        >${this.escapeXml(displayText)}</text>
      `;
    } else if (mode === 'tile' && tile) {
      const { placements } = calculateTilePlacements({
        imageWidth,
        imageHeight,
        elementWidth: textWidth,
        elementHeight: textHeight,
        config: tile,
      });
      
      console.log(`🔲 [PLUGIN SERVICE] Tile placements: ${placements.length} (shared algorithm)`);
      
      for (const p of placements) {
        textElements += `
          <text
            x="${p.x}"
            y="${p.y}"
            text-anchor="middle"
            dominant-baseline="middle"
            transform="rotate(${p.rotation}, ${p.x}, ${p.y})"
            class="watermark"
          >${this.escapeXml(displayText)}</text>
        `;
      }
    } else {
      // Default to bottom-right
      const x = imageWidth * 0.95;
      const y = imageHeight * 0.95;
      textElements = `
        <text
          x="${x}"
          y="${y}"
          text-anchor="end"
          dominant-baseline="auto"
          class="watermark"
        >${this.escapeXml(displayText)}</text>
      `;
    }
    
    const strokeStyle = strokeEnabled
      ? `stroke: ${strokeColor}; stroke-width: ${strokeWidth}px;`
      : '';
    
    const svg = `
      <svg width="${imageWidth}" height="${imageHeight}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .watermark {
            font-size: ${fontSize}px;
            font-family: 'DejaVu Sans', 'Liberation Sans', 'Noto Sans', Arial, sans-serif;
            font-weight: bold;
            fill: ${color};
            fill-opacity: ${opacity};
            ${strokeStyle}
          }
        </style>
        ${textElements}
      </svg>
    `;
    
    return Buffer.from(svg);
  }

  /**
   * Create SVG for image watermark layer (logo)
   * Uses shared calculateSinglePlacement / calculateElementSize from @dam-plugin/shared
   */
  private async createImageWatermarkSvg(
    layer: WatermarkLayer,
    imageWidth: number,
    imageHeight: number,
    logoBuffer: Buffer,
    resource: any,
  ): Promise<Buffer | null> {
    try {
      const sharp = (await import('sharp')).default;
      const { size, appearance, mode, single } = layer;
      
      // Calculate logo size using the shared algorithm
      const logoSize = calculateElementSize(
        imageWidth,
        imageHeight,
        size.basis || 'percent-image-width',
        size.percent,
        size.clampMinPx || 20,
        size.clampMaxPx || 500,
      );
      
      console.log(`📏 [PLUGIN SERVICE] Logo layer size: ${logoSize}px`);
      
      // Resize logo
      const resizedLogo = await sharp(logoBuffer)
        .resize(logoSize, logoSize, { fit: 'inside' })
        .toBuffer();
      
      const logoMeta = await sharp(resizedLogo).metadata();
      const logoWidth = logoMeta.width || logoSize;
      const logoHeight = logoMeta.height || logoSize;
      
      // Calculate position using the shared single placement algorithm
      let x = 0, y = 0;
      if (mode === 'single' && single) {
        const placement = calculateSinglePlacement(
          imageWidth,
          imageHeight,
          logoWidth,
          logoHeight,
          single.anchor,
          single.positionNorm,
          single.marginNorm,
          single.rotationDeg || 0,
          single.keepInside,
        );
        x = Math.round(placement.x - logoWidth / 2);
        y = Math.round(placement.y - logoHeight / 2);
      } else {
        // Default to bottom-right
        x = imageWidth - logoWidth - 20;
        y = imageHeight - logoHeight - 20;
      }
      
      // Create an SVG that positions the logo
      // For simplicity, we'll composite the resized logo directly
      const logoBase64 = resizedLogo.toString('base64');
      const opacity = appearance.opacity || 0.7;
      
      const svg = `
        <svg width="${imageWidth}" height="${imageHeight}" xmlns="http://www.w3.org/2000/svg">
          <image
            x="${x}"
            y="${y}"
            width="${logoWidth}"
            height="${logoHeight}"
            opacity="${opacity}"
            href="data:${resource.mimeType};base64,${logoBase64}"
          />
        </svg>
      `;
      
      return Buffer.from(svg);
    } catch (error: any) {
      console.error('❌ [PLUGIN SERVICE] Failed to create image watermark:', error.message);
      return null;
    }
  }

  // NOTE: calculateSinglePosition and createTiledTextSvg have been removed.
  // The server now uses calculateTilePlacements, calculateSinglePlacement, and
  // calculateElementSize from @dam-plugin/shared — the same algorithm as the
  // admin preview — so watermark output matches what users configure in the UI.

  /**
   * Escape XML special characters
   */
  private escapeXml(text: string): string {
    return text
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&apos;');
  }

  /**
   * Add default watermark (fallback when no spec available)
   */
  private async addDefaultWatermark(
    imageBuffer: Buffer,
    watermarkText: string,
  ): Promise<Buffer> {
    console.log(`🎯 [PLUGIN SERVICE] Adding default watermark: "${watermarkText}"`);
    
    const sharp = (await import('sharp')).default;
    
    // Get image metadata
    const metadata = await sharp(imageBuffer).metadata();
    console.log(`📐 [PLUGIN SERVICE] Image dimensions:`, JSON.stringify({
      width: metadata.width,
      height: metadata.height,
      format: metadata.format,
    }, null, 2));

    if (!metadata.width || !metadata.height) {
      throw new Error('Could not determine image dimensions');
    }

    // Calculate font size based on image size (10% of smallest dimension)
    const fontSize = Math.floor(Math.min(metadata.width, metadata.height) / 10);
    console.log(`📏 [PLUGIN SERVICE] Calculated font size: ${fontSize}px`);

    // Create SVG watermark - diagonal tiled pattern
    const step = Math.min(metadata.width, metadata.height) * 0.25;
    const rows = Math.ceil(metadata.height / step) + 2;
    const cols = Math.ceil(metadata.width / step) + 2;
    
    let textElements = '';
    for (let row = -1; row < rows; row++) {
      for (let col = -1; col < cols; col++) {
        let x = col * step;
        let y = row * step;
        
        // Stagger rows
        if (row % 2 === 1) {
          x += step / 2;
        }
        
        textElements += `
          <text
            x="${x}"
            y="${y}"
            text-anchor="middle"
            dominant-baseline="middle"
            transform="rotate(-30, ${x}, ${y})"
            class="watermark"
          >${this.escapeXml(watermarkText)}</text>
        `;
      }
    }

    const svgWatermark = `
      <svg width="${metadata.width}" height="${metadata.height}" xmlns="http://www.w3.org/2000/svg">
        <style>
          .watermark {
            font-size: ${fontSize}px;
            font-family: Arial, sans-serif;
            font-weight: bold;
            fill: rgba(255, 255, 255, 0.5);
            stroke: rgba(0, 0, 0, 0.3);
            stroke-width: 1;
          }
        </style>
        ${textElements}
      </svg>
    `;

    // Apply watermark
    console.log(`🖌️  [PLUGIN SERVICE] Compositing default watermark...`);
    const watermarkedImage = await sharp(imageBuffer)
      .composite([
        {
          input: Buffer.from(svgWatermark),
          top: 0,
          left: 0,
        },
      ])
      .toBuffer();

    console.log(`✅ [PLUGIN SERVICE] Default watermark applied (output: ${watermarkedImage.length} bytes)`);
    return watermarkedImage;
  }

  /**
   * Legacy method - kept for compatibility
   */
  private async addWatermark(
    imageBuffer: Buffer,
    watermarkText: string,
  ): Promise<Buffer> {
    return this.addDefaultWatermark(imageBuffer, watermarkText);
  }

  /**
   * Check if file is an image
   */
  private isImageFile(mimeType: string, filename: string): boolean {
    const imageMimeTypes = [
      'image/jpeg',
      'image/png',
      'image/gif',
      'image/webp',
      'image/tiff',
      'image/bmp',
    ];
    const imageExtensions = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'tiff', 'bmp'];
    const extension = filename.split('.').pop()?.toLowerCase();

    return (
      imageMimeTypes.includes(mimeType) ||
      (extension ? imageExtensions.includes(extension) : false)
    );
  }

  /**
   * Format analysis results to DAM-compatible structure
   */
  private formatResultForDAM(analysisResult: any): PluginResult {
    // Extract tags from analysis result
    const tags = (analysisResult.labels || [])
      .filter((label: any) => label.confidence > 0.7)
      .map((label: any) => label.name);

    // Build confidence scores
    const confidence: { [key: string]: number } = {};
    (analysisResult.labels || []).forEach((label: any) => {
      confidence[label.name] = label.confidence;
    });

    // Build metadata object
    const metadata = {
      ...analysisResult.metadata,
      processedAt: new Date().toISOString(),
      tagCount: tags.length,
    };

    return {
      tags,
      metadata,
      confidence,
    };
  }

  /**
   * Send processing results back to DAM via callback URL
   * The DAM expects the processed file to be sent back as multipart/form-data
   */
  async sendCallback(
    callbackUrl: string, 
    result: PluginResult,
    processedFileBuffer?: Buffer,
    originalFilename?: string,
    mimeType?: string,
    cookies?: string
  ): Promise<void> {
    console.log('================================================================================');
    console.log('📞 [PLUGIN SERVICE] Sending callback to DAM');
    console.log('--------------------------------------------------------------------------------');
    console.log('🔗 [PLUGIN SERVICE] Callback URL:', callbackUrl);
    console.log('📁 [PLUGIN SERVICE] Has processed file:', !!processedFileBuffer);
    
    // Log cookies before sending callback
    console.log('🍪 [PLUGIN SERVICE] *** COOKIES BEFORE CALLBACK ***');
    console.log('🍪 [PLUGIN SERVICE] Cookie header:', cookies || '(none)');
    if (cookies) {
      const cookieArray = cookies.split(';').map(c => c.trim());
      console.log('🍪 [PLUGIN SERVICE] Cookie count:', cookieArray.length);
      console.log('🍪 [PLUGIN SERVICE] Cookies:', cookieArray);
    }
    console.log('🍪 [PLUGIN SERVICE] *** END COOKIES ***');
    
    try {
      // If we have a processed file, send it as multipart/form-data
      if (processedFileBuffer && result.processedFile) {
        console.log('📤 [PLUGIN SERVICE] Sending processed file as multipart/form-data');
        console.log('📏 [PLUGIN SERVICE] File size:', processedFileBuffer.length, 'bytes');
        console.log('📋 [PLUGIN SERVICE] Filename:', originalFilename);
        console.log('🎨 [PLUGIN SERVICE] MIME type:', mimeType);

        const formData = new FormData();
        
        // Append the processed file
        formData.append('file', processedFileBuffer, {
          filename: originalFilename || 'processed-file.jpg',
          contentType: mimeType || 'image/jpeg',
        });

        // Append metadata as JSON
        formData.append('metadata', JSON.stringify({
          tags: result.tags,
          confidence: result.confidence,
          processingInfo: result.processingInfo,
          timestamp: new Date().toISOString(),
        }));

        console.log('🚀 [PLUGIN SERVICE] Posting to DAM callback URL...');
        
        const response = await axios.post(callbackUrl, formData, {
          headers: {
            ...formData.getHeaders(),
            'X-Plugin-Version': '1.0.0',
            ...(cookies && { 'Cookie': cookies }),
          },
          maxContentLength: Infinity,
          maxBodyLength: Infinity,
          timeout: 30000,
        });

        console.log('✅ [PLUGIN SERVICE] Callback sent successfully (multipart/form-data)');
        console.log('📊 [PLUGIN SERVICE] Response status:', response.status);
        console.log('📋 [PLUGIN SERVICE] Response data:', JSON.stringify(response.data, null, 2));
      } else {
        // No processed file - still need to send as multipart/form-data (DAM requirement)
        console.log('📤 [PLUGIN SERVICE] Sending multipart/form-data callback (no processed file)');
        
        const formData = new FormData();
        
        // DAM requires multipart/form-data even without a file
        // Append metadata as JSON string
        formData.append('metadata', JSON.stringify({
          status: 'success',
          tags: result.tags,
          confidence: result.confidence,
          processingInfo: result.processingInfo,
          timestamp: new Date().toISOString(),
        }));

        console.log('📦 [PLUGIN SERVICE] Metadata:', JSON.stringify({
          status: 'success',
          tags: result.tags,
          confidence: result.confidence,
          processingInfo: result.processingInfo,
        }, null, 2));

        const response = await axios.post(callbackUrl, formData, {
          headers: {
            ...formData.getHeaders(),
            'X-Plugin-Version': '1.0.0',
            ...(cookies && { 'Cookie': cookies }),
          },
          timeout: 10000,
        });

        console.log('✅ [PLUGIN SERVICE] Callback sent successfully (multipart/form-data, no file)');
        console.log('📊 [PLUGIN SERVICE] Response status:', response.status);
        console.log('📋 [PLUGIN SERVICE] Response data:', JSON.stringify(response.data, null, 2));
      }
      
      console.log('================================================================================');
    } catch (error: any) {
      console.error('❌ [PLUGIN SERVICE] Failed to send callback');
      console.error('🔴 [PLUGIN SERVICE] Error:', error.message);
      if (error.response) {
        console.error('📊 [PLUGIN SERVICE] Response status:', error.response.status);
        console.error('📋 [PLUGIN SERVICE] Response data:', JSON.stringify(error.response.data, null, 2));
      }
      if (error.code) {
        console.error('🔢 [PLUGIN SERVICE] Error code:', error.code);
      }
      console.error('📚 [PLUGIN SERVICE] Stack:', error.stack);
      console.error('================================================================================');
      
      // Don't throw - we don't want to fail the main request if callback fails
      // The plugin has already processed the asset successfully
    }
  }
}
