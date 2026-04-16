import {injectable, BindingScope} from '@loopback/core';
import {createCanvas, loadImage, Canvas, CanvasRenderingContext2D, Image} from 'canvas';
import {writeFile, mkdir} from 'fs/promises';
import {join} from 'path';
import {Specification} from '../models';

export interface RenderOptions {
  format?: 'png' | 'jpg' | 'webp' | 'svg';
  width?: number;
  height?: number;
  quality?: number;
  backgroundColor?: string;
}

export interface RenderResult {
  filePath: string;
  url: string;
  fileSize: number;
  width: number;
  height: number;
}

export interface TilingConfig {
  enabled: boolean;
  pattern: 'grid' | 'hexagonal' | 'brick' | 'diagonal';
  spacing: number;
  offset?: {x: number; y: number};
  rotation?: number;
}

@injectable({scope: BindingScope.TRANSIENT})
export class RenderingService {
  private outputDir: string;
  private baseUrl: string;

  constructor() {
    this.outputDir = process.env.RENDER_OUTPUT_DIR || '/tmp/water-muse-renders';
    this.baseUrl = process.env.BASE_URL || 'http://localhost:3000';
  }

  async renderSpecification(
    spec: Specification,
    options: RenderOptions = {},
  ): Promise<RenderResult> {
    const width = options.width || spec.width || 800;
    const height = options.height || spec.height || 600;
    const format = options.format || 'png';
    const quality = options.quality || 90;

    // Create canvas
    const canvas = createCanvas(width, height);
    const ctx = canvas.getContext('2d');

    // Set background
    const bgColor = options.backgroundColor || spec.specData?.backgroundColor || '#ffffff';
    ctx.fillStyle = bgColor;
    ctx.fillRect(0, 0, width, height);

    // Check if tiling is enabled
    const tilingConfig: TilingConfig = spec.specData?.tiling || {enabled: false, pattern: 'grid', spacing: 0};

    if (tilingConfig.enabled) {
      await this.renderWithTiling(ctx, spec, width, height, tilingConfig);
    } else {
      await this.renderLayers(ctx, spec, width, height);
    }

    // Generate filename
    const timestamp = Date.now();
    const filename = `${spec.id}_${timestamp}.${format}`;
    const filePath = join(this.outputDir, filename);

    // Ensure output directory exists
    await mkdir(this.outputDir, {recursive: true});

    // Save file
    let buffer: Buffer;
    if (format === 'png') {
      buffer = canvas.toBuffer('image/png');
    } else if (format === 'jpg') {
      buffer = canvas.toBuffer('image/jpeg', {quality: quality / 100});
    } else if (format === 'webp') {
      // @ts-ignore - canvas types may not include webp
      buffer = canvas.toBuffer('image/webp', {quality: quality / 100});
    } else {
      throw new Error(`Unsupported format: ${format}`);
    }

    await writeFile(filePath, buffer);

    return {
      filePath,
      url: `${this.baseUrl}/renders/${filename}`,
      fileSize: buffer.length,
      width,
      height,
    };
  }

  private async renderLayers(
    ctx: CanvasRenderingContext2D,
    spec: Specification,
    canvasWidth: number,
    canvasHeight: number,
  ): Promise<void> {
    const layers = spec.layers || [];

    // Sort layers by z-index
    const sortedLayers = [...layers].sort((a, b) => (a.zIndex || 0) - (b.zIndex || 0));

    for (const layer of sortedLayers) {
      if (!layer.visible) continue;

      ctx.save();

      // Apply layer transforms
      const x = layer.x || 0;
      const y = layer.y || 0;
      const width = layer.width || 100;
      const height = layer.height || 100;
      const rotation = layer.rotation || 0;
      const scaleX = layer.scaleX || 1;
      const scaleY = layer.scaleY || 1;
      const opacity = layer.opacity !== undefined ? layer.opacity : 1;

      // Set opacity
      ctx.globalAlpha = opacity;

      // Apply transformations
      ctx.translate(x + width / 2, y + height / 2);
      ctx.rotate((rotation * Math.PI) / 180);
      ctx.scale(scaleX, scaleY);
      ctx.translate(-(width / 2), -(height / 2));

      // Render based on layer type
      if (layer.type === 'image' && layer.layerData?.imageUrl) {
        await this.renderImageLayer(ctx, layer, width, height);
      } else if (layer.type === 'text' && layer.layerData?.text) {
        this.renderTextLayer(ctx, layer, width, height);
      } else if (layer.type === 'shape') {
        this.renderShapeLayer(ctx, layer, width, height);
      }

      ctx.restore();
    }
  }

  private async renderWithTiling(
    ctx: CanvasRenderingContext2D,
    spec: Specification,
    canvasWidth: number,
    canvasHeight: number,
    tilingConfig: TilingConfig,
  ): Promise<void> {
    const cellWidth = spec.width || 100;
    const cellHeight = spec.height || 100;
    const spacing = tilingConfig.spacing || 0;

    // Create a temporary canvas for the cell
    const cellCanvas = createCanvas(cellWidth, cellHeight);
    const cellCtx = cellCanvas.getContext('2d');

    // Render layers into cell
    cellCtx.fillStyle = spec.specData?.backgroundColor || '#ffffff';
    cellCtx.fillRect(0, 0, cellWidth, cellHeight);
    await this.renderLayers(cellCtx, spec, cellWidth, cellHeight);

    // Calculate grid dimensions
    const cols = Math.ceil(canvasWidth / (cellWidth + spacing));
    const rows = Math.ceil(canvasHeight / (cellHeight + spacing));

    // Tile the cell across the canvas
    if (tilingConfig.pattern === 'grid') {
      for (let row = 0; row < rows; row++) {
        for (let col = 0; col < cols; col++) {
          const x = col * (cellWidth + spacing);
          const y = row * (cellHeight + spacing);
          ctx.drawImage(cellCanvas, x, y);
        }
      }
    } else if (tilingConfig.pattern === 'brick') {
      for (let row = 0; row < rows; row++) {
        const offset = row % 2 === 1 ? cellWidth / 2 : 0;
        for (let col = 0; col < cols + 1; col++) {
          const x = col * (cellWidth + spacing) + offset;
          const y = row * (cellHeight + spacing);
          if (x < canvasWidth) {
            ctx.drawImage(cellCanvas, x, y);
          }
        }
      }
    } else if (tilingConfig.pattern === 'hexagonal') {
      const hexWidth = cellWidth;
      const hexHeight = cellHeight * 0.866; // sqrt(3)/2 for hex geometry
      for (let row = 0; row < rows; row++) {
        const offsetY = row % 2 === 1 ? hexHeight / 2 : 0;
        const offsetX = row % 2 === 1 ? hexWidth / 2 : 0;
        for (let col = 0; col < cols + 1; col++) {
          const x = col * (hexWidth + spacing) + offsetX;
          const y = row * (hexHeight + spacing) + offsetY;
          ctx.drawImage(cellCanvas, x, y);
        }
      }
    } else if (tilingConfig.pattern === 'diagonal') {
      ctx.save();
      ctx.rotate((45 * Math.PI) / 180);
      const diagCols = Math.ceil((canvasWidth + canvasHeight) / (cellWidth + spacing));
      const diagRows = Math.ceil((canvasWidth + canvasHeight) / (cellHeight + spacing));
      for (let row = 0; row < diagRows; row++) {
        for (let col = 0; col < diagCols; col++) {
          const x = col * (cellWidth + spacing);
          const y = row * (cellHeight + spacing);
          ctx.drawImage(cellCanvas, x, y);
        }
      }
      ctx.restore();
    }
  }

  private async renderImageLayer(
    ctx: CanvasRenderingContext2D,
    layer: any,
    width: number,
    height: number,
  ): Promise<void> {
    try {
      const imageUrl = layer.layerData.imageUrl;
      const image = await loadImage(imageUrl);

      // Apply filters if any
      if (layer.filters) {
        this.applyFilters(ctx, layer.filters);
      }

      ctx.drawImage(image, 0, 0, width, height);
    } catch (error) {
      console.error('Error loading image:', error);
      // Draw placeholder
      ctx.fillStyle = '#cccccc';
      ctx.fillRect(0, 0, width, height);
      ctx.strokeStyle = '#999999';
      ctx.strokeRect(0, 0, width, height);
    }
  }

  private renderTextLayer(
    ctx: CanvasRenderingContext2D,
    layer: any,
    width: number,
    height: number,
  ): void {
    const text = layer.layerData.text || '';
    const fontSize = layer.layerData.fontSize || 16;
    const fontFamily = layer.layerData.fontFamily || 'Arial';
    const color = layer.layerData.color || '#000000';
    const align = layer.layerData.align || 'left';
    const verticalAlign = layer.layerData.verticalAlign || 'top';

    ctx.font = `${fontSize}px ${fontFamily}`;
    ctx.fillStyle = color;
    ctx.textAlign = align;
    ctx.textBaseline = verticalAlign;

    // Calculate text position based on alignment
    let textX = 0;
    let textY = 0;

    if (align === 'center') textX = width / 2;
    else if (align === 'right') textX = width;

    if (verticalAlign === 'middle') textY = height / 2;
    else if (verticalAlign === 'bottom') textY = height;

    ctx.fillText(text, textX, textY);
  }

  private renderShapeLayer(
    ctx: CanvasRenderingContext2D,
    layer: any,
    width: number,
    height: number,
  ): void {
    const shapeType = layer.layerData.shapeType || 'rectangle';
    const fillColor = layer.layerData.fillColor || '#000000';
    const strokeColor = layer.layerData.strokeColor;
    const strokeWidth = layer.layerData.strokeWidth || 1;

    ctx.fillStyle = fillColor;
    if (strokeColor) {
      ctx.strokeStyle = strokeColor;
      ctx.lineWidth = strokeWidth;
    }

    if (shapeType === 'rectangle') {
      ctx.fillRect(0, 0, width, height);
      if (strokeColor) ctx.strokeRect(0, 0, width, height);
    } else if (shapeType === 'circle' || shapeType === 'ellipse') {
      const centerX = width / 2;
      const centerY = height / 2;
      const radiusX = width / 2;
      const radiusY = height / 2;

      ctx.beginPath();
      ctx.ellipse(centerX, centerY, radiusX, radiusY, 0, 0, 2 * Math.PI);
      ctx.fill();
      if (strokeColor) ctx.stroke();
    } else if (shapeType === 'triangle') {
      ctx.beginPath();
      ctx.moveTo(width / 2, 0);
      ctx.lineTo(width, height);
      ctx.lineTo(0, height);
      ctx.closePath();
      ctx.fill();
      if (strokeColor) ctx.stroke();
    }
  }

  private applyFilters(ctx: CanvasRenderingContext2D, filters: any): void {
    // Apply CSS filters (note: canvas 2D context has limited filter support)
    // For full filter support, consider using image manipulation libraries
    const filterStrings: string[] = [];

    if (filters.brightness) filterStrings.push(`brightness(${filters.brightness}%)`);
    if (filters.contrast) filterStrings.push(`contrast(${filters.contrast}%)`);
    if (filters.saturation) filterStrings.push(`saturate(${filters.saturation}%)`);
    if (filters.blur) filterStrings.push(`blur(${filters.blur}px)`);
    if (filters.hueRotate) filterStrings.push(`hue-rotate(${filters.hueRotate}deg)`);

    if (filterStrings.length > 0) {
      // @ts-ignore - filter property exists but may not be in types
      ctx.filter = filterStrings.join(' ');
    }
  }
}
