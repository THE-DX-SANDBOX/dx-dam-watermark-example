// Text Layer Properties Editor

import { useSpec } from '@/state/SpecContext';
import type { TextLayer, TextTransform, SizeBasis, LayerMode } from '@/spec/types';
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

interface TextLayerPropertiesProps {
  layer: TextLayer;
}

export function TextLayerProperties({ layer }: TextLayerPropertiesProps) {
  const { dispatch } = useSpec();
  const { currentImage } = usePreview();

  const updateLayer = (updates: Partial<TextLayer>) => {
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

      {/* Mode Toggle */}
      <div className="space-y-1.5">
        <Label className="text-xs">Mode</Label>
        <Tabs 
          value={layer.mode} 
          onValueChange={(v) => updateLayer({ mode: v as LayerMode })}
          className="w-full"
        >
          <TabsList className="w-full h-8">
            <TabsTrigger value="tile" className="flex-1 text-xs">Tile</TabsTrigger>
            <TabsTrigger value="single" className="flex-1 text-xs">Single</TabsTrigger>
          </TabsList>
        </Tabs>
      </div>

      {/* Content Section */}
      <div className="panel-section">
        <h4 className="panel-section-title">Content</h4>
        
        <div className="space-y-2">
          <div className="space-y-1.5">
            <Label className="text-xs">Text</Label>
            <Input
              value={layer.text.content}
              onChange={(e) => updateLayer({ text: { ...layer.text, content: e.target.value } })}
              className="h-8 text-sm"
            />
          </div>

          <div className="space-y-1.5">
            <Label className="text-xs">Transform</Label>
            <Select
              value={layer.text.transform}
              onValueChange={(v) => updateLayer({ text: { ...layer.text, transform: v as TextTransform } })}
            >
              <SelectTrigger className="h-8 text-sm">
                <SelectValue />
              </SelectTrigger>
              <SelectContent>
                <SelectItem value="none">None</SelectItem>
                <SelectItem value="uppercase">UPPERCASE</SelectItem>
                <SelectItem value="lowercase">lowercase</SelectItem>
                <SelectItem value="capitalize">Capitalize</SelectItem>
              </SelectContent>
            </Select>
          </div>

          <div className="prop-row">
            <Label className="text-xs">Color</Label>
            <div className="flex items-center gap-2">
              <input
                type="color"
                value={layer.appearance.color || '#FFFFFF'}
                onChange={(e) => updateLayer({ appearance: { ...layer.appearance, color: e.target.value } })}
                className="w-8 h-6 rounded border border-input cursor-pointer"
              />
              <Input
                value={layer.appearance.color || '#FFFFFF'}
                onChange={(e) => updateLayer({ appearance: { ...layer.appearance, color: e.target.value } })}
                className="h-6 w-20 text-xs font-mono"
              />
            </div>
          </div>

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
              step={1}
              className="w-full"
            />
          </div>
        </div>
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
                <SelectItem value="percent-min-dimension">% Min Dimension</SelectItem>
                <SelectItem value="percent-image-width">% Image Width</SelectItem>
                <SelectItem value="percent-image-height">% Image Height</SelectItem>
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
              max={20}
              step={0.5}
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

      {/* Tile Pattern Section (only for tile mode) */}
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

      {/* Stroke Section */}
      <div className="panel-section">
        <div className="flex items-center justify-between mb-2">
          <h4 className="panel-section-title mb-0">Stroke</h4>
          <Switch
            checked={layer.appearance.stroke?.enabled || false}
            onCheckedChange={(v) => updateLayer({
              appearance: {
                ...layer.appearance,
                stroke: { ...layer.appearance.stroke!, enabled: v, width: 1, color: '#000000' }
              }
            })}
          />
        </div>
        
        {layer.appearance.stroke?.enabled && (
          <div className="space-y-2">
            <div className="prop-row">
              <Label className="text-xs">Width</Label>
              <Input
                type="number"
                value={layer.appearance.stroke.width}
                onChange={(e) => updateLayer({
                  appearance: {
                    ...layer.appearance,
                    stroke: { ...layer.appearance.stroke!, width: Number(e.target.value) }
                  }
                })}
                className="h-6 w-16 text-xs"
                min={0}
                max={20}
              />
            </div>

            <div className="prop-row">
              <Label className="text-xs">Color</Label>
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  value={layer.appearance.stroke.color}
                  onChange={(e) => updateLayer({
                    appearance: {
                      ...layer.appearance,
                      stroke: { ...layer.appearance.stroke!, color: e.target.value }
                    }
                  })}
                  className="w-6 h-6 rounded border border-input cursor-pointer"
                />
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
