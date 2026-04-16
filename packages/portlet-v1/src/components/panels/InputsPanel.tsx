// Inputs Panel - Sample images, resources, and layers

import { useState, useRef, useCallback } from 'react';
import { 
  Image, 
  Upload, 
  Type, 
  ImageIcon, 
  Plus,
  Eye,
  EyeOff,
  GripVertical,
  Copy,
  Trash2,
  ChevronDown,
  ChevronRight,
  ChevronLeft,
  FileType,
  X,
} from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Collapsible, CollapsibleContent, CollapsibleTrigger } from '@/components/ui/collapsible';
import { useSpec } from '@/state/SpecContext';
import { usePreview, defaultSamples } from '@/state/PreviewContext';
import { cn } from '@/lib/utils';
import type { ImageResource } from '@/spec/types';
import { generateId } from '@/spec/types';

// Utility to compute SHA256 hash
async function computeSHA256(data: string): Promise<string> {
  const encoder = new TextEncoder();
  const dataBuffer = encoder.encode(data);
  const hashBuffer = await crypto.subtle.digest('SHA-256', dataBuffer);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map(b => b.toString(16).padStart(2, '0')).join('');
}

// Convert file to base64
function fileToBase64(file: File): Promise<string> {
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => {
      const result = reader.result as string;
      // Remove data URL prefix
      const base64 = result.split(',')[1];
      resolve(base64);
    };
    reader.onerror = reject;
    reader.readAsDataURL(file);
  });
}

// Get image dimensions
function getImageDimensions(dataUrl: string): Promise<{ width: number; height: number }> {
  return new Promise((resolve, reject) => {
    const img = new window.Image();
    img.onload = () => resolve({ width: img.width, height: img.height });
    img.onerror = reject;
    img.src = dataUrl;
  });
}

export function InputsPanel() {
  return (
    <div className="h-full flex flex-col">
      <div className="panel-header">Inputs</div>
      <div className="panel-content space-y-2">
        <SampleImagesSection />
        <ResourcesSection />
        <LayersSection />
      </div>
    </div>
  );
}

function SampleImagesSection() {
  const [isOpen, setIsOpen] = useState(true);
  const { 
    currentImage, 
    setCurrentImage, 
    loadImageFromFile, 
    addUploadedImage,
    removeUploadedImage,
    uploadedImages,
    allImages,
    nextImage,
    prevImage,
    currentImageIndex,
  } = usePreview();
  const fileInputRef = useRef<HTMLInputElement>(null);

  const handleFileUpload = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = e.target.files;
    if (!files || files.length === 0) return;

    try {
      // Support multiple file uploads
      for (const file of Array.from(files)) {
        const sample = await loadImageFromFile(file);
        addUploadedImage(sample);
      }
    } catch (err) {
      console.error('Failed to load image:', err);
    }
    // Reset input
    e.target.value = '';
  };

  const handleRemoveUploaded = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    removeUploadedImage(id);
  };

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen}>
      <CollapsibleTrigger asChild>
        <button className="flex items-center gap-2 w-full py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors">
          {isOpen ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
          <Image className="w-3.5 h-3.5" />
          Sample Images
          <span className="ml-auto text-muted-foreground">{allImages.length}</span>
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent className="space-y-1 mt-1">
        <input
          ref={fileInputRef}
          type="file"
          accept="image/*"
          multiple
          onChange={handleFileUpload}
          className="hidden"
        />
        
        <button
          onClick={() => fileInputRef.current?.click()}
          className="w-full flex items-center gap-2 px-2 py-2 border border-dashed border-border rounded-md text-xs text-muted-foreground hover:border-primary hover:text-primary transition-colors"
        >
          <Upload className="w-3.5 h-3.5" />
          Upload Images
        </button>

        {/* Navigation indicator */}
        {allImages.length > 1 && (
          <div className="flex items-center justify-between px-2 py-1 text-xs text-muted-foreground bg-muted/50 rounded">
            <span>{currentImageIndex + 1} / {allImages.length}</span>
            <div className="flex gap-1">
              <button 
                onClick={prevImage}
                className="p-0.5 hover:bg-muted rounded"
                title="Previous (←)"
              >
                <ChevronLeft className="w-3.5 h-3.5" />
              </button>
              <button 
                onClick={nextImage}
                className="p-0.5 hover:bg-muted rounded"
                title="Next (→)"
              >
                <ChevronRight className="w-3.5 h-3.5" />
              </button>
            </div>
          </div>
        )}

        {/* Preset samples */}
        <div className="space-y-0.5">
          <div className="text-[10px] text-muted-foreground uppercase tracking-wider px-2 py-1">Presets</div>
          {defaultSamples.map(sample => (
            <button
              key={sample.id}
              onClick={() => setCurrentImage(sample)}
              className={cn(
                'w-full flex items-center gap-2 px-2 py-1.5 rounded text-xs text-left transition-colors',
                currentImage?.id === sample.id
                  ? 'bg-layer-selected text-foreground'
                  : 'text-muted-foreground hover:bg-layer-hover hover:text-foreground'
              )}
            >
              <div className="w-6 h-4 rounded bg-muted flex items-center justify-center overflow-hidden">
                <img src={sample.url} alt="" className="w-full h-full object-cover" />
              </div>
              <span className="truncate">{sample.name}</span>
            </button>
          ))}
        </div>

        {/* Uploaded images */}
        {uploadedImages.length > 0 && (
          <div className="space-y-0.5">
            <div className="text-[10px] text-muted-foreground uppercase tracking-wider px-2 py-1">Uploaded</div>
            {uploadedImages.map(sample => (
              <div
                key={sample.id}
                onClick={() => setCurrentImage(sample)}
                className={cn(
                  'w-full flex items-center gap-2 px-2 py-1.5 rounded text-xs text-left transition-colors cursor-pointer group',
                  currentImage?.id === sample.id
                    ? 'bg-layer-selected text-foreground'
                    : 'text-muted-foreground hover:bg-layer-hover hover:text-foreground'
                )}
              >
                <div className="w-6 h-4 rounded bg-muted flex items-center justify-center overflow-hidden flex-shrink-0">
                  <img src={sample.url} alt="" className="w-full h-full object-cover" />
                </div>
                <span className="truncate flex-1">{sample.name}</span>
                <span className="text-[10px] text-muted-foreground">
                  {sample.width}×{sample.height}
                </span>
                <button
                  onClick={(e) => handleRemoveUploaded(e, sample.id)}
                  className="p-0.5 opacity-0 group-hover:opacity-100 hover:bg-destructive/10 hover:text-destructive rounded transition-opacity"
                  title="Remove"
                >
                  <X className="w-3 h-3" />
                </button>
              </div>
            ))}
          </div>
        )}
      </CollapsibleContent>
    </Collapsible>
  );
}

function ResourcesSection() {
  const [isOpen, setIsOpen] = useState(true);
  const [isDragging, setIsDragging] = useState(false);
  const { state, dispatch } = useSpec();
  const { spec } = state;
  const logoInputRef = useRef<HTMLInputElement>(null);

  const handleLogoUpload = useCallback(async (file: File) => {
    if (!file.type.startsWith('image/')) {
      console.error('Invalid file type');
      return;
    }

    try {
      const base64 = await fileToBase64(file);
      const sha256 = await computeSHA256(base64);
      const dataUrl = `data:${file.type};base64,${base64}`;
      const dimensions = await getImageDimensions(dataUrl);

      const resource: ImageResource = {
        id: generateId('logo'),
        fileName: file.name,
        mimeType: file.type,
        dataBase64: base64,
        sha256,
        width: dimensions.width,
        height: dimensions.height,
      };

      dispatch({ type: 'ADD_IMAGE_RESOURCE', payload: resource });
    } catch (err) {
      console.error('Failed to process logo:', err);
    }
  }, [dispatch]);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) handleLogoUpload(file);
    e.target.value = '';
  };

  const handleDragOver = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(true);
  };

  const handleDragLeave = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);
  };

  const handleDrop = (e: React.DragEvent) => {
    e.preventDefault();
    e.stopPropagation();
    setIsDragging(false);

    const file = e.dataTransfer.files[0];
    if (file) handleLogoUpload(file);
  };

  const handleRemoveLogo = (id: string) => {
    dispatch({ type: 'REMOVE_IMAGE_RESOURCE', payload: id });
  };

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen}>
      <CollapsibleTrigger asChild>
        <button className="flex items-center gap-2 w-full py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors">
          {isOpen ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
          <FileType className="w-3.5 h-3.5" />
          Resources
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent className="space-y-1 mt-1">
        {/* Font resource */}
        <div className="px-2 py-1.5 rounded bg-muted/50 text-xs">
          <div className="flex items-center gap-2 text-muted-foreground">
            <Type className="w-3.5 h-3.5" />
            <span className="font-medium">Font</span>
          </div>
          <div className="mt-1 text-muted-foreground">
            {spec.resources.font ? (
              <span className="truncate">{spec.resources.font.familyName}</span>
            ) : (
              <span className="italic">System default</span>
            )}
          </div>
        </div>

        {/* Logo resources with drag-drop */}
        <div 
          className={cn(
            "px-2 py-1.5 rounded text-xs transition-colors",
            isDragging ? "bg-primary/10 border-2 border-dashed border-primary" : "bg-muted/50"
          )}
          onDragOver={handleDragOver}
          onDragLeave={handleDragLeave}
          onDrop={handleDrop}
        >
          <div className="flex items-center gap-2 text-muted-foreground">
            <ImageIcon className="w-3.5 h-3.5" />
            <span className="font-medium">Logos</span>
            <span className="ml-auto">{spec.resources.images.length}</span>
          </div>
          
          {spec.resources.images.length === 0 ? (
            <div className="mt-2 text-muted-foreground italic text-center py-2">
              {isDragging ? "Drop logo here" : "Drag & drop a logo"}
            </div>
          ) : (
            <div className="mt-2 space-y-1">
              {spec.resources.images.map(img => (
                <div 
                  key={img.id}
                  className="flex items-center gap-2 p-1 rounded bg-background/50 group"
                >
                  <div className="w-8 h-8 rounded bg-muted flex items-center justify-center overflow-hidden flex-shrink-0">
                    <img 
                      src={`data:${img.mimeType};base64,${img.dataBase64}`} 
                      alt={img.fileName}
                      className="w-full h-full object-contain"
                    />
                  </div>
                  <div className="flex-1 min-w-0">
                    <div className="truncate text-xs">{img.fileName}</div>
                    <div className="text-[10px] text-muted-foreground">
                      {img.width}×{img.height}
                    </div>
                  </div>
                  <button
                    onClick={() => handleRemoveLogo(img.id)}
                    className="p-1 opacity-0 group-hover:opacity-100 hover:bg-destructive/10 hover:text-destructive rounded transition-opacity"
                    title="Remove"
                  >
                    <X className="w-3 h-3" />
                  </button>
                </div>
              ))}
            </div>
          )}
        </div>

        <input
          ref={logoInputRef}
          type="file"
          accept="image/png,image/svg+xml,image/jpeg,image/webp"
          onChange={handleFileChange}
          className="hidden"
        />
        
        <button 
          onClick={() => logoInputRef.current?.click()}
          className="w-full flex items-center gap-2 px-2 py-1.5 border border-dashed border-border rounded text-xs text-muted-foreground hover:border-primary hover:text-primary transition-colors"
        >
          <Plus className="w-3.5 h-3.5" />
          Upload Logo
        </button>
      </CollapsibleContent>
    </Collapsible>
  );
}

function LayersSection() {
  const [isOpen, setIsOpen] = useState(true);
  const { state, dispatch, addTextLayer, addLogoLayer } = useSpec();
  const { spec, selectedLayerId } = state;

  const handleSelectLayer = (id: string) => {
    dispatch({ type: 'SELECT_LAYER', payload: id });
  };

  const handleToggleVisibility = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    dispatch({ type: 'TOGGLE_LAYER_VISIBILITY', payload: id });
  };

  const handleDuplicate = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    dispatch({ type: 'DUPLICATE_LAYER', payload: id });
  };

  const handleDelete = (e: React.MouseEvent, id: string) => {
    e.stopPropagation();
    dispatch({ type: 'REMOVE_LAYER', payload: id });
  };

  return (
    <Collapsible open={isOpen} onOpenChange={setIsOpen}>
      <CollapsibleTrigger asChild>
        <button className="flex items-center gap-2 w-full py-1.5 text-xs font-medium text-muted-foreground hover:text-foreground transition-colors">
          {isOpen ? <ChevronDown className="w-3 h-3" /> : <ChevronRight className="w-3 h-3" />}
          <svg className="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
            <rect x="3" y="3" width="18" height="6" rx="1" />
            <rect x="3" y="11" width="18" height="6" rx="1" />
          </svg>
          Layers
          <span className="ml-auto text-muted-foreground">{spec.layers.length}</span>
        </button>
      </CollapsibleTrigger>
      <CollapsibleContent className="space-y-1 mt-1">
        {/* Layer list */}
        <div className="space-y-0.5">
          {spec.layers.map(layer => (
            <div
              key={layer.id}
              onClick={() => handleSelectLayer(layer.id)}
              className={cn(
                'layer-item group',
                selectedLayerId === layer.id && 'selected',
                !layer.enabled && 'disabled'
              )}
            >
              <GripVertical className="w-3 h-3 text-muted-foreground opacity-0 group-hover:opacity-100 cursor-grab" />
              
              {layer.type === 'text' ? (
                <Type className="w-3.5 h-3.5 text-muted-foreground" />
              ) : (
                <ImageIcon className="w-3.5 h-3.5 text-muted-foreground" />
              )}

              <span className="flex-1 truncate text-xs">{layer.name}</span>

              <div className="flex items-center gap-0.5 opacity-0 group-hover:opacity-100 transition-opacity">
                <button
                  onClick={(e) => handleDuplicate(e, layer.id)}
                  className="p-1 hover:bg-muted rounded"
                  title="Duplicate"
                >
                  <Copy className="w-3 h-3" />
                </button>
                <button
                  onClick={(e) => handleDelete(e, layer.id)}
                  className="p-1 hover:bg-destructive/10 hover:text-destructive rounded"
                  title="Delete"
                >
                  <Trash2 className="w-3 h-3" />
                </button>
              </div>

              <button
                onClick={(e) => handleToggleVisibility(e, layer.id)}
                className="p-1 hover:bg-muted rounded"
                title={layer.enabled ? 'Hide' : 'Show'}
              >
                {layer.enabled ? (
                  <Eye className="w-3.5 h-3.5 text-muted-foreground" />
                ) : (
                  <EyeOff className="w-3.5 h-3.5 text-muted-foreground" />
                )}
              </button>
            </div>
          ))}
        </div>

        {/* Add layer buttons */}
        <div className="flex gap-1 pt-1">
          <Button
            variant="outline"
            size="sm"
            onClick={addTextLayer}
            className="flex-1 h-7 text-xs"
          >
            <Type className="w-3 h-3 mr-1" />
            Text
          </Button>
          <Button
            variant="outline"
            size="sm"
            onClick={addLogoLayer}
            className="flex-1 h-7 text-xs"
          >
            <ImageIcon className="w-3 h-3 mr-1" />
            Logo
          </Button>
        </div>
      </CollapsibleContent>
    </Collapsible>
  );
}
