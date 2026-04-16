// Tiling Math Module - Deterministic placement calculations
// Shared between the admin preview renderer (Canvas) and the server plugin (SVG/Sharp)

import type { TileConfig, NormalizedPosition } from './types';

export interface TilePlacement {
  x: number;
  y: number;
  rotation: number;
}

export interface TilingInput {
  imageWidth: number;
  imageHeight: number;
  elementWidth: number;
  elementHeight: number;
  config: TileConfig;
}

export interface TilingResult {
  placements: TilePlacement[];
  patternBounds: {
    minX: number;
    minY: number;
    maxX: number;
    maxY: number;
  };
}

/**
 * Calculate deterministic tile placements for a watermark pattern.
 * 
 * The algorithm:
 * 1. Calculate step size in pixels using min dimension
 * 2. Create a grid of placements in "pattern space" (unrotated)
 * 3. Apply stagger offset for alternate rows if enabled
 * 4. Apply user offset
 * 5. Rotate all points around image center
 * 6. Filter to placements that would be visible (with overdraw margin)
 */
export function calculateTilePlacements(input: TilingInput): TilingResult {
  const { imageWidth, imageHeight, elementWidth, elementHeight, config } = input;
  const { angleDeg, stepNorm, offsetNorm, staggerRows } = config;

  // Calculate dimensions
  const minDimension = Math.min(imageWidth, imageHeight);

  // Calculate base step from normalized value (this is the user-controlled spacing)
  const baseStepPx = stepNorm * minDimension;
  
  // Image center for rotation
  const centerX = imageWidth / 2;
  const centerY = imageHeight / 2;

  // Convert angle to radians
  const angleRad = (angleDeg * Math.PI) / 180;
  const cosA = Math.cos(angleRad);
  const sinA = Math.sin(angleRad);

  // Work in pattern-aligned coordinate system
  // - "along" direction: parallel to text baseline (direction of text flow)
  // - "perp" direction: perpendicular to text baseline (between rows)
  //
  // This ensures the perpendicular distance between rows is CONSTANT
  // regardless of rotation angle.

  const paddingFactor = 1.2; // 20% breathing room between tiles

  // Step along the text direction (between tiles in same row)
  // Must be at least element width to prevent overlap
  const minStepAlong = elementWidth * paddingFactor;
  const stepAlong = Math.max(baseStepPx, minStepAlong);

  // Step perpendicular to text (between rows)
  // Based on element HEIGHT only - this stays constant regardless of text length or angle
  const minStepPerp = elementHeight * paddingFactor;
  const stepPerp = Math.max(baseStepPx, minStepPerp);

  // Calculate the diagonal of the image (max distance from center to cover all corners)
  const diagonal = Math.sqrt(imageWidth * imageWidth + imageHeight * imageHeight);
  
  // We need enough rows and columns to cover the entire image after rotation
  // The coverage area in pattern space needs to be the diagonal
  const coverageRadius = diagonal / 2 + Math.max(elementWidth, elementHeight);

  // Calculate number of rows and columns needed
  const numCols = Math.ceil((coverageRadius * 2) / stepAlong) + 2;
  const numRows = Math.ceil((coverageRadius * 2) / stepPerp) + 2;

  // User offset in pattern space
  const offsetAlong = offsetNorm.x * stepAlong;
  const offsetPerp = offsetNorm.y * stepPerp;

  const placements: TilePlacement[] = [];

  // Generate grid points in PATTERN SPACE (aligned with text direction)
  // Then transform to image space
  for (let row = -Math.ceil(numRows / 2); row <= Math.ceil(numRows / 2); row++) {
    for (let col = -Math.ceil(numCols / 2); col <= Math.ceil(numCols / 2); col++) {
      // Position in pattern-aligned coordinates (relative to center)
      // "along" is the X-axis of pattern space, "perp" is the Y-axis
      let patternX = col * stepAlong + offsetAlong;
      let patternY = row * stepPerp + offsetPerp;

      // Apply stagger for alternate rows (shift along the text direction)
      if (staggerRows && row % 2 !== 0) {
        patternX += stepAlong / 2;
      }

      // Transform from pattern space to image space by rotating
      // Pattern space is rotated by angleDeg relative to image space
      const imageX = centerX + patternX * cosA - patternY * sinA;
      const imageY = centerY + patternX * sinA + patternY * cosA;

      // Check if placement would be visible (with element size margin)
      const margin = Math.max(elementWidth, elementHeight);
      if (
        imageX >= -margin &&
        imageX <= imageWidth + margin &&
        imageY >= -margin &&
        imageY <= imageHeight + margin
      ) {
        placements.push({
          x: imageX,
          y: imageY,
          rotation: angleDeg,
        });
      }
    }
  }

  // Sort placements for deterministic ordering (top-left to bottom-right in image space)
  placements.sort((a, b) => {
    const rowDiff = Math.floor(a.y / stepPerp) - Math.floor(b.y / stepPerp);
    if (rowDiff !== 0) return rowDiff;
    return a.x - b.x;
  });

  return {
    placements,
    patternBounds: {
      minX: -coverageRadius,
      minY: -coverageRadius,
      maxX: coverageRadius,
      maxY: coverageRadius,
    },
  };
}

/**
 * Calculate single placement position based on anchor and margins
 */
export function calculateSinglePlacement(
  imageWidth: number,
  imageHeight: number,
  elementWidth: number,
  elementHeight: number,
  anchor: string,
  positionNorm: NormalizedPosition,
  marginNorm: number,
  rotationDeg: number,
  keepInside: boolean
): TilePlacement {
  const marginX = marginNorm * imageWidth;
  const marginY = marginNorm * imageHeight;

  let x: number;
  let y: number;

  // Calculate base position from anchor
  switch (anchor) {
    case 'top-left':
      x = marginX + elementWidth / 2;
      y = marginY + elementHeight / 2;
      break;
    case 'top-right':
      x = imageWidth - marginX - elementWidth / 2;
      y = marginY + elementHeight / 2;
      break;
    case 'bottom-left':
      x = marginX + elementWidth / 2;
      y = imageHeight - marginY - elementHeight / 2;
      break;
    case 'bottom-right':
      x = imageWidth - marginX - elementWidth / 2;
      y = imageHeight - marginY - elementHeight / 2;
      break;
    case 'center':
      x = imageWidth * positionNorm.x;
      y = imageHeight * positionNorm.y;
      break;
    default:
      x = imageWidth * positionNorm.x;
      y = imageHeight * positionNorm.y;
  }

  // Apply keepInside constraint
  if (keepInside) {
    const halfW = elementWidth / 2;
    const halfH = elementHeight / 2;
    x = Math.max(halfW + marginX, Math.min(imageWidth - halfW - marginX, x));
    y = Math.max(halfH + marginY, Math.min(imageHeight - halfH - marginY, y));
  }

  return {
    x,
    y,
    rotation: rotationDeg,
  };
}

/**
 * Calculate element size in pixels based on size config
 */
export function calculateElementSize(
  imageWidth: number,
  imageHeight: number,
  basis: string,
  percent: number,
  clampMinPx: number,
  clampMaxPx: number
): number {
  let reference: number;

  switch (basis) {
    case 'percent-min-dimension':
      reference = Math.min(imageWidth, imageHeight);
      break;
    case 'percent-image-width':
      reference = imageWidth;
      break;
    case 'percent-image-height':
      reference = imageHeight;
      break;
    default:
      reference = Math.min(imageWidth, imageHeight);
  }

  const rawSize = (percent / 100) * reference;
  return Math.max(clampMinPx, Math.min(clampMaxPx, rawSize));
}

/**
 * Density slider value (0-100) to stepNorm (0.05-0.8)
 * Higher density = smaller step = more tiles
 * But minimum step is enforced in calculateTilePlacements based on element size
 */
export function densityToStepNorm(density: number): number {
  const minStep = 0.05;
  const maxStep = 0.8;
  const normalized = density / 100;
  return maxStep - normalized * (maxStep - minStep);
}

/**
 * stepNorm to density slider value
 */
export function stepNormToDensity(stepNorm: number): number {
  const minStep = 0.05;
  const maxStep = 0.8;
  const normalized = (maxStep - stepNorm) / (maxStep - minStep);
  return Math.round(Math.max(0, Math.min(100, normalized * 100)));
}
