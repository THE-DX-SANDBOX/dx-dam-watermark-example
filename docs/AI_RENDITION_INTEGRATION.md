# AI-Driven DAM Rendition Configuration

This document describes how an AI assistant can use the DAM rendition registration tools to configure rendition processing pipelines based on user requests.

## Overview

The DAM Rendition Registration system allows configuration of processing stacks for different media types. Each media type can have four types of processing stacks:

| Stack Type | Purpose |
|-----------|---------|
| `keywordStack` | Extract/generate keywords from assets |
| `supplementalStack` | Generate supplemental data (metadata, etc.) |
| `thumbnailStack` | Generate thumbnail images |
| `transformationStack` | Transform assets (watermarks, conversions, etc.) |

## Tools Available

### 1. AI Helper (`scripts/ai-rendition-helper.sh`)

The AI helper provides JSON-based interfaces for programmatic access:

```bash
# Get capabilities and available commands
./scripts/ai-rendition-helper.sh capabilities

# Get current cluster state (plugins, actions, existing renditions)
./scripts/ai-rendition-helper.sh state <Namespace>

# Get JSON schema for config files
./scripts/ai-rendition-helper.sh schema

# Generate a configuration template
./scripts/ai-rendition-helper.sh template "MyRendition" "image/jpeg,image/png"

# Validate a configuration
./scripts/ai-rendition-helper.sh validate config.json

# Create the rendition
./scripts/ai-rendition-helper.sh create config.json

# Show example configurations
./scripts/ai-rendition-helper.sh examples
```

### 2. Registration Script (`scripts/register-rendition.sh`)

The main registration script supports both interactive and non-interactive modes:

```bash
# Interactive mode
./scripts/register-rendition.sh

# Non-interactive with config file
./scripts/register-rendition.sh --config config.json

# List available plugins as JSON
./scripts/register-rendition.sh --list-plugins

# Dry-run validation
./scripts/register-rendition.sh --config config.json --dry-run
```

## Configuration File Format

```json
{
  "name": "RenditionName",
  "mediaTypes": ["image/jpeg", "image/png"],
  "stacks": {
    "image/jpeg": {
      "keywordStack": [
        {
          "plugin": "plugin-name",
          "action": "actionName",
          "params": {}
        }
      ],
      "supplementalStack": [],
      "thumbnailStack": [],
      "transformationStack": []
    }
  }
}
```

## AI Integration Workflow

### Step 1: Understand User Intent

Map user requests to configuration requirements:

| User Says | Configuration Needed |
|-----------|---------------------|
| "Add watermarks to images" | `transformationStack` with watermark action |
| "Generate keywords for uploads" | `keywordStack` with keyword generation action |
| "Create thumbnails" | `thumbnailStack` with thumbnail action |
| "Extract metadata" | `supplementalStack` with metadata action |

### Step 2: Query Cluster State

```bash
./scripts/ai-rendition-helper.sh state
```

Returns available plugins and their actions. Use this to:
- Validate requested plugins exist
- Discover available actions for each plugin
- See existing rendition configurations

### Step 3: Generate Configuration

Based on user requirements and available plugins:

```bash
# Generate template
./scripts/ai-rendition-helper.sh template "UserRendition" "image/jpeg"

# Or create config file directly with proper structure
```

### Step 4: Validate Configuration

```bash
./scripts/ai-rendition-helper.sh validate config.json
```

This checks:
- All referenced plugins exist in the cluster
- All referenced actions exist in the specified plugins
- JSON structure is valid

### Step 5: Create Rendition

```bash
./scripts/ai-rendition-helper.sh create config.json
```

This generates:
- A configuration file in `config/renditions/`
- A kubectl patch file for applying to the cluster

## Example: Watermark Configuration

User request: "I want to add watermarks to all uploaded JPEG and PNG images"

1. **Query state** to find watermark plugin/action
2. **Generate config**:

```json
{
  "name": "WatermarkAll",
  "mediaTypes": ["image/jpeg", "image/png"],
  "stacks": {
    "image/jpeg": {
      "keywordStack": [],
      "supplementalStack": [],
      "thumbnailStack": [],
      "transformationStack": [
        {
          "plugin": "dam-plugin",
          "action": "applyWatermark",
          "params": {
            "watermarkId": "default"
          }
        }
      ]
    },
    "image/png": {
      "keywordStack": [],
      "supplementalStack": [],
      "thumbnailStack": [],
      "transformationStack": [
        {
          "plugin": "dam-plugin",
          "action": "applyWatermark",
          "params": {
            "watermarkId": "default"
          }
        }
      ]
    }
  }
}
```

3. **Validate and create** the configuration

## Constraints

The tool enforces these constraints that the AI must respect:

1. **Plugin Existence**: Only plugins registered in the cluster can be used
2. **Action Validity**: Only actions defined for a plugin can be specified
3. **Media Type Format**: Must be valid MIME types (e.g., `image/jpeg`)
4. **Stack Types**: Only the four defined stack types are valid
5. **Execution Order**: Plugins in a stack execute in array order

## Error Handling

The tools return JSON errors that can be parsed:

```json
{
  "status": "error",
  "message": "Plugin 'unknown-plugin' not found in cluster"
}
```

Always validate configurations before attempting to create them.
