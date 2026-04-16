// Tiling Math Module - Re-exports from @dam-plugin/shared
// The canonical implementation lives in packages/shared/src/tiling.ts

// Re-export everything from the shared package
export {
  calculateTilePlacements,
  calculateSinglePlacement,
  calculateElementSize,
  densityToStepNorm,
  stepNormToDensity,
} from '@dam-plugin/shared';

export type {
  TilePlacement,
  TilingInput,
  TilingResult,
} from '@dam-plugin/shared';
