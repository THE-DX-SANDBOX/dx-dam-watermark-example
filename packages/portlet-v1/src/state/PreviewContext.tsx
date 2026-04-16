// Preview State Management

import React, { createContext, useContext, useState, useMemo, useCallback, useEffect } from 'react';

export type ZoomLevel = 'fit' | number; // 'fit' or percentage (10-500)

const STORAGE_KEY = 'watermark-designer-preview';

interface SampleImage {
  id: string;
  name: string;
  url: string;
  width: number;
  height: number;
  isUploaded?: boolean; // Flag to distinguish uploaded vs preset images
}

interface PreviewState {
  // Current sample image
  currentImage: SampleImage | null;
  // Zoom level
  zoom: ZoomLevel;
  // Overlay toggles
  showTileGrid: boolean;
  showSafeMargin: boolean;
  // Uploaded sample images (for cycling through)
  uploadedImages: SampleImage[];
  // All available images (presets + uploaded)
  allImages: SampleImage[];
}

interface PreviewContextValue extends PreviewState {
  setCurrentImage: (image: SampleImage | null) => void;
  setZoom: (zoom: ZoomLevel) => void;
  zoomIn: () => void;
  zoomOut: () => void;
  toggleTileGrid: () => void;
  toggleSafeMargin: () => void;
  addUploadedImage: (image: SampleImage) => void;
  removeUploadedImage: (id: string) => void;
  loadImageFromFile: (file: File) => Promise<SampleImage>;
  // Navigation helpers
  nextImage: () => void;
  prevImage: () => void;
  currentImageIndex: number;
}

// Create SVG data URL helper - properly encode SVG
function createSvgDataUrl(svg: string): string {
  // Use base64 encoding for reliability
  const encoded = btoa(svg.trim());
  return `data:image/svg+xml;base64,${encoded}`;
}

// Default sample images (placeholders)
const defaultSamples: SampleImage[] = [
  {
    id: 'sample-landscape',
    name: 'Landscape (1920×1080)',
    url: createSvgDataUrl(`<svg xmlns="http://www.w3.org/2000/svg" width="1920" height="1080" viewBox="0 0 1920 1080"><defs><linearGradient id="bgGrad" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#3b82f6;stop-opacity:1"/><stop offset="100%" style="stop-color:#8b5cf6;stop-opacity:1"/></linearGradient></defs><rect width="1920" height="1080" fill="url(#bgGrad)"/><text x="960" y="520" font-family="system-ui" font-size="48" fill="white" text-anchor="middle" opacity="0.5">Sample Landscape Image</text><text x="960" y="580" font-family="system-ui" font-size="24" fill="white" text-anchor="middle" opacity="0.3">1920 x 1080</text></svg>`),
    width: 1920,
    height: 1080,
    isUploaded: false,
  },
  {
    id: 'sample-portrait',
    name: 'Portrait (1080×1920)',
    url: createSvgDataUrl(`<svg xmlns="http://www.w3.org/2000/svg" width="1080" height="1920" viewBox="0 0 1080 1920"><defs><linearGradient id="bgGrad2" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#10b981;stop-opacity:1"/><stop offset="100%" style="stop-color:#3b82f6;stop-opacity:1"/></linearGradient></defs><rect width="1080" height="1920" fill="url(#bgGrad2)"/><text x="540" y="940" font-family="system-ui" font-size="36" fill="white" text-anchor="middle" opacity="0.5">Sample Portrait</text><text x="540" y="990" font-family="system-ui" font-size="20" fill="white" text-anchor="middle" opacity="0.3">1080 x 1920</text></svg>`),
    width: 1080,
    height: 1920,
    isUploaded: false,
  },
  {
    id: 'sample-square',
    name: 'Square (1200×1200)',
    url: createSvgDataUrl(`<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="1200" viewBox="0 0 1200 1200"><defs><linearGradient id="bgGrad3" x1="0%" y1="0%" x2="100%" y2="100%"><stop offset="0%" style="stop-color:#f59e0b;stop-opacity:1"/><stop offset="100%" style="stop-color:#ef4444;stop-opacity:1"/></linearGradient></defs><rect width="1200" height="1200" fill="url(#bgGrad3)"/><text x="600" y="580" font-family="system-ui" font-size="40" fill="white" text-anchor="middle" opacity="0.5">Sample Square</text><text x="600" y="640" font-family="system-ui" font-size="22" fill="white" text-anchor="middle" opacity="0.3">1200 x 1200</text></svg>`),
    width: 1200,
    height: 1200,
    isUploaded: false,
  },
];

const PreviewContext = createContext<PreviewContextValue | null>(null);

// Load initial state from localStorage
function loadPersistedState() {
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) {
      const parsed = JSON.parse(stored);
      return {
        currentImageId: parsed.currentImageId || defaultSamples[0].id,
        zoom: parsed.zoom || 'fit',
        showTileGrid: parsed.showTileGrid || false,
        showSafeMargin: parsed.showSafeMargin || false,
        uploadedImages: parsed.uploadedImages || [],
      };
    }
  } catch (e) {
    console.warn('Failed to load preview state from localStorage:', e);
  }
  return {
    currentImageId: defaultSamples[0].id,
    zoom: 'fit' as ZoomLevel,
    showTileGrid: false,
    showSafeMargin: false,
    uploadedImages: [] as SampleImage[],
  };
}

export function PreviewProvider({ children }: { children: React.ReactNode }) {
  const initialState = loadPersistedState();
  
  const [uploadedImages, setUploadedImages] = useState<SampleImage[]>(initialState.uploadedImages);
  
  // Combine default samples with uploaded images
  const allImages = useMemo(() => [...defaultSamples, ...uploadedImages], [uploadedImages]);
  
  // Find initial image from all available images (kept for potential future use)
  const _findImageById = useCallback((id: string): SampleImage | null => {
    return allImages.find(s => s.id === id) || null;
  }, [allImages]);
  void _findImageById; // Suppress unused warning
  
  const [currentImage, setCurrentImageState] = useState<SampleImage | null>(() => {
    // Try to find from defaults first (uploaded images load async from storage)
    const fromDefaults = defaultSamples.find(s => s.id === initialState.currentImageId);
    if (fromDefaults) return fromDefaults;
    // Check uploaded
    const fromUploaded = initialState.uploadedImages.find((s: SampleImage) => s.id === initialState.currentImageId);
    return fromUploaded || defaultSamples[0];
  });
  
  const [zoom, setZoomState] = useState<ZoomLevel>(initialState.zoom as ZoomLevel);
  const [showTileGrid, setShowTileGrid] = useState(initialState.showTileGrid);
  const [showSafeMargin, setShowSafeMargin] = useState(initialState.showSafeMargin);

  // Current image index for navigation
  const currentImageIndex = useMemo(() => {
    if (!currentImage) return -1;
    return allImages.findIndex(img => img.id === currentImage.id);
  }, [currentImage, allImages]);

  // Persist state to localStorage
  useEffect(() => {
    const state = {
      currentImageId: currentImage?.id || defaultSamples[0].id,
      zoom,
      showTileGrid,
      showSafeMargin,
      uploadedImages,
    };
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
    } catch (e) {
      console.warn('Failed to persist preview state:', e);
    }
  }, [currentImage, zoom, showTileGrid, showSafeMargin, uploadedImages]);

  // Wrapper for setCurrentImage
  const setCurrentImage = useCallback((image: SampleImage | null) => {
    setCurrentImageState(image);
  }, []);

  // Wrapper for setZoom
  const setZoom = useCallback((newZoom: ZoomLevel) => {
    setZoomState(newZoom);
  }, []);

  // Zoom in by 10%
  const zoomIn = useCallback(() => {
    setZoomState(prev => {
      const currentPercent = prev === 'fit' ? 100 : prev;
      return Math.min(500, currentPercent + 10);
    });
  }, []);

  // Zoom out by 10%
  const zoomOut = useCallback(() => {
    setZoomState(prev => {
      const currentPercent = prev === 'fit' ? 100 : prev;
      return Math.max(10, currentPercent - 10);
    });
  }, []);

  const toggleTileGrid = useCallback(() => {
    setShowTileGrid((prev: boolean) => !prev);
  }, []);

  const toggleSafeMargin = useCallback(() => {
    setShowSafeMargin((prev: boolean) => !prev);
  }, []);

  const addUploadedImage = useCallback((image: SampleImage) => {
    const uploadedImage = { ...image, isUploaded: true };
    setUploadedImages(prev => [...prev, uploadedImage]);
    // Auto-select the newly uploaded image
    setCurrentImageState(uploadedImage);
  }, []);

  const removeUploadedImage = useCallback((id: string) => {
    setUploadedImages(prev => {
      const newList = prev.filter(img => img.id !== id);
      return newList;
    });
    // If current image was removed, select first available
    setCurrentImageState(current => {
      if (current?.id === id) {
        return defaultSamples[0];
      }
      return current;
    });
  }, []);

  const loadImageFromFile = useCallback((file: File): Promise<SampleImage> => {
    return new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = (e) => {
        const img = new Image();
        img.onload = () => {
          const sample: SampleImage = {
            id: `upload-${Date.now()}`,
            name: file.name,
            url: e.target?.result as string,
            width: img.naturalWidth,
            height: img.naturalHeight,
            isUploaded: true,
          };
          resolve(sample);
        };
        img.onerror = () => reject(new Error('Failed to load image'));
        img.src = e.target?.result as string;
      };
      reader.onerror = () => reject(new Error('Failed to read file'));
      reader.readAsDataURL(file);
    });
  }, []);

  // Navigation: next image
  const nextImage = useCallback(() => {
    if (allImages.length === 0) return;
    const nextIndex = (currentImageIndex + 1) % allImages.length;
    setCurrentImageState(allImages[nextIndex]);
  }, [allImages, currentImageIndex]);

  // Navigation: previous image
  const prevImage = useCallback(() => {
    if (allImages.length === 0) return;
    const prevIndex = (currentImageIndex - 1 + allImages.length) % allImages.length;
    setCurrentImageState(allImages[prevIndex]);
  }, [allImages, currentImageIndex]);

  const value = useMemo(() => ({
    currentImage,
    zoom,
    showTileGrid,
    showSafeMargin,
    uploadedImages,
    allImages,
    setCurrentImage,
    setZoom,
    zoomIn,
    zoomOut,
    toggleTileGrid,
    toggleSafeMargin,
    addUploadedImage,
    removeUploadedImage,
    loadImageFromFile,
    nextImage,
    prevImage,
    currentImageIndex,
  }), [
    currentImage,
    zoom,
    showTileGrid,
    showSafeMargin,
    uploadedImages,
    allImages,
    setCurrentImage,
    setZoom,
    zoomIn,
    zoomOut,
    toggleTileGrid,
    toggleSafeMargin,
    addUploadedImage,
    removeUploadedImage,
    loadImageFromFile,
    nextImage,
    prevImage,
    currentImageIndex,
  ]);

  return (
    <PreviewContext.Provider value={value}>
      {children}
    </PreviewContext.Provider>
  );
}

export function usePreview() {
  const context = useContext(PreviewContext);
  if (!context) {
    throw new Error('usePreview must be used within a PreviewProvider');
  }
  return context;
}

export { defaultSamples };
export type { SampleImage };
