// Image Layer Properties Editor

import { useSpec } from '@/state/SpecContext';
import type { ImageLayer, SizeBasis, Anchor, LayerMode } from '@/spec/types';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import { Slider } from '@/components/ui/slider';
import { Switch } from '@/components/ui/switch';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '@/components/ui/select';
import { Tabs, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { usePreview } from '@/state/PreviewContext';
import { calculateElementSize, stepNormToDensity, densityToStepNorm } from '@/math/tiling';
import { ImageIcon } from 'lucide-react';

interface ImageLayerPropertiesProps {
  layer: ImageLayer;
}

export function ImageLayerProperties({ layer }: ImageLayerPropertiesProps) {
  const { state, dispatch } = useSpec();
  const { currentImage } = usePreview();

  const updateLayer = (updates: Partial<ImageLayer>) => {
    dispatch({ type: 'UPDATE_LAYER', payload: { id: layer.id, updates } });
  };

  // Calculate computed size
  const computedSize = currentImage
    ? calculateElementSize(
        currentImage.width,
        currentImage.height,
        layer.size.basis,
        layer.size.percent,
        layer.size.clampMinPx,
        layer.size.clampMaxPx
      )
    : null;

  return (
    <div className="space-y-4">
      {/* Layer Name */}
      <div className="space-y-1.5">
        <Label className="text-xs">Layer Name</Label>
        <Input
          value={layer.name}
          onChange={(e) => updateLayer({ name: e.target.value })}
          className="h-8 text-sm"
        />
      </div>

      {/* Logo Source Selection */}
      <div className="space-y-1.5">
        <Label className="text-xs">Logo Source</Label>
        {state.spec.resources.images.length > 0 ? (
          <Select
            value={layer.image.resourceId}
            onValueChange={(v) => updateLayer({ image: { ...layer.image, resourceId: v } })}
          >
            <SelectTrigger className="h-8 text-sm">
              <SelectValue placeholder="Select a logo" />
            </SelectTrigger>
            <SelectContent>
              {state.spec.resources.images.map(img => (
                <SelectItem key={img.id} value={img.id}>
                  <div className="flex items-center gap-2">
                    <img 
                      src={`data:${img.mimeType};base64,${img.dataBase64}`} 
                      alt={img.fileName}
                      className="w-4 h-4 object-contain"
                    />
                    <span className="truncate">{img.fileName}</span>
                  </div>
                </SelectItem>
              ))}
            </SelectContent>
          </Select>
        ) : (
          <div className="flex items-center gap-2 px-2 py-2 border border-dashed border-border rounded text-xs text-muted-foreground">
            <ImageIcon className="w-4 h-4" />
            <span>Upload a logo in Resources panel</span>
          </div>
        )}
      </div>

      {/* Mode Toggle */}
      <div className="space-y-1.5">
        <Label className="text-xs">Mode</Label>
        <Tabs 
          value={layer.mode} 
          onValueChange={(v) => updateLayer({ mode: v as LayerMode })}
          className="w-full"
        >
          <TabsList className="w-full h-8">
            <TabsTrigger value="single" className="flex-1 text-xs">Single</TabsTrigger>
            <TabsTrigger value="tile" className="flex-1 text-xs">Tile</TabsTrigger>
          </TabsList>
        </Tabs>
      </div>

      {/* Size Section */}
      <div className="panel-section">
        <h4 className="panel-section-title">Size</h4>
        
        <div className="space-y-2">
          <div className="space-y-1.5">
            <Label className="text-xs">Basis</Label>
            <Select
              value={layer.size.basis}
              onValueChange={(v) => updateLayer({ size: { ...layer.size, basis: v as SizeBasis } })}
            >
              <SelectTrigger className="h-8 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="percent-image-width">% Image Width</SelectItem>
                <SelectItem value="percent-image-height">% Image Height</SelectItem>
                <SelectItem value="percent-min-dimension">% Min Dimension</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label className="text-xs">Size</Label>
              <span className="text-xs text-muted-foreground">{layer.size.percent}%</span>
            </div>
            <Slider
              value={[layer.size.percent]}
              onValueChange={([v]) => updateLayer({ size: { ...layer.size, percent: v } })}
              min={1}
              max={50}
              step={1}
              className="w-full"
            />
          </div>

          <div className="prop-row">
            <Label className="text-xs">Clamp Min</Label>
            <Input
              type="number"
              value={layer.size.clampMinPx}
              onChange={(e) => updateLayer({ size: { ...layer.size, clampMinPx: Number(e.target.value) } })}
              className="h-6 w-20 text-xs"
              min={1}
            />
          </div>

          <div className="prop-row">
            <Label className="text-xs">Clamp Max</Label>
            <Input
              type="number"
              value={layer.size.clampMaxPx}
              onChange={(e) => updateLayer({ size: { ...layer.size, clampMaxPx: Number(e.target.value) } })}
              className="h-6 w-20 text-xs"
              min={1}
            />
          </div>

          {computedSize && (
            <div className="prop-row bg-muted/50 rounded px-2 py-1">
              <span className="text-xs text-muted-foreground">Computed</span>
              <span className="text-xs font-mono">{Math.round(computedSize)}px</span>
            </div>
          )}
        </div>
      </div>

      {/* Placement Section (for single mode) */}
      {layer.mode === 'single' && layer.single && (
        <div className="panel-section">
          <h4 className="panel-section-title">Placement</h4>
          
          <div className="space-y-2">
            <div className="space-y-1.5">
              <Label className="text-xs">Anchor</Label>
              <Select
                value={layer.single.anchor}
                onValueChange={(v) => updateLayer({ single: { ...layer.single!, anchor: v as Anchor } })}
              >
                <SelectTrigger className="h-8 text-sm">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="top-left">Top Left</SelectItem>
                  <SelectItem value="top-right">Top Right</SelectItem>
                  <SelectItem value="bottom-left">Bottom Left</SelectItem>
                  <SelectItem value="bottom-right">Bottom Right</SelectItem>
                  <SelectItem value="center">Center</SelectItem>
                </SelectContent>
              </Select>
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label className="text-xs">Margin</Label>
                <span className="text-xs text-muted-foreground">{Math.round(layer.single.marginNorm * 100)}%</span>
              </div>
              <Slider
                value={[layer.single.marginNorm * 100]}
                onValueChange={([v]) => updateLayer({ single: { ...layer.single!, marginNorm: v / 100 } })}
                min={0}
                max={20}
                step={0.5}
                className="w-full"
              />
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label className="text-xs">Rotation</Label>
                <span className="text-xs text-muted-foreground">{layer.single.rotationDeg}°</span>
              </div>
              <Slider
                value={[layer.single.rotationDeg]}
                onValueChange={([v]) => updateLayer({ single: { ...layer.single!, rotationDeg: v } })}
                min={-180}
                max={180}
                step={5}
                className="w-full"
              />
            </div>

            <div className="prop-row">
              <Label className="text-xs">Keep Inside</Label>
              <Switch
                checked={layer.single.keepInside}
                onCheckedChange={(v) => updateLayer({ single: { ...layer.single!, keepInside: v } })}
              />
            </div>
          </div>
        </div>
      )}

      {/* Tile Pattern Section (for tile mode) */}
      {layer.mode === 'tile' && layer.tile && (
        <div className="panel-section">
          <h4 className="panel-section-title">Tile Pattern</h4>
          
          <div className="space-y-2">
            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label className="text-xs">Angle</Label>
                <span className="text-xs text-muted-foreground">{layer.tile.angleDeg}°</span>
              </div>
              <Slider
                value={[layer.tile.angleDeg]}
                onValueChange={([v]) => updateLayer({ tile: { ...layer.tile!, angleDeg: v } })}
                min={-90}
                max={90}
                step={5}
                className="w-full"
              />
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label className="text-xs">Density</Label>
                <span className="text-xs text-muted-foreground">{stepNormToDensity(layer.tile.stepNorm)}</span>
              </div>
              <Slider
                value={[stepNormToDensity(layer.tile.stepNorm)]}
                onValueChange={([v]) => updateLayer({ tile: { ...layer.tile!, stepNorm: densityToStepNorm(v) } })}
                min={0}
                max={100}
                step={5}
                className="w-full"
              />
            </div>

            <div className="prop-row">
              <Label className="text-xs">Stagger Rows</Label>
              <Switch
                checked={layer.tile.staggerRows}
                onCheckedChange={(v) => updateLayer({ tile: { ...layer.tile!, staggerRows: v } })}
              />
            </div>
          </div>
        </div>
      )}

      {/* Appearance Section */}
      <div className="panel-section">
        <h4 className="panel-section-title">Appearance</h4>
        
        <div className="space-y-2">
          <div className="space-y-1.5">
            <div className="flex items-center justify-between">
              <Label className="text-xs">Opacity</Label>
              <span className="text-xs text-muted-foreground">{Math.round(layer.appearance.opacity * 100)}%</span>
            </div>
            <Slider
              value={[layer.appearance.opacity * 100]}
              onValueChange={([v]) => updateLayer({ appearance: { ...layer.appearance, opacity: v / 100 } })}
              min={0}
              max={100}
              step={5}
              className="w-full"
            />
          </div>
        </div>
      </div>

      {/* Plate Section */}
      <div className="panel-section">
        <div className="flex items-center justify-between mb-2">
          <h4 className="panel-section-title mb-0">Background Plate</h4>
          <Switch
            checked={layer.appearance.plate?.enabled || false}
            onCheckedChange={(v) => updateLayer({
              appearance: {
                ...layer.appearance,
                plate: { 
                  ...layer.appearance.plate!, 
                  enabled: v, 
                  padding: 8, 
                  radius: 4, 
                  color: '#FFFFFF', 
                  opacity: 0.5 
                }
              }
            })}
          />
        </div>
        
        {layer.appearance.plate?.enabled && (
          <div className="space-y-2">
            <div className="prop-row">
              <Label className="text-xs">Padding</Label>
              <Input
                type="number"
                value={layer.appearance.plate.padding}
                onChange={(e) => updateLayer({
                  appearance: {
                    ...layer.appearance,
                    plate: { ...layer.appearance.plate!, padding: Number(e.target.value) }
                  }
                })}
                className="h-6 w-16 text-xs"
                min={0}
                max={50}
              />
            </div>

            <div className="prop-row">
              <Label className="text-xs">Radius</Label>
              <Input
                type="number"
                value={layer.appearance.plate.radius}
                onChange={(e) => updateLayer({
                  appearance: {
                    ...layer.appearance,
                    plate: { ...layer.appearance.plate!, radius: Number(e.target.value) }
                  }
                })}
                className="h-6 w-16 text-xs"
                min={0}
                max={50}
              />
            </div>

            <div className="prop-row">
              <Label className="text-xs">Color</Label>
              <input
                type="color"
                value={layer.appearance.plate.color}
                onChange={(e) => updateLayer({
                  appearance: {
                    ...layer.appearance,
                    plate: { ...layer.appearance.plate!, color: e.target.value }
                  }
                })}
                className="w-6 h-6 rounded border border-input cursor-pointer"
              />
            </div>

            <div className="space-y-1.5">
              <div className="flex items-center justify-between">
                <Label className="text-xs">Plate Opacity</Label>
                <span className="text-xs text-muted-foreground">{Math.round(layer.appearance.plate.opacity * 100)}%</span>
              </div>
              <Slider
                value={[layer.appearance.plate.opacity * 100]}
                onValueChange={([v]) => updateLayer({
                  appearance: {
                    ...layer.appearance,
                    plate: { ...layer.appearance.plate!, opacity: v / 100 }
                  }
                })}
                min={0}
                max={100}
                step={5}
                className="w-full"
              />
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
