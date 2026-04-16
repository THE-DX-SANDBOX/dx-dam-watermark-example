// Tiling Math Unit Tests
import { describe, it, expect } from 'vitest';
import {
  calculateTilePlacements,
  calculateSinglePlacement,
  calculateElementSize,
  densityToStepNorm,
  stepNormToDensity,
} from '@/math/tiling';

describe('calculateElementSize', () => {
  it('calculates size based on percent-min-dimension', () => {
    // For a 1920x1080 image, min dimension is 1080
    // 10% of 1080 = 108
    const size = calculateElementSize(1920, 1080, 'percent-min-dimension', 10, 50, 500);
    expect(size).toBe(108);
  });

  it('calculates size based on percent-image-width', () => {
    // For a 1920x1080 image, 10% of width = 192
    const size = calculateElementSize(1920, 1080, 'percent-image-width', 10, 50, 500);
    expect(size).toBe(192);
  });

  it('clamps size to minimum', () => {
    // For a 100x100 image, 1% = 1px, but clamp min is 50
    const size = calculateElementSize(100, 100, 'percent-min-dimension', 1, 50, 500);
    expect(size).toBe(50);
  });

  it('clamps size to maximum', () => {
    // For a 1920x1080 image, 50% of 1080 = 540, but clamp max is 500
    const size = calculateElementSize(1920, 1080, 'percent-min-dimension', 50, 50, 500);
    expect(size).toBe(500);
  });
});

describe('calculateTilePlacements', () => {
  it('produces deterministic placements', () => {
    const input = {
      imageWidth: 800,
      imageHeight: 600,
      elementWidth: 100,
      elementHeight: 30,
      config: {
        angleDeg: -30,
        stepNorm: 0.2,
        offsetNorm: { x: 0, y: 0 },
        staggerRows: true,
      },
    };

    const result1 = calculateTilePlacements(input);
    const result2 = calculateTilePlacements(input);

    // Same inputs should produce identical placements
    expect(result1.placements.length).toBe(result2.placements.length);
    expect(result1.placements).toEqual(result2.placements);
  });

  it('produces consistent placement count for fixed inputs', () => {
    const input = {
      imageWidth: 1920,
      imageHeight: 1080,
      elementWidth: 150,
      elementHeight: 40,
      config: {
        angleDeg: 0,
        stepNorm: 0.15,
        offsetNorm: { x: 0, y: 0 },
        staggerRows: false,
      },
    };

    const result = calculateTilePlacements(input);
    
    // Should produce a reasonable number of placements
    expect(result.placements.length).toBeGreaterThan(0);
    expect(result.placements.length).toBeLessThan(500); // Sanity check
  });

  it('covers the canvas with placements', () => {
    const input = {
      imageWidth: 800,
      imageHeight: 600,
      elementWidth: 80,
      elementHeight: 20,
      config: {
        angleDeg: 0,
        stepNorm: 0.15,
        offsetNorm: { x: 0, y: 0 },
        staggerRows: false,
      },
    };

    const result = calculateTilePlacements(input);
    
    // Check that placements exist in all quadrants
    const hasTopLeft = result.placements.some(p => p.x < 400 && p.y < 300);
    const hasTopRight = result.placements.some(p => p.x >= 400 && p.y < 300);
    const hasBottomLeft = result.placements.some(p => p.x < 400 && p.y >= 300);
    const hasBottomRight = result.placements.some(p => p.x >= 400 && p.y >= 300);

    expect(hasTopLeft).toBe(true);
    expect(hasTopRight).toBe(true);
    expect(hasBottomLeft).toBe(true);
    expect(hasBottomRight).toBe(true);
  });

  it('applies rotation correctly', () => {
    const input = {
      imageWidth: 800,
      imageHeight: 600,
      elementWidth: 80,
      elementHeight: 20,
      config: {
        angleDeg: -45,
        stepNorm: 0.2,
        offsetNorm: { x: 0, y: 0 },
        staggerRows: false,
      },
    };

    const result = calculateTilePlacements(input);
    
    // All placements should have the same rotation
    result.placements.forEach(p => {
      expect(p.rotation).toBe(-45);
    });
  });

  it('applies stagger offset for alternate rows', () => {
    const inputWithStagger = {
      imageWidth: 800,
      imageHeight: 600,
      elementWidth: 80,
      elementHeight: 20,
      config: {
        angleDeg: 0,
        stepNorm: 0.2,
        offsetNorm: { x: 0, y: 0 },
        staggerRows: true,
      },
    };

    const inputWithoutStagger = {
      ...inputWithStagger,
      config: { ...inputWithStagger.config, staggerRows: false },
    };

    const resultWithStagger = calculateTilePlacements(inputWithStagger);
    const resultWithoutStagger = calculateTilePlacements(inputWithoutStagger);

    // Staggered result should have different x positions
    expect(resultWithStagger.placements).not.toEqual(resultWithoutStagger.placements);
  });
});

describe('calculateSinglePlacement', () => {
  const imageWidth = 1920;
  const imageHeight = 1080;
  const elementWidth = 200;
  const elementHeight = 200;

  it('places element in bottom-right corner', () => {
    const placement = calculateSinglePlacement(
      imageWidth,
      imageHeight,
      elementWidth,
      elementHeight,
      'bottom-right',
      { x: 1, y: 1 },
      0.03,
      0,
      true
    );

    // Should be near bottom-right with 3% margin
    expect(placement.x).toBeLessThan(imageWidth);
    expect(placement.y).toBeLessThan(imageHeight);
    expect(placement.x).toBeGreaterThan(imageWidth - 200);
    expect(placement.y).toBeGreaterThan(imageHeight - 200);
  });

  it('places element in top-left corner', () => {
    const placement = calculateSinglePlacement(
      imageWidth,
      imageHeight,
      elementWidth,
      elementHeight,
      'top-left',
      { x: 0, y: 0 },
      0.03,
      0,
      true
    );

    // Should be near top-left
    expect(placement.x).toBeLessThan(200);
    expect(placement.y).toBeLessThan(200);
  });

  it('applies rotation', () => {
    const placement = calculateSinglePlacement(
      imageWidth,
      imageHeight,
      elementWidth,
      elementHeight,
      'center',
      { x: 0.5, y: 0.5 },
      0,
      45,
      false
    );

    expect(placement.rotation).toBe(45);
  });

  it('keeps element inside bounds when keepInside is true', () => {
    const placement = calculateSinglePlacement(
      imageWidth,
      imageHeight,
      elementWidth,
      elementHeight,
      'center',
      { x: 0, y: 0 }, // Would place element outside
      0.03,
      0,
      true
    );

    // Element should be constrained to stay inside with margin
    expect(placement.x).toBeGreaterThan(0);
    expect(placement.y).toBeGreaterThan(0);
    expect(placement.x).toBeLessThan(imageWidth);
    expect(placement.y).toBeLessThan(imageHeight);
  });
});

describe('density conversion', () => {
  it('converts density to stepNorm', () => {
    // High density (100) = small step
    expect(densityToStepNorm(100)).toBeCloseTo(0.05);
    // Low density (0) = large step
    expect(densityToStepNorm(0)).toBeCloseTo(0.8);
    // Medium density (50) = medium step
    expect(densityToStepNorm(50)).toBeCloseTo(0.425);
  });

  it('converts stepNorm to density', () => {
    // Small step = high density
    expect(stepNormToDensity(0.05)).toBe(100);
    // Large step = low density
    expect(stepNormToDensity(0.8)).toBe(0);
  });

  it('round-trips correctly', () => {
    const densities = [0, 25, 50, 75, 100];
    densities.forEach(d => {
      const stepNorm = densityToStepNorm(d);
      const roundTripped = stepNormToDensity(stepNorm);
      expect(roundTripped).toBe(d);
    });
  });
});
