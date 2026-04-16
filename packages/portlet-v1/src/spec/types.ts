// Watermark Spec Types - Re-exports shared types from @dam-plugin/shared,
// plus portlet-specific helper functions (createDefaultSpec, generateId, etc.)

// Re-export all shared types
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
} from '@dam-plugin/shared';

export { CURRENT_SCHEMA_VERSION } from '@dam-plugin/shared';

import type { WatermarkSpec, TextLayer, ImageLayer } from '@dam-plugin/shared';
import { CURRENT_SCHEMA_VERSION } from '@dam-plugin/shared';

// Helper to create default spec
export function createDefaultSpec(id: string, name: string = 'Untitled Spec'): WatermarkSpec {
  const now = new Date().toISOString();
  
  return {
    schemaVersion: CURRENT_SCHEMA_VERSION,
    specId: id,
    specVersion: '1.0.0',
    name,
    status: 'inactive',
    createdAt: now,
    updatedAt: now,
    output: {
      sizePolicy: 'preserve-input',
      resample: false,
      crop: false,
    },
    resources: {
      font: undefined,
      images: [],
    },
    layers: [
      createDefaultTextLayer('layer-text-1', 'Copyright Text'),
      createDefaultLogoLayer('layer-logo-1', 'Logo'),
    ],
  };
}

// Helper to create default text layer
export function createDefaultTextLayer(id: string, name: string): TextLayer {
  return {
    id,
    name,
    type: 'text',
    enabled: true,
    mode: 'tile',
    size: {
      basis: 'percent-min-dimension',
      percent: 4,
      clampMinPx: 12,
      clampMaxPx: 48,
    },
    appearance: {
      opacity: 0.25,
      color: '#FFFFFF',
      stroke: {
        enabled: false,
        width: 1,
        color: '#000000',
      },
      blendMode: 'normal',
    },
    text: {
      content: '© ACME',
      transform: 'none',
    },
    tile: {
      angleDeg: -30,
      stepNorm: 0.25, // Increased from 0.15 for better default spacing
      offsetNorm: { x: 0, y: 0 },
      staggerRows: true,
    },
  };
}

// Helper to create default logo layer
export function createDefaultLogoLayer(id: string, name: string): ImageLayer {
  return {
    id,
    name,
    type: 'image',
    enabled: true,
    mode: 'single',
    size: {
      basis: 'percent-image-width',
      percent: 12,
      clampMinPx: 80,
      clampMaxPx: 260,
    },
    appearance: {
      opacity: 0.8,
      plate: {
        enabled: false,
        padding: 8,
        radius: 4,
        color: '#FFFFFF',
        opacity: 0.5,
      },
      blendMode: 'normal',
    },
    image: {
      resourceId: 'logo-default',
    },
    single: {
      anchor: 'bottom-right',
      positionNorm: { x: 1, y: 1 },
      marginNorm: 0.03,
      rotationDeg: 0,
      keepInside: true,
    },
  };
}

// Generate unique ID
export function generateId(prefix: string = 'id'): string {
  return `${prefix}-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
}
