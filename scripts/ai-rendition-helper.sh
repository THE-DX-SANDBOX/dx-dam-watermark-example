#!/bin/bash
# =============================================================================
# AI Rendition Helper
# =============================================================================
# A wrapper around register-rendition.sh designed for AI agent integration.
# Provides JSON-based interfaces for programmatic access to DAM rendition
# configuration capabilities.
#
# Usage:
#   ./ai-rendition-helper.sh <command> [options]
#
# Commands:
#   capabilities  - Show tool capabilities as JSON
#   state         - Get current cluster state (plugins, media types)
#   schema        - Get JSON schema for configuration
#   validate      - Validate a configuration file
#   template      - Generate a configuration template
#   create        - Create rendition from configuration
#   examples      - Show example configurations
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REGISTER_SCRIPT="$SCRIPT_DIR/register-rendition.sh"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

NAMESPACE="${NAMESPACE:-default}"

# =============================================================================
# Commands
# =============================================================================

cmd_capabilities() {
    cat << 'EOF'
{
  "tool": "dam-rendition-helper",
  "version": "1.0.0",
  "description": "Configure DAM rendition processing stacks for media types",
  "commands": {
    "capabilities": {
      "description": "Show this capabilities document",
      "input": null,
      "output": "JSON capabilities document"
    },
    "state": {
      "description": "Get current cluster state including available plugins and their actions",
      "input": {"namespace": "optional, kubernetes namespace"},
      "output": "JSON with plugins array and mediaTypes array"
    },
    "schema": {
      "description": "Get JSON schema for rendition configuration files",
      "input": null,
      "output": "JSON Schema document"
    },
    "validate": {
      "description": "Validate a configuration file against cluster state",
      "input": {"file": "path to JSON config file"},
      "output": "JSON validation result"
    },
    "template": {
      "description": "Generate a configuration template",
      "input": {"name": "rendition name", "mediaTypes": "comma-separated list"},
      "output": "JSON configuration template"
    },
    "create": {
      "description": "Create rendition configuration from file",
      "input": {"file": "path to JSON config file"},
      "output": "JSON result with output file paths"
    },
    "examples": {
      "description": "Show example configurations",
      "input": null,
      "output": "JSON with example configurations"
    }
  },
  "stackTypes": ["keywordStack", "supplementalStack", "thumbnailStack", "transformationStack"],
  "commonMediaTypes": {
    "images": ["image/jpeg", "image/png", "image/gif", "image/webp", "image/svg+xml", "image/tiff"],
    "videos": ["video/mp4", "video/webm", "video/ogg"],
    "documents": ["application/pdf"]
  }
}
EOF
}

cmd_state() {
    local ns="${1:-$NAMESPACE}"
    
    # Get plugins
    local plugins
    plugins=$("$REGISTER_SCRIPT" --list-plugins --namespace "$ns" --quiet 2>/dev/null || echo "[]")
    
    # Get existing renditions (if configmap exists)
    local configmap_name
    configmap_name=$(kubectl get configmap -n "$ns" -o name 2>/dev/null | grep -i "digital-asset-management" | head -1 | sed 's|configmap/||' || echo "")
    
    local existing_renditions="{}"
    if [[ -n "$configmap_name" ]]; then
        local configmap_data
        configmap_data=$(kubectl get configmap "$configmap_name" -n "$ns" -o json 2>/dev/null || echo "{}")
        
        local rendition_config
        rendition_config=$(echo "$configmap_data" | jq -r '.data["dam.config.dam.extensibility_rendition_config.json"] // "{}"' 2>/dev/null || echo "{}")
        
        if [[ -n "$rendition_config" && "$rendition_config" != "null" ]]; then
            existing_renditions="$rendition_config"
        fi
    fi
    
    jq -n \
        --arg namespace "$ns" \
        --arg configmap "$configmap_name" \
        --argjson plugins "$plugins" \
        --argjson existingRenditions "$existing_renditions" \
        '{
            namespace: $namespace,
            configmap: $configmap,
            plugins: $plugins,
            existingRenditions: $existingRenditions
        }'
}

cmd_schema() {
    "$REGISTER_SCRIPT" --export-schema
}

cmd_validate() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        jq -n --arg file "$file" '{status: "error", message: "File not found", file: $file}'
        return 1
    fi
    
    local result
    if result=$("$REGISTER_SCRIPT" --config "$file" --dry-run --quiet 2>&1); then
        jq -n --arg file "$file" '{status: "valid", message: "Configuration is valid", file: $file}'
    else
        jq -n --arg file "$file" --arg error "$result" '{status: "invalid", message: $error, file: $file}'
        return 1
    fi
}

cmd_template() {
    local name="${1:-MyRendition}"
    local media_types="${2:-image/jpeg}"
    
    # Parse comma-separated media types
    local media_types_json="[]"
    IFS=',' read -ra mt_array <<< "$media_types"
    for mt in "${mt_array[@]}"; do
        mt=$(echo "$mt" | xargs)  # trim whitespace
        media_types_json=$(echo "$media_types_json" | jq --arg mt "$mt" '. + [$mt]')
    done
    
    # Build stacks template
    local stacks="{}"
    for mt in "${mt_array[@]}"; do
        mt=$(echo "$mt" | xargs)
        stacks=$(echo "$stacks" | jq --arg mt "$mt" '. + {($mt): {
            "keywordStack": [],
            "supplementalStack": [],
            "thumbnailStack": [],
            "transformationStack": []
        }}')
    done
    
    jq -n \
        --arg name "$name" \
        --argjson mediaTypes "$media_types_json" \
        --argjson stacks "$stacks" \
        '{
            name: $name,
            mediaTypes: $mediaTypes,
            stacks: $stacks
        }'
}

cmd_create() {
    local file="$1"
    
    if [[ ! -f "$file" ]]; then
        jq -n --arg file "$file" '{status: "error", message: "File not found", file: $file}'
        return 1
    fi
    
    local output
    if output=$("$REGISTER_SCRIPT" --config "$file" --quiet 2>&1); then
        # Parse output to find created files
        local config_file patch_file
        config_file=$(echo "$output" | grep -o 'Saved to: [^ ]*' | sed 's/Saved to: //' || echo "")
        patch_file=$(echo "$output" | grep -o 'Patch file: [^ ]*' | sed 's/Patch file: //' || echo "")
        
        jq -n \
            --arg configFile "$config_file" \
            --arg patchFile "$patch_file" \
            '{
                status: "success",
                message: "Rendition configuration created",
                files: {
                    config: $configFile,
                    patch: $patchFile
                }
            }'
    else
        jq -n --arg error "$output" '{status: "error", message: $error}'
        return 1
    fi
}

cmd_examples() {
    cat << 'EOF'
{
  "examples": [
    {
      "name": "Basic Image Watermarking",
      "description": "Apply watermark to JPEG and PNG images",
      "config": {
        "name": "WatermarkRendition",
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
                  "watermarkId": "default",
                  "position": "bottom-right",
                  "opacity": 0.8
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
                  "watermarkId": "default",
                  "position": "bottom-right",
                  "opacity": 0.8
                }
              }
            ]
          }
        }
      }
    },
    {
      "name": "AI Keyword Extraction",
      "description": "Use AI to generate keywords for images",
      "config": {
        "name": "AIKeywords",
        "mediaTypes": ["image/jpeg"],
        "stacks": {
          "image/jpeg": {
            "keywordStack": [
              {
                "plugin": "dam-plugin",
                "action": "generateKeywords",
                "params": {
                  "maxKeywords": 10,
                  "language": "en"
                }
              }
            ],
            "supplementalStack": [],
            "thumbnailStack": [],
            "transformationStack": []
          }
        }
      }
    },
    {
      "name": "Full Processing Pipeline",
      "description": "Complete pipeline with keywords, thumbnails, and watermarks",
      "config": {
        "name": "FullPipeline",
        "mediaTypes": ["image/jpeg"],
        "stacks": {
          "image/jpeg": {
            "keywordStack": [
              {
                "plugin": "dam-plugin",
                "action": "generateKeywords",
                "params": {}
              }
            ],
            "supplementalStack": [
              {
                "plugin": "dam-plugin",
                "action": "extractMetadata",
                "params": {}
              }
            ],
            "thumbnailStack": [
              {
                "plugin": "dam-plugin",
                "action": "generateThumbnail",
                "params": {
                  "width": 200,
                  "height": 200
                }
              }
            ],
            "transformationStack": [
              {
                "plugin": "dam-plugin",
                "action": "applyWatermark",
                "params": {
                  "watermarkId": "corporate"
                }
              }
            ]
          }
        }
      }
    }
  ]
}
EOF
}

# =============================================================================
# Main
# =============================================================================

show_help() {
    cat << EOF
AI Rendition Helper - Programmatic interface for DAM rendition configuration

Usage: $(basename "$0") <command> [options]

Commands:
  capabilities           Show tool capabilities as JSON
  state [namespace]      Get current cluster state
  schema                 Get JSON schema for configuration
  validate <file>        Validate a configuration file
  template <name> <types> Generate a configuration template
  create <file>          Create rendition from configuration
  examples               Show example configurations

Examples:
  $(basename "$0") capabilities
  $(basename "$0") state <namespace>
  $(basename "$0") template "MyRendition" "image/jpeg,image/png"
  $(basename "$0") validate config.json
  $(basename "$0") create config.json
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        show_help
        exit 1
    fi
    
    local command="$1"
    shift
    
    case "$command" in
        capabilities)
            cmd_capabilities
            ;;
        state)
            cmd_state "$@"
            ;;
        schema)
            cmd_schema
            ;;
        validate)
            if [[ $# -eq 0 ]]; then
                echo '{"status": "error", "message": "File path required"}' >&2
                exit 1
            fi
            cmd_validate "$1"
            ;;
        template)
            cmd_template "${1:-MyRendition}" "${2:-image/jpeg}"
            ;;
        create)
            if [[ $# -eq 0 ]]; then
                echo '{"status": "error", "message": "File path required"}' >&2
                exit 1
            fi
            cmd_create "$1"
            ;;
        examples)
            cmd_examples
            ;;
        help|-h|--help)
            show_help
            ;;
        *)
            echo "{\"status\": \"error\", \"message\": \"Unknown command: $command\"}" >&2
            exit 1
            ;;
    esac
}

main "$@"
