// Canvas Watermark Renderer
// Uses the shared tiling math to render watermark preview

import { calculateTilePlacements, calculateSinglePlacement, calculateElementSize } from '@/math/tiling';
import type { WatermarkSpec, TextLayer, ImageLayer, ImageResource } from '@/spec/types';

interface RenderOptions {
  showTileGrid?: boolean;
  showSafeMargin?: boolean;
  safeMarginPercent?: number;
}

// Image cache for loaded logo images
const imageCache = new Map<string, HTMLImageElement>();

/**
 * Preload all image resources from a spec
 */
export function preloadSpecImages(spec: WatermarkSpec): Promise<void[]> {
  const promises = spec.resources.images.map(resource => {
    if (imageCache.has(resource.id)) {
      return Promise.resolve();
    }
    return loadImageResource(resource);
  });
  return Promise.all(promises);
}

function loadImageResource(resource: ImageResource): Promise<void> {
  return new Promise((resolve) => {
    const img = new Image();
    img.onload = () => {
      imageCache.set(resource.id, img);
      resolve();
    };
    img.onerror = () => {
      console.error(`Failed to load image resource: ${resource.id}`);
      resolve(); // Resolve anyway to not block rendering
    };
    img.src = `data:${resource.mimeType};base64,${resource.dataBase64}`;
  });
}

/**
 * Get cached image or null
 */
function getCachedImage(resourceId: string): HTMLImageElement | null {
  return imageCache.get(resourceId) || null;
}

/**
 * Render watermark layers onto a canvas
 */
export function renderWatermark(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number,
  spec: WatermarkSpec,
  options: RenderOptions = {}
): void {
  const { showTileGrid = false, showSafeMargin = false, safeMarginPercent = 5 } = options;

  // Render each enabled layer in order
  for (const layer of spec.layers) {
    if (!layer.enabled) continue;

    if (layer.type === 'text') {
      renderTextLayer(ctx, imageWidth, imageHeight, layer, spec);
    } else if (layer.type === 'image') {
      renderImageLayer(ctx, imageWidth, imageHeight, layer, spec);
    }
  }

  // Render overlays if enabled
  if (showTileGrid) {
    renderTileGridOverlay(ctx, imageWidth, imageHeight);
  }

  if (showSafeMargin) {
    renderSafeMarginOverlay(ctx, imageWidth, imageHeight, safeMarginPercent);
  }
}

function renderTextLayer(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number,
  layer: TextLayer,
  spec: WatermarkSpec
): void {
  const { size, appearance, text, mode, tile, single } = layer;

  // Calculate font size
  const fontSize = calculateElementSize(
    imageWidth,
    imageHeight,
    size.basis,
    size.percent,
    size.clampMinPx,
    size.clampMaxPx
  );

  // Apply text transform
  let displayText = text.content;
  switch (text.transform) {
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

  // Set font (use embedded font family or fallback)
  const fontFamily = spec.resources.font?.familyName || 'Arial, sans-serif';
  ctx.font = `${fontSize}px ${fontFamily}`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';

  // Measure text for element bounds
  const metrics = ctx.measureText(displayText);
  const textWidth = metrics.width;
  const textHeight = fontSize;

  // Get placements based on mode
  const placements = mode === 'tile' && tile
    ? calculateTilePlacements({
        imageWidth,
        imageHeight,
        elementWidth: textWidth,
        elementHeight: textHeight,
        config: tile,
      }).placements
    : single
    ? [calculateSinglePlacement(
        imageWidth,
        imageHeight,
        textWidth,
        textHeight,
        single.anchor,
        single.positionNorm,
        single.marginNorm,
        single.rotationDeg,
        single.keepInside
      )]
    : [];

  // Render each placement
  for (const placement of placements) {
    ctx.save();
    ctx.translate(placement.x, placement.y);
    ctx.rotate((placement.rotation * Math.PI) / 180);
    ctx.globalAlpha = appearance.opacity;

    // Draw stroke if enabled
    if (appearance.stroke?.enabled) {
      ctx.strokeStyle = appearance.stroke.color;
      ctx.lineWidth = appearance.stroke.width;
      ctx.strokeText(displayText, 0, 0);
    }

    // Draw fill
    ctx.fillStyle = appearance.color || '#FFFFFF';
    ctx.fillText(displayText, 0, 0);

    ctx.restore();
  }
}

function renderImageLayer(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number,
  layer: ImageLayer,
  spec: WatermarkSpec
): void {
  const { size, appearance, mode, tile, single, image } = layer;

  // Find the image resource
  const resource = spec.resources.images.find(r => r.id === image.resourceId);
  if (!resource) {
    // Render placeholder if no resource
    renderLogoPlaceholder(ctx, imageWidth, imageHeight, layer);
    return;
  }

  // Calculate logo size (maintaining aspect ratio)
  const logoSize = calculateElementSize(
    imageWidth,
    imageHeight,
    size.basis,
    size.percent,
    size.clampMinPx,
    size.clampMaxPx
  );

  // Get cached image
  const img = getCachedImage(image.resourceId);
  if (!img) {
    // Try to load synchronously (for first render)
    loadImageResource(resource);
    renderLogoPlaceholder(ctx, imageWidth, imageHeight, layer);
    return;
  }

  // Calculate aspect ratio-aware dimensions
  const aspectRatio = resource.width && resource.height ? resource.width / resource.height : 1;
  let drawWidth = logoSize;
  let drawHeight = logoSize;
  
  if (aspectRatio > 1) {
    drawHeight = logoSize / aspectRatio;
  } else {
    drawWidth = logoSize * aspectRatio;
  }

  // Get placements based on mode
  const placements = mode === 'tile' && tile
    ? calculateTilePlacements({
        imageWidth,
        imageHeight,
        elementWidth: drawWidth,
        elementHeight: drawHeight,
        config: tile,
      }).placements
    : single
    ? [calculateSinglePlacement(
        imageWidth,
        imageHeight,
        drawWidth,
        drawHeight,
        single.anchor,
        single.positionNorm,
        single.marginNorm,
        single.rotationDeg,
        single.keepInside
      )]
    : [];

  // Render each placement
  for (const placement of placements) {
    ctx.save();
    ctx.translate(placement.x, placement.y);
    ctx.rotate((placement.rotation * Math.PI) / 180);
    ctx.globalAlpha = appearance.opacity;

    // Draw plate background if enabled
    if (appearance.plate?.enabled) {
      const padding = appearance.plate.padding;
      ctx.fillStyle = appearance.plate.color;
      ctx.globalAlpha = appearance.plate.opacity * appearance.opacity;
      roundRect(
        ctx,
        -drawWidth / 2 - padding,
        -drawHeight / 2 - padding,
        drawWidth + padding * 2,
        drawHeight + padding * 2,
        appearance.plate.radius
      );
      ctx.fill();
      ctx.globalAlpha = appearance.opacity;
    }

    // Draw image centered
    ctx.drawImage(img, -drawWidth / 2, -drawHeight / 2, drawWidth, drawHeight);

    ctx.restore();
  }
}

function renderLogoPlaceholder(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number,
  layer: ImageLayer
): void {
  const { size, appearance, mode, single } = layer;

  const logoSize = calculateElementSize(
    imageWidth,
    imageHeight,
    size.basis,
    size.percent,
    size.clampMinPx,
    size.clampMaxPx
  );

  const placements = mode === 'single' && single
    ? [calculateSinglePlacement(
        imageWidth,
        imageHeight,
        logoSize,
        logoSize,
        single.anchor,
        single.positionNorm,
        single.marginNorm,
        single.rotationDeg,
        single.keepInside
      )]
    : [];

  for (const placement of placements) {
    ctx.save();
    ctx.translate(placement.x, placement.y);
    ctx.rotate((placement.rotation * Math.PI) / 180);
    ctx.globalAlpha = appearance.opacity;

    // Draw placeholder rectangle
    ctx.strokeStyle = 'rgba(255,255,255,0.5)';
    ctx.lineWidth = 2;
    ctx.setLineDash([4, 4]);
    ctx.strokeRect(-logoSize / 2, -logoSize / 2, logoSize, logoSize);

    // Draw placeholder text
    ctx.setLineDash([]);
    ctx.fillStyle = 'rgba(255,255,255,0.5)';
    ctx.font = '12px sans-serif';
    ctx.textAlign = 'center';
    ctx.textBaseline = 'middle';
    ctx.fillText('Logo', 0, 0);

    ctx.restore();
  }
}

function renderTileGridOverlay(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number
): void {
  ctx.save();
  ctx.strokeStyle = 'rgba(0, 150, 255, 0.3)';
  ctx.lineWidth = 1;
  ctx.setLineDash([4, 4]);

  const gridSize = 50;
  
  // Vertical lines
  for (let x = 0; x <= imageWidth; x += gridSize) {
    ctx.beginPath();
    ctx.moveTo(x, 0);
    ctx.lineTo(x, imageHeight);
    ctx.stroke();
  }

  // Horizontal lines
  for (let y = 0; y <= imageHeight; y += gridSize) {
    ctx.beginPath();
    ctx.moveTo(0, y);
    ctx.lineTo(imageWidth, y);
    ctx.stroke();
  }

  ctx.restore();
}

function renderSafeMarginOverlay(
  ctx: CanvasRenderingContext2D,
  imageWidth: number,
  imageHeight: number,
  marginPercent: number
): void {
  const marginX = (marginPercent / 100) * imageWidth;
  const marginY = (marginPercent / 100) * imageHeight;

  ctx.save();
  ctx.strokeStyle = 'rgba(255, 100, 100, 0.5)';
  ctx.lineWidth = 2;
  ctx.setLineDash([8, 4]);

  ctx.strokeRect(marginX, marginY, imageWidth - 2 * marginX, imageHeight - 2 * marginY);

  ctx.restore();
}

function roundRect(
  ctx: CanvasRenderingContext2D,
  x: number,
  y: number,
  width: number,
  height: number,
  radius: number
): void {
  ctx.beginPath();
  ctx.moveTo(x + radius, y);
  ctx.lineTo(x + width - radius, y);
  ctx.quadraticCurveTo(x + width, y, x + width, y + radius);
  ctx.lineTo(x + width, y + height - radius);
  ctx.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  ctx.lineTo(x + radius, y + height);
  ctx.quadraticCurveTo(x, y + height, x, y + height - radius);
  ctx.lineTo(x, y + radius);
  ctx.quadraticCurveTo(x, y, x + radius, y);
  ctx.closePath();
}
