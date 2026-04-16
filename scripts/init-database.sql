-- DAM Demo Plugin Database Schema
-- Run this script to create all required tables
-- Uses lowercase column names (PostgreSQL standard, LoopBack default)

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    thumbnailurl TEXT,
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    createdby VARCHAR(255),
    status VARCHAR(50) DEFAULT 'draft',
    metadata JSONB
);

-- Specifications table
CREATE TABLE IF NOT EXISTS specifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    projectid UUID REFERENCES projects(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    version INTEGER DEFAULT 1,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    backgroundcolor VARCHAR(50) DEFAULT '#FFFFFF',
    tilingenabled BOOLEAN DEFAULT FALSE,
    tilingpattern VARCHAR(50),
    tilingconfig JSONB,
    specdata JSONB NOT NULL,
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Layers table
CREATE TABLE IF NOT EXISTS layers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    specid UUID REFERENCES specifications(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    zindex INTEGER NOT NULL,
    visible BOOLEAN DEFAULT TRUE,
    locked BOOLEAN DEFAULT FALSE,
    opacity DECIMAL(3,2) DEFAULT 1.0,
    x DECIMAL(10,2) DEFAULT 0,
    y DECIMAL(10,2) DEFAULT 0,
    width DECIMAL(10,2),
    height DECIMAL(10,2),
    rotation DECIMAL(10,2) DEFAULT 0,
    scalex DECIMAL(10,4) DEFAULT 1.0,
    scaley DECIMAL(10,4) DEFAULT 1.0,
    anchorx DECIMAL(5,2) DEFAULT 0.5,
    anchory DECIMAL(5,2) DEFAULT 0.5,
    blendmode VARCHAR(50) DEFAULT 'normal',
    cliptobounds BOOLEAN DEFAULT FALSE,
    parentlayerid UUID REFERENCES layers(id),
    layerdata JSONB,
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Assets table
CREATE TABLE IF NOT EXISTS assets (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    projectid UUID REFERENCES projects(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    type VARCHAR(50) NOT NULL,
    mimetype VARCHAR(100),
    storagepath TEXT NOT NULL,
    fileurl TEXT,
    filename VARCHAR(255),
    storageprovider VARCHAR(50) DEFAULT 'local',
    filesize BIGINT,
    width INTEGER,
    height INTEGER,
    metadata JSONB,
    tags TEXT[],
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updatedat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    createdby VARCHAR(255)
);

-- Rendered Images table
CREATE TABLE IF NOT EXISTS rendered_images (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    specid UUID REFERENCES specifications(id) ON DELETE CASCADE,
    format VARCHAR(10) NOT NULL,
    width INTEGER NOT NULL,
    height INTEGER NOT NULL,
    quality INTEGER,
    filepath TEXT NOT NULL,
    filesize BIGINT,
    fileurl TEXT,
    status VARCHAR(50) DEFAULT 'pending',
    errormessage TEXT,
    rendertimems INTEGER,
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    expiresat TIMESTAMP
);

-- Templates table
CREATE TABLE IF NOT EXISTS templates (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    templatespec JSONB NOT NULL,
    thumbnailurl TEXT,
    usecount INTEGER DEFAULT 0,
    tags TEXT[],
    createdat TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    createdby VARCHAR(255),
    ispublic BOOLEAN DEFAULT FALSE
);

-- Create indexes for better query performance
CREATE INDEX IF NOT EXISTS idx_specifications_project_id ON specifications(projectid);
CREATE INDEX IF NOT EXISTS idx_layers_spec_id ON layers(specid);
CREATE INDEX IF NOT EXISTS idx_layers_parent_layer_id ON layers(parentlayerid);
CREATE INDEX IF NOT EXISTS idx_assets_project_id ON assets(projectid);
CREATE INDEX IF NOT EXISTS idx_assets_type ON assets(type);
CREATE INDEX IF NOT EXISTS idx_rendered_images_spec_id ON rendered_images(specid);
CREATE INDEX IF NOT EXISTS idx_rendered_images_status ON rendered_images(status);
CREATE INDEX IF NOT EXISTS idx_templates_category ON templates(category);
CREATE INDEX IF NOT EXISTS idx_templates_is_public ON templates(ispublic);

SELECT 'Database schema created successfully!' as message;
