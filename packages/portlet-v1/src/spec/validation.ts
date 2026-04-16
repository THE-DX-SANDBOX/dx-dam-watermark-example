// Zod schema for Watermark Spec validation

import { z } from 'zod';
import { CURRENT_SCHEMA_VERSION } from './types';

// Enums
const SizeBasisSchema = z.enum(['percent-min-dimension', 'percent-image-width', 'percent-image-height']);
const AnchorSchema = z.enum(['top-left', 'top-right', 'bottom-left', 'bottom-right', 'center']);
const LayerModeSchema = z.enum(['tile', 'single']);
const TextTransformSchema = z.enum(['none', 'uppercase', 'lowercase', 'capitalize']);
const BlendModeSchema = z.enum(['normal', 'multiply', 'screen', 'overlay']);
const SpecStatusSchema = z.enum(['inactive', 'active']);

// Basic structures
const NormalizedPositionSchema = z.object({
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
});

const SizeConfigSchema = z.object({
  basis: SizeBasisSchema,
  percent: z.number().min(0.1).max(100),
  clampMinPx: z.number().min(1).max(10000),
  clampMaxPx: z.number().min(1).max(10000),
});

const StrokeConfigSchema = z.object({
  enabled: z.boolean(),
  width: z.number().min(0).max(20),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
});

const PlateConfigSchema = z.object({
  enabled: z.boolean(),
  padding: z.number().min(0).max(100),
  radius: z.number().min(0).max(50),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/),
  opacity: z.number().min(0).max(1),
});

const AppearanceConfigSchema = z.object({
  opacity: z.number().min(0).max(1),
  color: z.string().regex(/^#[0-9A-Fa-f]{6}$/).optional(),
  stroke: StrokeConfigSchema.optional(),
  plate: PlateConfigSchema.optional(),
  blendMode: BlendModeSchema,
});

const TileConfigSchema = z.object({
  angleDeg: z.number().min(-180).max(180),
  stepNorm: z.number().min(0.01).max(1),
  offsetNorm: NormalizedPositionSchema,
  staggerRows: z.boolean(),
});

const SingleConfigSchema = z.object({
  anchor: AnchorSchema,
  positionNorm: NormalizedPositionSchema,
  marginNorm: z.number().min(0).max(0.5),
  rotationDeg: z.number().min(-180).max(180),
  keepInside: z.boolean(),
});

const TextLayerDataSchema = z.object({
  content: z.string().min(1).max(500),
  transform: TextTransformSchema,
  fontFamily: z.string().optional(),
});

const ImageLayerDataSchema = z.object({
  resourceId: z.string(),
});

// Layer schemas (using union instead of discriminatedUnion to avoid refine issues)
const TextLayerSchema = z.object({
  id: z.string(),
  name: z.string().min(1).max(100),
  type: z.literal('text'),
  enabled: z.boolean(),
  mode: LayerModeSchema,
  size: SizeConfigSchema,
  appearance: AppearanceConfigSchema,
  text: TextLayerDataSchema,
  tile: TileConfigSchema.optional(),
  single: SingleConfigSchema.optional(),
});

const ImageLayerSchema = z.object({
  id: z.string(),
  name: z.string().min(1).max(100),
  type: z.literal('image'),
  enabled: z.boolean(),
  mode: LayerModeSchema,
  size: SizeConfigSchema,
  appearance: AppearanceConfigSchema,
  image: ImageLayerDataSchema,
  tile: TileConfigSchema.optional(),
  single: SingleConfigSchema.optional(),
});

const LayerSchema = z.union([TextLayerSchema, ImageLayerSchema]);

// Resource schemas
const FontResourceSchema = z.object({
  id: z.string(),
  fileName: z.string(),
  mimeType: z.string(),
  dataBase64: z.string(),
  sha256: z.string().length(64),
  familyName: z.string(),
  metadata: z.object({
    weight: z.number().optional(),
    style: z.string().optional(),
  }).optional(),
});

const ImageResourceSchema = z.object({
  id: z.string(),
  fileName: z.string(),
  mimeType: z.string(),
  dataBase64: z.string(),
  sha256: z.string().length(64),
  width: z.number().optional(),
  height: z.number().optional(),
});

// Output policy
const OutputPolicySchema = z.object({
  sizePolicy: z.literal('preserve-input'),
  resample: z.literal(false),
  crop: z.literal(false),
});

// Complete spec schema
export const WatermarkSpecSchema = z.object({
  schemaVersion: z.number().int().min(1).max(CURRENT_SCHEMA_VERSION),
  specId: z.string().min(1),
  specVersion: z.string().regex(/^\d+\.\d+\.\d+$/),
  name: z.string().min(1).max(200),
  description: z.string().max(1000).optional(),
  status: SpecStatusSchema,
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
  output: OutputPolicySchema,
  resources: z.object({
    font: FontResourceSchema.optional(),
    images: z.array(ImageResourceSchema),
  }),
  layers: z.array(LayerSchema).min(0).max(50),
});

// Validation function
export function validateSpec(spec: unknown): { valid: boolean; errors?: z.ZodError } {
  const result = WatermarkSpecSchema.safeParse(spec);
  if (result.success) {
    return { valid: true };
  }
  return { valid: false, errors: result.error };
}

// Type inference from schema
export type ValidatedWatermarkSpec = z.infer<typeof WatermarkSpecSchema>;
