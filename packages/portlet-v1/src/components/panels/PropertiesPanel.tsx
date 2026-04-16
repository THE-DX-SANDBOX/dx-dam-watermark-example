// Properties Panel - Layer property editor

import { useSpec } from '@/state/SpecContext';
import { TextLayerProperties } from './properties/TextLayerProperties';
import { ImageLayerProperties } from './properties/ImageLayerProperties';

export function PropertiesPanel() {
  const { selectedLayer } = useSpec();

  return (
    <div className="h-full flex flex-col">
      <div className="panel-header">Properties</div>
      <div className="panel-content">
        {selectedLayer ? (
          selectedLayer.type === 'text' ? (
            <TextLayerProperties layer={selectedLayer} />
          ) : (
            <ImageLayerProperties layer={selectedLayer} />
          )
        ) : (
          <div className="flex items-center justify-center h-32 text-sm text-muted-foreground">
            Select a layer to edit
          </div>
        )}
      </div>
    </div>
  );
}
