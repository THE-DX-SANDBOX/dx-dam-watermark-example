// @dam-plugin/shared - Shared watermark types and tiling math
// Used by both portlet-v1 (client/Canvas) and server-v1 (Node/SVG+Sharp)

export {
  calculateTilePlacements,
  calculateSinglePlacement,
  calculateElementSize,
  densityToStepNorm,
  stepNormToDensity,
} from './tiling';

export type {
  TilePlacement,
  TilingInput,
  TilingResult,
} from './tiling';

export type {
  SizeBasis,
  Anchor,
  LayerType,
  LayerMode,
  TextTransform,
  BlendMode,
  SpecStatus,
  NormalizedPosition,
  SizeConfig,
  StrokeConfig,
  PlateConfig,
  AppearanceConfig,
  TileConfig,
  SingleConfig,
  BaseLayer,
  TextLayerData,
  ImageLayerData,
  TextLayer,
  ImageLayer,
  Layer,
  FontResource,
  ImageResource,
  Resource,
  OutputPolicy,
  WatermarkSpec,
  SpecMetadata,
} from './types';

export { CURRENT_SCHEMA_VERSION } from './types';
