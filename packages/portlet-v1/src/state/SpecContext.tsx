// Spec State Management with React Context and Reducer

import React, { createContext, useContext, useReducer, useCallback, useMemo } from 'react';
import type { 
  WatermarkSpec, 
  Layer, 
  FontResource,
  ImageResource,
  SpecStatus,
} from '@/spec/types';
import { 
  createDefaultSpec, 
  createDefaultTextLayer, 
  createDefaultLogoLayer,
  generateId,
} from '@/spec/types';

// Action types
type SpecAction =
  | { type: 'LOAD_SPEC'; payload: WatermarkSpec }
  | { type: 'NEW_SPEC'; payload: { id: string; name: string } }
  | { type: 'UPDATE_SPEC_NAME'; payload: string }
  | { type: 'UPDATE_SPEC_DESCRIPTION'; payload: string }
  | { type: 'ADD_LAYER'; payload: Layer }
  | { type: 'REMOVE_LAYER'; payload: string }
  | { type: 'UPDATE_LAYER'; payload: { id: string; updates: Partial<Layer> } }
  | { type: 'TOGGLE_LAYER_VISIBILITY'; payload: string }
  | { type: 'REORDER_LAYERS'; payload: string[] }
  | { type: 'DUPLICATE_LAYER'; payload: string }
  | { type: 'SELECT_LAYER'; payload: string | null }
  | { type: 'SET_FONT_RESOURCE'; payload: FontResource | undefined }
  | { type: 'ADD_IMAGE_RESOURCE'; payload: ImageResource }
  | { type: 'REMOVE_IMAGE_RESOURCE'; payload: string }
  | { type: 'MARK_DIRTY' }
  | { type: 'MARK_SAVED' }
  | { type: 'INCREMENT_VERSION' }
  | { type: 'SET_STATUS'; payload: SpecStatus };

interface SpecState {
  spec: WatermarkSpec;
  selectedLayerId: string | null;
  isDirty: boolean;
  lastSaved: string | null;
}

const initialState: SpecState = {
  spec: createDefaultSpec(generateId('spec'), 'New Watermark'),
  selectedLayerId: null,
  isDirty: false,
  lastSaved: null,
};

function specReducer(state: SpecState, action: SpecAction): SpecState {
  const now = new Date().toISOString();

  switch (action.type) {
    case 'LOAD_SPEC':
      return {
        ...state,
        spec: action.payload,
        selectedLayerId: action.payload.layers[0]?.id || null,
        isDirty: false,
      };

    case 'NEW_SPEC':
      const newSpec = createDefaultSpec(action.payload.id, action.payload.name);
      return {
        ...state,
        spec: newSpec,
        selectedLayerId: newSpec.layers[0]?.id || null,
        isDirty: false,
        lastSaved: null,
      };

    case 'UPDATE_SPEC_NAME':
      return {
        ...state,
        spec: { ...state.spec, name: action.payload, updatedAt: now },
        isDirty: true,
      };

    case 'UPDATE_SPEC_DESCRIPTION':
      return {
        ...state,
        spec: { ...state.spec, description: action.payload, updatedAt: now },
        isDirty: true,
      };

    case 'ADD_LAYER':
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: [...state.spec.layers, action.payload],
          updatedAt: now,
        },
        selectedLayerId: action.payload.id,
        isDirty: true,
      };

    case 'REMOVE_LAYER':
      const filteredLayers = state.spec.layers.filter(l => l.id !== action.payload);
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: filteredLayers,
          updatedAt: now,
        },
        selectedLayerId: state.selectedLayerId === action.payload 
          ? filteredLayers[0]?.id || null 
          : state.selectedLayerId,
        isDirty: true,
      };

    case 'UPDATE_LAYER':
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: state.spec.layers.map(layer =>
            layer.id === action.payload.id
              ? { ...layer, ...action.payload.updates } as Layer
              : layer
          ),
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'TOGGLE_LAYER_VISIBILITY':
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: state.spec.layers.map(layer =>
            layer.id === action.payload
              ? { ...layer, enabled: !layer.enabled }
              : layer
          ),
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'REORDER_LAYERS':
      const reorderedLayers = action.payload
        .map(id => state.spec.layers.find(l => l.id === id))
        .filter((l): l is Layer => l !== undefined);
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: reorderedLayers,
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'DUPLICATE_LAYER':
      const layerToDuplicate = state.spec.layers.find(l => l.id === action.payload);
      if (!layerToDuplicate) return state;
      
      const duplicatedLayer: Layer = {
        ...layerToDuplicate,
        id: generateId('layer'),
        name: `${layerToDuplicate.name} (Copy)`,
      };
      const insertIndex = state.spec.layers.findIndex(l => l.id === action.payload) + 1;
      const layersWithDuplicate = [
        ...state.spec.layers.slice(0, insertIndex),
        duplicatedLayer,
        ...state.spec.layers.slice(insertIndex),
      ];
      return {
        ...state,
        spec: {
          ...state.spec,
          layers: layersWithDuplicate,
          updatedAt: now,
        },
        selectedLayerId: duplicatedLayer.id,
        isDirty: true,
      };

    case 'SELECT_LAYER':
      return {
        ...state,
        selectedLayerId: action.payload,
      };

    case 'SET_FONT_RESOURCE':
      return {
        ...state,
        spec: {
          ...state.spec,
          resources: {
            ...state.spec.resources,
            font: action.payload,
          },
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'ADD_IMAGE_RESOURCE':
      return {
        ...state,
        spec: {
          ...state.spec,
          resources: {
            ...state.spec.resources,
            images: [...state.spec.resources.images, action.payload],
          },
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'REMOVE_IMAGE_RESOURCE':
      return {
        ...state,
        spec: {
          ...state.spec,
          resources: {
            ...state.spec.resources,
            images: state.spec.resources.images.filter(r => r.id !== action.payload),
          },
          updatedAt: now,
        },
        isDirty: true,
      };

    case 'MARK_DIRTY':
      return { ...state, isDirty: true };

    case 'MARK_SAVED':
      return { ...state, isDirty: false, lastSaved: now };

    case 'INCREMENT_VERSION':
      const [major, minor, patch] = state.spec.specVersion.split('.').map(Number);
      return {
        ...state,
        spec: {
          ...state.spec,
          specVersion: `${major}.${minor}.${patch + 1}`,
          updatedAt: now,
        },
      };

    case 'SET_STATUS':
      return {
        ...state,
        spec: { ...state.spec, status: action.payload, updatedAt: now },
        isDirty: true,
      };

    default:
      return state;
  }
}

// Context interface
interface SpecContextValue {
  state: SpecState;
  dispatch: React.Dispatch<SpecAction>;
  // Convenience methods
  selectedLayer: Layer | null;
  addTextLayer: () => void;
  addLogoLayer: () => void;
  updateSelectedLayer: (updates: Partial<Layer>) => void;
}

const SpecContext = createContext<SpecContextValue | null>(null);

export function SpecProvider({ children }: { children: React.ReactNode }) {
  const [state, dispatch] = useReducer(specReducer, initialState);

  const selectedLayer = useMemo(() => {
    if (!state.selectedLayerId) return null;
    return state.spec.layers.find(l => l.id === state.selectedLayerId) || null;
  }, [state.spec.layers, state.selectedLayerId]);

  const addTextLayer = useCallback(() => {
    const id = generateId('layer');
    const layer = createDefaultTextLayer(id, `Text Layer ${state.spec.layers.length + 1}`);
    dispatch({ type: 'ADD_LAYER', payload: layer });
  }, [state.spec.layers.length]);

  const addLogoLayer = useCallback(() => {
    const id = generateId('layer');
    const layer = createDefaultLogoLayer(id, `Logo Layer ${state.spec.layers.length + 1}`);
    dispatch({ type: 'ADD_LAYER', payload: layer });
  }, [state.spec.layers.length]);

  const updateSelectedLayer = useCallback((updates: Partial<Layer>) => {
    if (!state.selectedLayerId) return;
    dispatch({ type: 'UPDATE_LAYER', payload: { id: state.selectedLayerId, updates } });
  }, [state.selectedLayerId]);

  const value = useMemo(() => ({
    state,
    dispatch,
    selectedLayer,
    addTextLayer,
    addLogoLayer,
    updateSelectedLayer,
  }), [state, selectedLayer, addTextLayer, addLogoLayer, updateSelectedLayer]);

  return (
    <SpecContext.Provider value={value}>
      {children}
    </SpecContext.Provider>
  );
}

export function useSpec() {
  const context = useContext(SpecContext);
  if (!context) {
    throw new Error('useSpec must be used within a SpecProvider');
  }
  return context;
}

export function useSelectedLayer() {
  const { selectedLayer, updateSelectedLayer } = useSpec();
  return { selectedLayer, updateSelectedLayer };
}
