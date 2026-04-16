-- =============================================================================
-- Water Muse Database Schema
-- =============================================================================
-- This schema supports the Water Muse image designer application with:
-- - Project management
-- - Specification (canvas) configurations
-- - Layer management (images, text, shapes)
-- - Asset storage
-- - Render caching
-- - Version control
-- =============================================================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =============================================================================
-- Projects Table
-- =============================================================================
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    thumbnail_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    status VARCHAR(50) DEFAULT 'draft',
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    
    CONSTRAINT projects_status_check CHECK (status IN ('draft', 'published', 'archived'))
);

CREATE INDEX IF NOT EXISTS idx_projects_created_at ON projects(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_projects_status ON projects(status);
CREATE INDEX IF NOT EXISTS idx_projects_created_by ON projects(created_by);

-- =============================================================================
-- Specifications Table (Image Specs/Canvas Configurations)
-- =============================================================================
CREATE TABLE IF NOT EXISTS specifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version INTEGER DEFAULT 1,
    
    -- Canvas configuration
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    background_color VARCHAR(50) DEFAULT '#FFFFFF',
    
    -- Tiling configuration
    tiling_enabled BOOLEAN DEFAULT false,
    tiling_pattern VARCHAR(50),
    tiling_config JSONB,
    
    -- Full specification JSON (complete spec from frontend)
    spec_data JSONB NOT NULL,
    
    -- Metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    
    CONSTRAINT spec_tiling_pattern_check CHECK (
        tiling_pattern IS NULL OR 
        tiling_pattern IN ('grid', 'hexagonal', 'brick', 'diagonal', 'random')
    )
);

CREATE INDEX IF NOT EXISTS idx_specs_project ON specifications(project_id);
CREATE INDEX IF NOT EXISTS idx_specs_version ON specifications(project_id, version DESC);
CREATE INDEX IF NOT EXISTS idx_specs_active ON specifications(is_active);
CREATE INDEX IF NOT EXISTS idx_specs_created_at ON specifications(created_at DESC);

-- =============================================================================
-- Layers Table
-- =============================================================================
CREATE TABLE IF NOT EXISTS layers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spec_id UUID REFERENCES specifications(id) ON DELETE CASCADE,
    
    -- Layer identification
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    z_index INTEGER NOT NULL,
    
    -- Layer state
    visible BOOLEAN DEFAULT true,
    locked BOOLEAN DEFAULT false,
    opacity DECIMAL(3,2) DEFAULT 1.0,
    
    -- Position and dimensions
    x DECIMAL(10,2) DEFAULT 0,
    y DECIMAL(10,2) DEFAULT 0,
    width DECIMAL(10,2),
    height DECIMAL(10,2),
    rotation DECIMAL(10,2) DEFAULT 0,
    scale_x DECIMAL(10,4) DEFAULT 1.0,
    scale_y DECIMAL(10,4) DEFAULT 1.0,
    
    -- Layer-specific data (text content, image URL, shape properties)
    layer_data JSONB NOT NULL,
    
    -- Blend mode and effects
    blend_mode VARCHAR(50) DEFAULT 'normal',
    filters JSONB DEFAULT '[]',
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    CONSTRAINT layer_type_check CHECK (type IN ('image', 'text', 'shape', 'group')),
    CONSTRAINT layer_opacity_check CHECK (opacity >= 0 AND opacity <= 1)
);

CREATE INDEX IF NOT EXISTS idx_layers_spec ON layers(spec_id);
CREATE INDEX IF NOT EXISTS idx_layers_z_index ON layers(spec_id, z_index);
CREATE INDEX IF NOT EXISTS idx_layers_type ON layers(type);
CREATE INDEX IF NOT EXISTS idx_layers_visible ON layers(visible);

-- =============================================================================
-- Assets Table (Images/Fonts/Resources)
-- =============================================================================
CREATE TABLE IF NOT EXISTS assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    project_id UUID REFERENCES projects(id) ON DELETE SET NULL,
    
    -- Asset identification
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    mime_type VARCHAR(100),
    
    -- Storage
    storage_path TEXT NOT NULL,
    storage_provider VARCHAR(50) DEFAULT 'local',
    file_size BIGINT,
    
    -- Dimensions (for images)
    width INTEGER,
    height INTEGER,
    
    -- Metadata
    metadata JSONB DEFAULT '{}',
    tags TEXT[],
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    
    CONSTRAINT asset_type_check CHECK (type IN ('image', 'font', 'texture', 'template', 'icon'))
);

CREATE INDEX IF NOT EXISTS idx_assets_project ON assets(project_id);
CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(type);
CREATE INDEX IF NOT EXISTS idx_assets_tags ON assets USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_assets_created_at ON assets(created_at DESC);

-- =============================================================================
-- Rendered Images Table (Output Cache)
-- =============================================================================
CREATE TABLE IF NOT EXISTS rendered_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spec_id UUID REFERENCES specifications(id) ON DELETE CASCADE,
    
    -- Render configuration
    format VARCHAR(20) NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    quality INTEGER,
    
    -- Storage
    file_path TEXT NOT NULL,
    file_size BIGINT,
    file_url TEXT,
    
    -- Status
    status VARCHAR(50) DEFAULT 'pending',
    error_message TEXT,
    
    -- Timing
    render_time_ms INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP,
    
    CONSTRAINT render_format_check CHECK (format IN ('png', 'jpg', 'jpeg', 'webp', 'svg')),
    CONSTRAINT render_status_check CHECK (status IN ('pending', 'processing', 'completed', 'failed'))
);

CREATE INDEX IF NOT EXISTS idx_rendered_spec ON rendered_images(spec_id);
CREATE INDEX IF NOT EXISTS idx_rendered_status ON rendered_images(status);
CREATE INDEX IF NOT EXISTS idx_rendered_expires ON rendered_images(expires_at);
CREATE INDEX IF NOT EXISTS idx_rendered_created_at ON rendered_images(created_at DESC);

-- =============================================================================
-- Templates Table (Reusable Specs)
-- =============================================================================
CREATE TABLE IF NOT EXISTS templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    
    -- Template data (based on specification)
    template_spec JSONB NOT NULL,
    thumbnail_url TEXT,
    
    -- Usage tracking
    use_count INTEGER DEFAULT 0,
    
    -- Metadata
    tags TEXT[],
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_by VARCHAR(100),
    is_public BOOLEAN DEFAULT false
);

CREATE INDEX IF NOT EXISTS idx_templates_category ON templates(category);
CREATE INDEX IF NOT EXISTS idx_templates_public ON templates(is_public);
CREATE INDEX IF NOT EXISTS idx_templates_tags ON templates USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_templates_use_count ON templates(use_count DESC);

-- =============================================================================
-- Spec History (Version Control)
-- =============================================================================
CREATE TABLE IF NOT EXISTS spec_history (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    spec_id UUID REFERENCES specifications(id) ON DELETE CASCADE,
    version INTEGER NOT NULL,
    
    -- Snapshot of spec data
    spec_snapshot JSONB NOT NULL,
    layers_snapshot JSONB,
    
    -- Change metadata
    change_description TEXT,
    changed_by VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    
    UNIQUE(spec_id, version)
);

CREATE INDEX IF NOT EXISTS idx_spec_history_spec ON spec_history(spec_id, version DESC);
CREATE INDEX IF NOT EXISTS idx_spec_history_created_at ON spec_history(created_at DESC);

-- =============================================================================
-- Functions and Triggers
-- =============================================================================

-- Update timestamp trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Apply update triggers to tables
DROP TRIGGER IF EXISTS update_projects_updated_at ON projects;
CREATE TRIGGER update_projects_updated_at BEFORE UPDATE ON projects
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_specs_updated_at ON specifications;
CREATE TRIGGER update_specs_updated_at BEFORE UPDATE ON specifications
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_layers_updated_at ON layers;
CREATE TRIGGER update_layers_updated_at BEFORE UPDATE ON layers
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Increment spec version and save history on update
CREATE OR REPLACE FUNCTION increment_spec_version()
RETURNS TRIGGER AS $$
BEGIN
    -- Only increment if spec_data actually changed
    IF OLD.spec_data IS DISTINCT FROM NEW.spec_data THEN
        -- Save old version to history
        INSERT INTO spec_history (spec_id, version, spec_snapshot, changed_by)
        VALUES (
            OLD.id, 
            OLD.version, 
            OLD.spec_data,
            COALESCE(NEW.created_by, 'system')
        );
        
        -- Increment version
        NEW.version = OLD.version + 1;
    END IF;
    RETURN NEW;
END;
$$ language 'plpgsql';

DROP TRIGGER IF EXISTS track_spec_versions ON specifications;
CREATE TRIGGER track_spec_versions BEFORE UPDATE ON specifications
    FOR EACH ROW EXECUTE FUNCTION increment_spec_version();

-- =============================================================================
-- Views for Common Queries
-- =============================================================================

-- Active specifications with project info
CREATE OR REPLACE VIEW v_active_specifications AS
SELECT 
    s.*,
    p.name as project_name,
    p.description as project_description,
    p.status as project_status,
    (SELECT COUNT(*) FROM layers WHERE spec_id = s.id) as layer_count,
    (SELECT MAX(created_at) FROM layers WHERE spec_id = s.id) as last_layer_update
FROM specifications s
LEFT JOIN projects p ON s.project_id = p.id
WHERE s.is_active = true;

-- Projects with latest spec
CREATE OR REPLACE VIEW v_projects_with_latest_spec AS
SELECT 
    p.*,
    s.id as latest_spec_id,
    s.name as latest_spec_name,
    s.version as latest_spec_version,
    s.width as canvas_width,
    s.height as canvas_height
FROM projects p
LEFT JOIN LATERAL (
    SELECT * FROM specifications
    WHERE project_id = p.id AND is_active = true
    ORDER BY version DESC
    LIMIT 1
) s ON true;

-- Layer summary by specification
CREATE OR REPLACE VIEW v_spec_layer_summary AS
SELECT 
    spec_id,
    COUNT(*) as total_layers,
    COUNT(*) FILTER (WHERE type = 'image') as image_layers,
    COUNT(*) FILTER (WHERE type = 'text') as text_layers,
    COUNT(*) FILTER (WHERE type = 'shape') as shape_layers,
    COUNT(*) FILTER (WHERE visible = true) as visible_layers,
    COUNT(*) FILTER (WHERE locked = true) as locked_layers
FROM layers
GROUP BY spec_id;

-- =============================================================================
-- Initial Data / Sample Templates
-- =============================================================================

-- Insert default tiling patterns
INSERT INTO templates (name, description, category, template_spec, is_public, tags) VALUES
(
    'Grid Tiling', 
    'Basic grid tiling pattern for repeating images', 
    'Tiling',
    '{"tilingPattern": "grid", "tilingConfig": {"rows": 4, "cols": 4, "spacing": 10}, "width": 800, "height": 600}',
    true,
    ARRAY['tiling', 'grid', 'pattern']
),
(
    'Hexagonal Tiling', 
    'Honeycomb hexagonal pattern for unique layouts', 
    'Tiling',
    '{"tilingPattern": "hexagonal", "tilingConfig": {"size": 50, "spacing": 5}, "width": 800, "height": 600}',
    true,
    ARRAY['tiling', 'hexagonal', 'honeycomb']
),
(
    'Brick Pattern', 
    'Offset brick pattern for wall-like effects', 
    'Tiling',
    '{"tilingPattern": "brick", "tilingConfig": {"offset": 0.5, "spacing": 10}, "width": 800, "height": 600}',
    true,
    ARRAY['tiling', 'brick', 'offset']
),
(
    'Blank Canvas',
    'Empty canvas for custom designs',
    'Basic',
    '{"width": 1200, "height": 800, "backgroundColor": "#FFFFFF", "layers": []}',
    true,
    ARRAY['basic', 'blank', 'starter']
),
(
    'Social Media Post',
    'Standard social media image dimensions',
    'Social',
    '{"width": 1080, "height": 1080, "backgroundColor": "#F0F0F0", "layers": []}',
    true,
    ARRAY['social', 'instagram', 'square']
)
ON CONFLICT DO NOTHING;

-- =============================================================================
-- Permissions and Security
-- =============================================================================

-- Grant permissions (adjust user as needed)
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO water_muse_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO water_muse_user;
-- GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA public TO water_muse_user;

-- =============================================================================
-- Comments for Documentation
-- =============================================================================

COMMENT ON TABLE projects IS 'Top-level projects containing multiple specifications';
COMMENT ON TABLE specifications IS 'Canvas/image specifications with dimensions and tiling config';
COMMENT ON TABLE layers IS 'Individual layers within a specification (images, text, shapes)';
COMMENT ON TABLE assets IS 'Uploaded images, fonts, and other resources';
COMMENT ON TABLE rendered_images IS 'Cache of rendered output images';
COMMENT ON TABLE templates IS 'Reusable specification templates';
COMMENT ON TABLE spec_history IS 'Version control history for specifications';

COMMENT ON COLUMN specifications.spec_data IS 'Complete specification JSON from frontend';
COMMENT ON COLUMN layers.layer_data IS 'Layer-specific data: text content, image URL, shape properties';
COMMENT ON COLUMN layers.z_index IS 'Stacking order - higher values render on top';
COMMENT ON COLUMN rendered_images.expires_at IS 'When this cached render should be deleted';

-- =============================================================================
-- Schema Version
-- =============================================================================
CREATE TABLE IF NOT EXISTS schema_version (
    version VARCHAR(20) PRIMARY KEY,
    applied_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    description TEXT
);

INSERT INTO schema_version (version, description) VALUES 
('1.0.0', 'Initial Water Muse schema with projects, specs, layers, assets, and rendering')
ON CONFLICT (version) DO NOTHING;
