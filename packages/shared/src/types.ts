// Shared Watermark Types
// Environment-agnostic type definitions used by both client and server

export type SizeBasis = 'percent-min-dimension' | 'percent-image-width' | 'percent-image-height';
export type Anchor = 'top-left' | 'top-right' | 'bottom-left' | 'bottom-right' | 'center';
export type LayerType = 'text' | 'image';
export type LayerMode = 'tile' | 'single';
export type TextTransform = 'none' | 'uppercase' | 'lowercase' | 'capitalize';
export type BlendMode = 'normal' | 'multiply' | 'screen' | 'overlay';
export type SpecStatus = 'inactive' | 'active';

export interface NormalizedPosition {
  x: number;
  y: number;
}

export interface SizeConfig {
  basis: SizeBasis;
  percent: number;
  clampMinPx: number;
  clampMaxPx: number;
}

export interface StrokeConfig {
  enabled: boolean;
  width: number;
  color: string;
}

export interface PlateConfig {
  enabled: boolean;
  padding: number;
  radius: number;
  color: string;
  opacity: number;
}

export interface AppearanceConfig {
  opacity: number;
  color?: string;
  stroke?: StrokeConfig;
  plate?: PlateConfig;
  blendMode: BlendMode;
}

export interface TileConfig {
  angleDeg: number;
  stepNorm: number;
  offsetNorm: NormalizedPosition;
  staggerRows: boolean;
}

export interface SingleConfig {
  anchor: Anchor;
  positionNorm: NormalizedPosition;
  marginNorm: number;
  rotationDeg: number;
  keepInside: boolean;
}

export interface BaseLayer {
  id: string;
  name: string;
  type: LayerType;
  enabled: boolean;
  mode: LayerMode;
  size: SizeConfig;
  appearance: AppearanceConfig;
}

export interface TextLayerData {
  content: string;
  transform: TextTransform;
  fontFamily?: string;
}

export interface ImageLayerData {
  resourceId: string;
}

export interface TextLayer extends BaseLayer {
  type: 'text';
  text: TextLayerData;
  tile?: TileConfig;
  single?: SingleConfig;
}

export interface ImageLayer extends BaseLayer {
  type: 'image';
  image: ImageLayerData;
  tile?: TileConfig;
  single?: SingleConfig;
}

export type Layer = TextLayer | ImageLayer;

export interface FontResource {
  id: string;
  fileName: string;
  mimeType: string;
  dataBase64: string;
  sha256: string;
  familyName: string;
  metadata?: {
    weight?: number;
    style?: string;
  };
}

export interface ImageResource {
  id: string;
  fileName: string;
  mimeType: string;
  dataBase64: string;
  sha256: string;
  width?: number;
  height?: number;
}

export type Resource = FontResource | ImageResource;

export interface OutputPolicy {
  sizePolicy: 'preserve-input';
  resample: false;
  crop: false;
}

export interface WatermarkSpec {
  schemaVersion: number;
  specId: string;
  specVersion: string;
  name: string;
  description?: string;
  status: SpecStatus;
  createdAt: string;
  updatedAt: string;
  output: OutputPolicy;
  resources: {
    font?: FontResource;
    images: ImageResource[];
  };
  layers: Layer[];
}

export interface SpecMetadata {
  specId: string;
  name: string;
  description?: string;
  status: SpecStatus;
  specVersion: string;
  updatedAt: string;
  layerCount: number;
}

export const CURRENT_SCHEMA_VERSION = 1;
