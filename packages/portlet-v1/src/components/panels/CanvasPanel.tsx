// Canvas Panel - Preview area with toolbar and canvas

import { useRef, useEffect, useState, useCallback } from 'react';
import { 
  Grid3X3, 
  Square,
  Crosshair,
  Minus,
  Plus,
} from 'lucide-react';
import { useSpec } from '@/state/SpecContext';
import { usePreview } from '@/state/PreviewContext';
import { renderWatermark, preloadSpecImages } from '@/render/canvasRenderer';
import { cn } from '@/lib/utils';

export function CanvasPanel() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const [canvasScale, setCanvasScale] = useState(1);
  const [imageLoaded, setImageLoaded] = useState(false);
  const imageRef = useRef<HTMLImageElement | null>(null);

  const { state } = useSpec();
  const { spec } = state;
  const { 
    currentImage, 
    zoom, 
    setZoom,
    zoomIn,
    zoomOut,
    showTileGrid, 
    showSafeMargin,
    toggleTileGrid,
    toggleSafeMargin,
  } = usePreview();

  // Load image when currentImage changes
  useEffect(() => {
    if (!currentImage) {
      imageRef.current = null;
      setImageLoaded(false);
      return;
    }

    // Reset state when image changes
    setImageLoaded(false);
    
    const img = new Image();
    img.onload = () => {
      imageRef.current = img;
      setImageLoaded(true);
    };
    img.onerror = () => {
      console.error('Failed to load image:', currentImage.url.slice(0, 50));
      setImageLoaded(false);
    };
    img.src = currentImage.url;
    
    return () => {
      // Cleanup to prevent memory leaks
      img.onload = null;
      img.onerror = null;
    };
  }, [currentImage]);

  // Preload spec images whenever resources change
  useEffect(() => {
    preloadSpecImages(spec).then(() => {
      // Trigger re-render after images are loaded
      renderCanvas();
    });
  }, [spec.resources.images]);

  // Calculate canvas scale based on zoom and container size
  useEffect(() => {
    if (!containerRef.current || !currentImage) return;

    const container = containerRef.current;
    const containerWidth = container.clientWidth - 48; // padding
    const containerHeight = container.clientHeight - 48;

    let scale: number;
    if (zoom === 'fit') {
      const scaleX = containerWidth / currentImage.width;
      const scaleY = containerHeight / currentImage.height;
      scale = Math.min(scaleX, scaleY, 1);
    } else {
      // Numeric zoom percentage
      scale = zoom / 100;
    }

    setCanvasScale(scale);
  }, [zoom, currentImage, containerRef.current?.clientWidth, containerRef.current?.clientHeight]);

  // Render canvas
  const renderCanvas = useCallback(() => {
    const canvas = canvasRef.current;
    const img = imageRef.current;
    if (!canvas || !img || !currentImage || !imageLoaded) return;

    const ctx = canvas.getContext('2d');
    if (!ctx) return;

    // Set canvas size to match image dimensions
    canvas.width = currentImage.width;
    canvas.height = currentImage.height;

    // Clear canvas
    ctx.clearRect(0, 0, canvas.width, canvas.height);

    // Draw base image
    ctx.drawImage(img, 0, 0, currentImage.width, currentImage.height);

    // Render watermark layers
    renderWatermark(ctx, currentImage.width, currentImage.height, spec, {
      showTileGrid,
      showSafeMargin,
    });
  }, [currentImage, spec, showTileGrid, showSafeMargin, imageLoaded]);

  // Re-render on changes
  useEffect(() => {
    renderCanvas();
  }, [renderCanvas]);

  // Get display text for current zoom
  const zoomDisplayText = zoom === 'fit' ? 'Fit' : `${zoom}%`;

  return (
    <div className="h-full flex flex-col">
      {/* Toolbar */}
      <div className="flex-shrink-0 px-3 py-2 border-b border-panel-border bg-panel-header flex items-center justify-between">
        <div className="flex items-center gap-1">
          {/* Zoom controls */}
          <div className="toolbar">
            <button
              onClick={() => setZoom('fit')}
              className={cn('toolbar-btn text-xs px-2', zoom === 'fit' && 'active')}
            >
              Fit
            </button>
            <div className="toolbar-divider" />
            <button
              onClick={zoomOut}
              className="toolbar-btn"
              title="Zoom out (-10%)"
              disabled={zoom !== 'fit' && zoom <= 10}
            >
              <Minus className="w-3.5 h-3.5" />
            </button>
            <span className="text-xs text-muted-foreground px-2 min-w-[45px] text-center">
              {zoomDisplayText}
            </span>
            <button
              onClick={zoomIn}
              className="toolbar-btn"
              title="Zoom in (+10%)"
              disabled={zoom !== 'fit' && zoom >= 500}
            >
              <Plus className="w-3.5 h-3.5" />
            </button>
            <div className="toolbar-divider" />
            <button
              onClick={() => setZoom(100)}
              className={cn('toolbar-btn text-xs px-2', zoom === 100 && 'active')}
            >
              100%
            </button>
            <button
              onClick={() => setZoom(200)}
              className={cn('toolbar-btn text-xs px-2', zoom === 200 && 'active')}
            >
              200%
            </button>
          </div>
        </div>

        <div className="flex items-center gap-1">
          {/* Overlay toggles */}
          <div className="toolbar">
            <button
              onClick={toggleTileGrid}
              className={cn('toolbar-btn', showTileGrid && 'active')}
              title="Toggle Tile Grid"
            >
              <Grid3X3 className="w-4 h-4" />
            </button>
            <div className="toolbar-divider" />
            <button
              onClick={toggleSafeMargin}
              className={cn('toolbar-btn', showSafeMargin && 'active')}
              title="Toggle Safe Margin"
            >
              <Square className="w-4 h-4" />
            </button>
          </div>
        </div>

        {/* Image info */}
        {currentImage && (
          <div className="text-xs text-muted-foreground">
            {currentImage.width} × {currentImage.height} · {Math.round(canvasScale * 100)}%
          </div>
        )}
      </div>

      {/* Canvas area */}
      <div 
        ref={containerRef}
        className="canvas-area"
      >
        {currentImage && imageLoaded ? (
          <div 
            className="relative shadow-canvas"
            style={{
              width: currentImage.width * canvasScale,
              height: currentImage.height * canvasScale,
            }}
          >
            <canvas
              ref={canvasRef}
              className="block"
              style={{
                width: currentImage.width * canvasScale,
                height: currentImage.height * canvasScale,
              }}
            />
          </div>
        ) : (
          <div className="flex flex-col items-center justify-center text-muted-foreground">
            <Crosshair className="w-12 h-12 mb-4 opacity-20" />
            <p className="text-sm">Select a sample image to preview</p>
          </div>
        )}
      </div>
    </div>
  );
}
