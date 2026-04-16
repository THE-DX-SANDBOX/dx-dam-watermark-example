/**
 * API Client for Backend Communication
 * 
 * Uses relative paths for production (deployed to DX Portal)
 * so requests go through the same origin and HAProxy routes to the backend.
 */

// For local development, use localhost with the API base path
// For production (deployed as Script Application), use relative path
const isDev = import.meta.env.DEV;
const API_BASE_URL = import.meta.env.VITE_API_BASE_URL || 
  (isDev ? 'http://localhost:3000/api/dam-plugin' : '/api/dam-plugin');
const API_TIMEOUT = parseInt(import.meta.env.VITE_API_TIMEOUT || '30000');

console.log('🔧 [API] Configuration:', { isDev, API_BASE_URL });

export class APIClient {
  private baseURL: string;
  private timeout: number;

  constructor(baseURL: string = API_BASE_URL, timeout: number = API_TIMEOUT) {
    this.baseURL = baseURL;
    this.timeout = timeout;
  }

  async request<T>(endpoint: string, options: RequestInit = {}): Promise<T> {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), this.timeout);

    try {
      const response = await fetch(`${this.baseURL}${endpoint}`, {
        ...options,
        signal: controller.signal,
        headers: {
          'Content-Type': 'application/json',
          ...options.headers,
        },
        credentials: 'include', // Include cookies for DX Portal auth
      });

      clearTimeout(timeoutId);

      if (!response.ok) {
        const errorText = await response.text();
        throw new Error(`API Error: ${response.status} ${response.statusText} - ${errorText}`);
      }

      // Handle 204 No Content or empty responses
      if (response.status === 204 || response.headers.get('content-length') === '0') {
        return undefined as T;
      }

      // Check if there's a body to parse
      const text = await response.text();
      if (!text) {
        return undefined as T;
      }

      return JSON.parse(text);
    } catch (error) {
      clearTimeout(timeoutId);
      if (error instanceof Error && error.name === 'AbortError') {
        throw new Error('Request timeout');
      }
      throw error;
    }
  }

  get<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'GET' });
  }

  post<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'POST',
      body: JSON.stringify(data),
    });
  }

  put<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PUT',
      body: JSON.stringify(data),
    });
  }

  patch<T>(endpoint: string, data: unknown): Promise<T> {
    return this.request<T>(endpoint, {
      method: 'PATCH',
      body: JSON.stringify(data),
    });
  }

  delete<T>(endpoint: string): Promise<T> {
    return this.request<T>(endpoint, { method: 'DELETE' });
  }
}

// Export singleton instance
export const api = new APIClient();

// Project API Types (matching LoopBack backend)
export interface ProjectDB {
  id: string;
  name: string;
  description?: string;
  thumbnailUrl?: string;
  createdAt?: string;
  updatedAt?: string;
  createdBy?: string;
  status: 'draft' | 'published' | 'archived';
  metadata?: Record<string, unknown>;
}

// Specification API Types
export interface SpecificationDB {
  id: string;
  projectId: string;
  name: string;
  version: number;
  width: number;
  height: number;
  backgroundColor: string;
  tilingEnabled: boolean;
  tilingPattern?: string;
  tilingConfig?: Record<string, unknown>;
  specData: Record<string, unknown>; // The full WatermarkSpec JSON
  createdAt?: string;
  updatedAt?: string;
}

// Legacy type alias for backwards compatibility
// Note: Now using string IDs (UUIDs) from the server
export interface WatermarkConfigDB {
  id: string; // UUID from server
  name: string;
  description?: string;
  spec_data: unknown;
  status: 'active' | 'inactive';
  version: string;
  created_at: string;
  updated_at: string;
}

// Convert ProjectDB to legacy WatermarkConfigDB format for backwards compatibility
function projectToWatermarkConfig(project: ProjectDB, spec?: SpecificationDB): WatermarkConfigDB {
  return {
    id: project.id, // Keep UUID as string
    name: project.name,
    description: project.description,
    spec_data: spec?.specData || project.metadata || {},
    status: project.status === 'published' ? 'active' : 'inactive',
    version: '1.0.0',
    created_at: project.createdAt || new Date().toISOString(),
    updated_at: project.updatedAt || new Date().toISOString(),
  };
}

// Project API Service (primary API)
export const projectApi = {
  async getAll(): Promise<ProjectDB[]> {
    return api.get<ProjectDB[]>('/projects');
  },

  async getById(id: string): Promise<ProjectDB> {
    return api.get<ProjectDB>(`/projects/${id}`);
  },

  async create(project: Partial<ProjectDB>): Promise<ProjectDB> {
    return api.post<ProjectDB>('/projects', project);
  },

  async update(id: string, project: Partial<ProjectDB>): Promise<ProjectDB> {
    return api.patch<ProjectDB>(`/projects/${id}`, project);
  },

  async delete(id: string): Promise<void> {
    return api.delete<void>(`/projects/${id}`);
  },

  async getSpecifications(id: string): Promise<SpecificationDB[]> {
    return api.get<SpecificationDB[]>(`/projects/${id}/specifications`);
  },
};

// Specification API Service
export const specificationApi = {
  async getAll(): Promise<SpecificationDB[]> {
    return api.get<SpecificationDB[]>('/specifications');
  },

  async getById(id: string): Promise<SpecificationDB> {
    return api.get<SpecificationDB>(`/specifications/${id}`);
  },

  async create(spec: Partial<SpecificationDB>): Promise<SpecificationDB> {
    return api.post<SpecificationDB>('/specifications', spec);
  },

  async update(id: string, spec: Partial<SpecificationDB>): Promise<SpecificationDB> {
    return api.put<SpecificationDB>(`/specifications/${id}`, spec);
  },

  async delete(id: string): Promise<void> {
    return api.delete<void>(`/specifications/${id}`);
  },
};

// Watermark Config API Service (backwards compatible wrapper)
// Maps to Projects API but provides legacy interface
export const watermarkConfigApi = {
  // Get all watermark configs (from projects)
  async getAll(): Promise<WatermarkConfigDB[]> {
    try {
      const projects = await projectApi.getAll();
      console.log('📊 [API] Loaded projects:', projects);
      return projects.map(p => projectToWatermarkConfig(p));
    } catch (error) {
      console.error('❌ [API] Failed to load projects:', error);
      return [];
    }
  },

  // Get single watermark config by ID (UUID string)
  async getById(id: string): Promise<WatermarkConfigDB> {
    const project = await projectApi.getById(id);
    return projectToWatermarkConfig(project);
  },

  // Create new watermark config (creates a project)
  async create(config: {
    name: string;
    description?: string;
    spec_data: unknown;
    status?: 'active' | 'inactive';
    version?: string;
  }): Promise<WatermarkConfigDB> {
    // Ensure description is a string (LoopBack validation requires string type, not null)
    const project = await projectApi.create({
      name: config.name,
      description: config.description || '',
      status: config.status === 'active' ? 'published' : 'draft',
      metadata: config.spec_data as Record<string, unknown>,
    });
    return projectToWatermarkConfig(project);
  },

  // Update existing watermark config (id is UUID string)
  async update(id: string, config: {
    name?: string;
    description?: string;
    spec_data?: unknown;
    status?: 'active' | 'inactive';
    version?: string;
  }): Promise<WatermarkConfigDB> {
    // LoopBack requires 'name' field on every PUT request
    // Fetch current record to get required fields and merge with updates
    const current = await projectApi.getById(id);
    
    // Build update object with all required fields
    // LoopBack validation requires string types, not null/undefined
    const updateData: Partial<ProjectDB> = {
      name: config.name || current.name,
      description: config.description !== undefined ? (config.description || '') : (current.description || ''),
    };
    
    // Add optional fields if provided
    if (config.status !== undefined) {
      updateData.status = config.status === 'active' ? 'published' : 'draft';
    }
    if (config.spec_data !== undefined) {
      updateData.metadata = config.spec_data as Record<string, unknown>;
    }
    
    const updated = await projectApi.update(id, updateData);
    // If server returns 204 No Content, fetch the updated record
    if (!updated) {
      const project = await projectApi.getById(id);
      return projectToWatermarkConfig(project);
    }
    return projectToWatermarkConfig(updated);
  },

  // Delete watermark config (id is UUID string)
  async delete(id: string): Promise<void> {
    await projectApi.delete(id);
  },

  // Set a config as active (deactivates others)
  // Fetches the current record first to get all required fields, then updates status
  async setActive(id: string): Promise<WatermarkConfigDB> {
    // First fetch the current record to get required fields (LoopBack validation)
    const current = await projectApi.getById(id);
    
    // Now update with all required fields (name and description must be strings)
    const updated = await projectApi.update(id, {
      name: current.name,
      description: current.description || '',
      status: 'published',
    });
    
    if (!updated) {
      const project = await projectApi.getById(id);
      return projectToWatermarkConfig(project);
    }
    return projectToWatermarkConfig(updated);
  },

  // Health check
  async healthCheck(): Promise<{ status: string; timestamp: string }> {
    return api.get<{ status: string; timestamp: string }>('/health');
  },
};
