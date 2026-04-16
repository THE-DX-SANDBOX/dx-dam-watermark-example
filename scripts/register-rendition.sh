#!/bin/bash
# =============================================================================
# DAM Rendition Registration Wizard
# =============================================================================
# This script queries the configmap, extracts existing plugins, and allows
# the user to interactively build plugin stacks for each media type.
# Output is saved to a local JSON file for manual application.
#
# Supports both interactive mode and non-interactive mode for AI automation.
#
# Usage:
#   Interactive:     ./register-rendition.sh
#   Non-interactive: ./register-rendition.sh --config config.json
#   List plugins:    ./register-rendition.sh --list-plugins
#   Export schema:   ./register-rendition.sh --export-schema
#   Dry run:         ./register-rendition.sh --config config.json --dry-run
# =============================================================================

set -euo pipefail

# =============================================================================
# ANSI Colors
# =============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# =============================================================================
# Configuration
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$PROJECT_ROOT/.env" ]]; then
    source "$PROJECT_ROOT/.env"
fi

NAMESPACE="${NAMESPACE:-default}"
CONFIGMAP_NAME="${CONFIGMAP_NAME:-}"

declare -a EXISTING_PLUGINS=()
declare -a MEDIA_TYPES=()
declare -a STACK_TYPES=("keywordStack" "supplementalStack" "thumbnailStack" "transformationStack")
CONFIGMAP_DATA=""
RENDITION_NAME=""
RENDITION_JSON=""
PLUGIN_CONFIG_JSON=""
RENDITION_CONFIG_JSON=""

# Non-interactive mode settings
CONFIG_FILE=""
DRY_RUN=false
QUIET=false
LIST_PLUGINS=false
EXPORT_SCHEMA=false

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    [[ "$QUIET" == "true" ]] && return
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_subheader() {
    [[ "$QUIET" == "true" ]] && return
    echo ""
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│ $1${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
}

print_success() {
    [[ "$QUIET" == "true" ]] && return
    echo -e "${GREEN}  ✓ $1${NC}"
}

print_warning() {
    [[ "$QUIET" == "true" ]] && return
    echo -e "${YELLOW}  ⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}  ✗ $1${NC}" >&2
}

print_info() {
    [[ "$QUIET" == "true" ]] && return
    echo -e "${BLUE}  ℹ $1${NC}"
}

prompt() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local var_name="$3"
    
    if [[ -n "$default_value" ]]; then
        echo -ne "  ${BOLD}$prompt_text${NC} [${GREEN}$default_value${NC}]: "
    else
        echo -ne "  ${BOLD}$prompt_text${NC}: "
    fi
    
    read -r input
    if [[ -z "$input" && -n "$default_value" ]]; then
        eval "$var_name='$default_value'"
    else
        eval "$var_name='$input'"
    fi
}

prompt_yes_no() {
    local prompt_text="$1"
    local default="${2:-Y}"
    
    if [[ "$default" == "Y" ]]; then
        echo -ne "  ${BOLD}$prompt_text${NC} [${GREEN}Y${NC}/n]: "
    else
        echo -ne "  ${BOLD}$prompt_text${NC} [y/${GREEN}N${NC}]: "
    fi
    
    read -r input
    input="${input:-$default}"
    
    # Convert to uppercase using tr for compatibility
    input=$(echo "$input" | tr '[:lower:]' '[:upper:]')
    [[ "$input" == "Y" ]]
}

# =============================================================================
# Parse Command Line Arguments
# =============================================================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            --list-plugins)
                LIST_PLUGINS=true
                shift
                ;;
            --export-schema)
                EXPORT_SCHEMA=true
                shift
                ;;
            -n|--namespace)
                NAMESPACE="$2"
                shift 2
                ;;
            -m|--configmap)
                CONFIGMAP_NAME="$2"
                shift 2
                ;;
            -h|--help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
}

show_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

DAM Rendition Registration Wizard - Interactive and non-interactive modes

OPTIONS:
  -c, --config FILE     Run in non-interactive mode with JSON config file
  --dry-run             Validate config without saving (use with --config)
  -q, --quiet           Suppress output except errors
  --list-plugins        List available plugins as JSON and exit
  --export-schema       Export JSON schema for config files and exit
  -n, --namespace NS    Kubernetes namespace (default: from .env or 'default')
  -m, --configmap NAME  ConfigMap name (default: auto-detect)
  -h, --help            Show this help message

EXAMPLES:
  # Interactive mode
  $(basename "$0")

  # Non-interactive with config file
  $(basename "$0") --config rendition-config.json

  # List available plugins
    $(basename "$0") --list-plugins --namespace <namespace>

  # Validate config without saving
  $(basename "$0") --config rendition-config.json --dry-run

CONFIG FILE FORMAT:
  {
    "name": "MyRendition",
    "mediaTypes": ["image/jpeg", "image/png"],
    "stacks": {
      "image/jpeg": {
        "keywordStack": [
          {"plugin": "plugin-name", "action": "actionName", "params": {}}
        ],
        "thumbnailStack": [],
        "supplementalStack": [],
        "transformationStack": []
      }
    }
  }
EOF
}

# =============================================================================
# JSON Schema Export
# =============================================================================

export_schema() {
    cat << 'EOF'
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "DAM Rendition Configuration",
  "type": "object",
  "required": ["name", "mediaTypes", "stacks"],
  "properties": {
    "name": {
      "type": "string",
      "description": "Name of the rendition configuration"
    },
    "mediaTypes": {
      "type": "array",
      "items": {
        "type": "string",
        "pattern": "^[a-z]+/[a-z0-9.+-]+$"
      },
      "description": "List of media types to configure"
    },
    "stacks": {
      "type": "object",
      "additionalProperties": {
        "type": "object",
        "properties": {
          "keywordStack": { "$ref": "#/definitions/stack" },
          "supplementalStack": { "$ref": "#/definitions/stack" },
          "thumbnailStack": { "$ref": "#/definitions/stack" },
          "transformationStack": { "$ref": "#/definitions/stack" }
        }
      }
    }
  },
  "definitions": {
    "stack": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["plugin", "action"],
        "properties": {
          "plugin": {
            "type": "string",
            "description": "Name of the plugin"
          },
          "action": {
            "type": "string",
            "description": "Action to perform"
          },
          "params": {
            "type": "object",
            "description": "Parameters for the action"
          }
        }
      }
    }
  }
}
EOF
}

# =============================================================================
# Silent/Non-Interactive ConfigMap Functions
# =============================================================================

query_configmap_silent() {
    if [[ -z "$CONFIGMAP_NAME" ]]; then
        local found_configmaps
        found_configmaps=$(kubectl get configmap -n "$NAMESPACE" -o name 2>/dev/null | grep -i "digital-asset-management" || true)
        
        if [[ -n "$found_configmaps" ]]; then
            CONFIGMAP_NAME=$(echo "$found_configmaps" | head -1 | sed 's|configmap/||')
        else
            CONFIGMAP_NAME="${NAMESPACE}-digital-asset-management"
        fi
    fi
    
    if ! kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "ConfigMap '$CONFIGMAP_NAME' not found in namespace '$NAMESPACE'"
        exit 1
    fi
    
    CONFIGMAP_DATA=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o json)
}

extract_plugins_silent() {
    PLUGIN_CONFIG_JSON=$(echo "$CONFIGMAP_DATA" | jq -r '.data["dam.config.dam.extensibility_plugin_config.json"] // empty')
    
    if [[ -z "$PLUGIN_CONFIG_JSON" || "$PLUGIN_CONFIG_JSON" == "null" ]]; then
        print_error "Could not find extensibility_plugin_config.json in ConfigMap"
        exit 1
    fi
    
    while IFS= read -r plugin; do
        [[ -n "$plugin" ]] && EXISTING_PLUGINS+=("$plugin")
    done < <(echo "$PLUGIN_CONFIG_JSON" | jq -r 'keys[]')
    
    RENDITION_CONFIG_JSON=$(echo "$CONFIGMAP_DATA" | jq -r '.data["dam.config.dam.extensibility_rendition_config.json"] // empty')
}

# =============================================================================
# List Plugins Command
# =============================================================================

list_plugins_json() {
    query_configmap_silent
    extract_plugins_silent
    
    local output="[]"
    
    for plugin in "${EXISTING_PLUGINS[@]}"; do
        local enabled
        enabled=$(echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin" '.[$p].enable // false')
        
        local actions
        actions=$(echo "$PLUGIN_CONFIG_JSON" | jq -c --arg p "$plugin" '.[$p].actions | keys' 2>/dev/null || echo "[]")
        
        output=$(echo "$output" | jq --arg name "$plugin" --argjson enabled "$enabled" --argjson actions "$actions" \
            '. + [{name: $name, enabled: $enabled, actions: $actions}]')
    done
    
    echo "$output" | jq '.'
}

# =============================================================================
# Non-Interactive Mode
# =============================================================================

run_non_interactive() {
    local config_file="$1"
    
    if [[ ! -f "$config_file" ]]; then
        print_error "Config file not found: $config_file"
        exit 1
    fi
    
    local config
    config=$(cat "$config_file")
    
    # Validate JSON
    if ! echo "$config" | jq empty 2>/dev/null; then
        print_error "Invalid JSON in config file"
        exit 1
    fi
    
    # Extract configuration
    RENDITION_NAME=$(echo "$config" | jq -r '.name // "Custom"')
    
    local media_types_json
    media_types_json=$(echo "$config" | jq -r '.mediaTypes // []')
    
    while IFS= read -r mt; do
        [[ -n "$mt" ]] && MEDIA_TYPES+=("$mt")
    done < <(echo "$media_types_json" | jq -r '.[]')
    
    if [[ ${#MEDIA_TYPES[@]} -eq 0 ]]; then
        print_error "No media types specified in config"
        exit 1
    fi
    
    # Query cluster state
    query_configmap_silent
    extract_plugins_silent
    
    # Validate plugins exist
    local stacks_config
    stacks_config=$(echo "$config" | jq -r '.stacks // {}')
    
    local validation_errors=()
    
    for media_type in "${MEDIA_TYPES[@]}"; do
        local mt_config
        mt_config=$(echo "$stacks_config" | jq --arg mt "$media_type" '.[$mt] // {}')
        
        for stack_type in "${STACK_TYPES[@]}"; do
            local stack
            stack=$(echo "$mt_config" | jq --arg st "$stack_type" '.[$st] // []')
            
            while IFS= read -r entry; do
                if [[ -n "$entry" && "$entry" != "null" ]]; then
                    local plugin_name
                    plugin_name=$(echo "$entry" | jq -r '.plugin')
                    local action_name
                    action_name=$(echo "$entry" | jq -r '.action')
                    
                    # Check plugin exists
                    local plugin_found=false
                    for p in "${EXISTING_PLUGINS[@]}"; do
                        if [[ "$p" == "$plugin_name" ]]; then
                            plugin_found=true
                            break
                        fi
                    done
                    
                    if [[ "$plugin_found" == "false" ]]; then
                        validation_errors+=("Plugin '$plugin_name' not found in cluster")
                    else
                        # Check action exists
                        local action_exists
                        action_exists=$(echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin_name" --arg a "$action_name" \
                            '.[$p].actions[$a] != null')
                        
                        if [[ "$action_exists" != "true" ]]; then
                            validation_errors+=("Action '$action_name' not found in plugin '$plugin_name'")
                        fi
                    fi
                fi
            done < <(echo "$stack" | jq -c '.[]?' 2>/dev/null)
        done
    done
    
    if [[ ${#validation_errors[@]} -gt 0 ]]; then
        print_error "Validation errors found:"
        for err in "${validation_errors[@]}"; do
            echo "  - $err" >&2
        done
        exit 1
    fi
    
    [[ "$QUIET" != "true" ]] && print_success "Configuration validated successfully"
    
    if [[ "$DRY_RUN" == "true" ]]; then
        echo '{"status": "valid", "message": "Configuration is valid"}' 
        return 0
    fi
    
    # Build the rendition JSON
    local rendition_updates="{}"
    
    for media_type in "${MEDIA_TYPES[@]}"; do
        local rendition_entry
        rendition_entry=$(jq -n --arg name "$RENDITION_NAME" '{name: $name}')
        
        local mt_config
        mt_config=$(echo "$stacks_config" | jq --arg mt "$media_type" '.[$mt] // {}')
        
        for stack_type in "${STACK_TYPES[@]}"; do
            local stack
            stack=$(echo "$mt_config" | jq --arg st "$stack_type" '.[$st] // []')
            
            # Convert from simplified format to DAM format
            local converted_stack="[]"
            
            while IFS= read -r entry; do
                if [[ -n "$entry" && "$entry" != "null" ]]; then
                    local plugin_name
                    plugin_name=$(echo "$entry" | jq -r '.plugin')
                    local action_name
                    action_name=$(echo "$entry" | jq -r '.action')
                    local params
                    params=$(echo "$entry" | jq '.params // {}')
                    
                    local stack_entry
                    stack_entry=$(jq -n \
                        --arg plugin "$plugin_name" \
                        --arg action "$action_name" \
                        --argjson params "$params" \
                        '{plugin: $plugin, operation: {($action): $params}}')
                    
                    converted_stack=$(echo "$converted_stack" | jq --argjson entry "$stack_entry" '. + [$entry]')
                fi
            done < <(echo "$stack" | jq -c '.[]?' 2>/dev/null)
            
            rendition_entry=$(echo "$rendition_entry" | jq --argjson stack "$converted_stack" --arg st "$stack_type" '. + {($st): $stack}')
        done
        
        rendition_updates=$(echo "$rendition_updates" | jq \
            --arg mt "$media_type" \
            --argjson entry "$rendition_entry" \
            '. + {($mt): {rendition: [.[$mt].rendition[]?, $entry]}}')
    done
    
    RENDITION_JSON="$rendition_updates"
    
    # Save to file
    save_to_file
}

# =============================================================================
# Check Prerequisites
# =============================================================================

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local missing_deps=()
    
    if ! command -v kubectl &> /dev/null; then
        missing_deps+=("kubectl")
    else
        print_success "kubectl found"
    fi
    
    if ! command -v jq &> /dev/null; then
        missing_deps+=("jq")
    else
        print_success "jq found"
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        exit 1
    fi
    
    if kubectl cluster-info &> /dev/null; then
        print_success "Kubernetes cluster is reachable"
    else
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
}

# =============================================================================
# Query ConfigMap
# =============================================================================

query_configmap() {
    print_header "Querying ConfigMap"
    
    prompt "Kubernetes Namespace" "$NAMESPACE" NAMESPACE
    
    local default_configmap=""
    if [[ -z "$CONFIGMAP_NAME" ]]; then
        print_info "Searching for digital-asset-management configmaps..."
        local found_configmaps
        found_configmaps=$(kubectl get configmap -n "$NAMESPACE" -o name 2>/dev/null | grep -i "digital-asset-management" || true)
        
        if [[ -n "$found_configmaps" ]]; then
            default_configmap=$(echo "$found_configmaps" | head -1 | sed 's|configmap/||')
            print_success "Found: $default_configmap"
        else
            default_configmap="${NAMESPACE}-digital-asset-management"
        fi
    else
        default_configmap="$CONFIGMAP_NAME"
    fi
    
    prompt "ConfigMap Name" "$default_configmap" CONFIGMAP_NAME
    
    print_info "Fetching ConfigMap..."
    
    if ! kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" &> /dev/null; then
        print_error "ConfigMap not found"
        exit 1
    fi
    
    CONFIGMAP_DATA=$(kubectl get configmap "$CONFIGMAP_NAME" -n "$NAMESPACE" -o json)
    print_success "ConfigMap retrieved successfully"
}

# =============================================================================
# Extract Plugins from ConfigMap
# =============================================================================

extract_plugins() {
    print_header "Extracting Available Plugins"
    
    PLUGIN_CONFIG_JSON=$(echo "$CONFIGMAP_DATA" | jq -r '.data["dam.config.dam.extensibility_plugin_config.json"] // empty')
    
    if [[ -z "$PLUGIN_CONFIG_JSON" || "$PLUGIN_CONFIG_JSON" == "null" ]]; then
        print_error "Could not find extensibility_plugin_config.json in ConfigMap"
        exit 1
    fi
    
    while IFS= read -r plugin; do
        [[ -n "$plugin" ]] && EXISTING_PLUGINS+=("$plugin")
    done < <(echo "$PLUGIN_CONFIG_JSON" | jq -r 'keys[]')
    
    if [[ ${#EXISTING_PLUGINS[@]} -eq 0 ]]; then
        print_error "No plugins found in ConfigMap"
        exit 1
    fi
    
    echo ""
    echo -e "  ${BOLD}Available Plugins:${NC}"
    for i in "${!EXISTING_PLUGINS[@]}"; do
        local plugin="${EXISTING_PLUGINS[$i]}"
        local enabled
        enabled=$(echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin" '.[$p].enable // false')
        local status_color="$GREEN"
        [[ "$enabled" != "true" ]] && status_color="$YELLOW"
        echo -e "    ${CYAN}$((i+1)).${NC} $plugin ${status_color}(enabled: $enabled)${NC}"
        
        local actions
        actions=$(echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin" '.[$p].actions | keys | join(", ")' 2>/dev/null || echo "")
        if [[ -n "$actions" ]]; then
            echo -e "       ${BLUE}Actions:${NC} $actions"
        fi
    done
    
    RENDITION_CONFIG_JSON=$(echo "$CONFIGMAP_DATA" | jq -r '.data["dam.config.dam.extensibility_rendition_config.json"] // empty')
    
    if [[ -n "$RENDITION_CONFIG_JSON" && "$RENDITION_CONFIG_JSON" != "null" ]]; then
        echo ""
        echo -e "  ${BOLD}Existing Media Types with Renditions:${NC}"
        while IFS= read -r media_type; do
            if [[ -n "$media_type" ]]; then
                local rendition_count
                rendition_count=$(echo "$RENDITION_CONFIG_JSON" | jq -r --arg mt "$media_type" '.[$mt].rendition | length')
                echo -e "    ${YELLOW}•${NC} $media_type ($rendition_count renditions)"
            fi
        done < <(echo "$RENDITION_CONFIG_JSON" | jq -r 'keys[]')
    fi
}

# =============================================================================
# Select Media Types
# =============================================================================

select_media_types() {
    print_header "Select Media Types"
    
    echo ""
    echo -e "  ${BOLD}Common Media Types:${NC}"
    echo -e "    ${CYAN}1.${NC} image/jpeg"
    echo -e "    ${CYAN}2.${NC} image/png"
    echo -e "    ${CYAN}3.${NC} image/gif"
    echo -e "    ${CYAN}4.${NC} image/webp"
    echo -e "    ${CYAN}5.${NC} image/svg+xml"
    echo -e "    ${CYAN}6.${NC} image/tiff"
    echo -e "    ${CYAN}7.${NC} video/mp4"
    echo -e "    ${CYAN}8.${NC} video/webm"
    echo -e "    ${CYAN}9.${NC} video/ogg"
    echo -e "    ${CYAN}10.${NC} All image types (1-6)"
    echo -e "    ${CYAN}11.${NC} All video types (7-9)"
    echo -e "    ${CYAN}12.${NC} Custom (enter manually)"
    echo ""
    
    echo -ne "  ${BOLD}Select media types (comma-separated, e.g., 1,2,3)${NC}: "
    read -r selection
    
    MEDIA_TYPES=()
    
    if [[ -z "$selection" ]]; then
        print_error "No selection made"
        return 1
    fi
    
    local -a selections=()
    IFS=',' read -ra selections <<< "$selection"
    
    for sel in "${selections[@]:-}"; do
        [[ -z "$sel" ]] && continue
        sel=$(echo "$sel" | xargs)
        case "$sel" in
            1) MEDIA_TYPES+=("image/jpeg") ;;
            2) MEDIA_TYPES+=("image/png") ;;
            3) MEDIA_TYPES+=("image/gif") ;;
            4) MEDIA_TYPES+=("image/webp") ;;
            5) MEDIA_TYPES+=("image/svg+xml") ;;
            6) MEDIA_TYPES+=("image/tiff") ;;
            7) MEDIA_TYPES+=("video/mp4") ;;
            8) MEDIA_TYPES+=("video/webm") ;;
            9) MEDIA_TYPES+=("video/ogg") ;;
            10) MEDIA_TYPES+=("image/jpeg" "image/png" "image/gif" "image/webp" "image/svg+xml" "image/tiff") ;;
            11) MEDIA_TYPES+=("video/mp4" "video/webm" "video/ogg") ;;
            12)
                echo -ne "  ${BOLD}Enter media type (e.g., application/pdf)${NC}: "
                read -r custom_type
                [[ -n "$custom_type" ]] && MEDIA_TYPES+=("$custom_type")
                ;;
        esac
    done
    
    if [[ ${#MEDIA_TYPES[@]} -gt 0 ]]; then
        MEDIA_TYPES=($(printf "%s\n" "${MEDIA_TYPES[@]}" | sort -u))
    fi
    
    echo ""
    echo -e "  ${BOLD}Selected Media Types:${NC}"
    for mt in "${MEDIA_TYPES[@]}"; do
        echo -e "    ${GREEN}•${NC} $mt"
    done
}

# =============================================================================
# Get Plugin Actions
# =============================================================================

get_plugin_actions() {
    local plugin="$1"
    echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin" '.[$p].actions | keys[]' 2>/dev/null || true
}

# =============================================================================
# Build Stack for Media Type
# =============================================================================

build_stack_for_media_type() {
    local media_type="$1"
    local stack_type="$2"
    local -a stack=()
    
    echo "" >&2
    echo -e "  ${BOLD}Building ${CYAN}$stack_type${NC}${BOLD} for ${YELLOW}$media_type${NC}" >&2
    echo -e "  ${BLUE}(Select plugins in execution order, 0 when done)${NC}" >&2
    echo "" >&2
    
    local position=1
    
    while true; do
        echo -e "  ${BOLD}Position $position:${NC}" >&2
        
        local idx=1
        for plugin in "${EXISTING_PLUGINS[@]}"; do
            local enabled
            enabled=$(echo "$PLUGIN_CONFIG_JSON" | jq -r --arg p "$plugin" '.[$p].enable // false')
            local status=""
            [[ "$enabled" != "true" ]] && status=" ${YELLOW}(disabled)${NC}"
            echo -e "    ${CYAN}$idx.${NC} $plugin$status" >&2
            ((idx++))
        done
        echo -e "    ${YELLOW}0.${NC} (done with this stack)" >&2
        echo "" >&2
        
        echo -ne "  ${BOLD}Select plugin [0-$((idx-1))]${NC}: " >&2
        read -r selection
        
        if [[ -z "$selection" || "$selection" == "0" ]]; then
            break
        fi
        
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [[ "$selection" -lt 1 ]] || [[ "$selection" -gt ${#EXISTING_PLUGINS[@]} ]]; then
            echo -e "${RED}  ✗ Invalid selection${NC}" >&2
            continue
        fi
        
        local selected_plugin="${EXISTING_PLUGINS[$((selection-1))]}"
        
        local actions
        actions=$(get_plugin_actions "$selected_plugin")
        
        if [[ -z "$actions" ]]; then
            echo -e "${YELLOW}  ⚠ No actions found for $selected_plugin${NC}" >&2
            continue
        fi
        
        echo "" >&2
        echo -e "  ${BOLD}Select action for $selected_plugin:${NC}" >&2
        
        local action_idx=1
        local -a action_array=()
        while IFS= read -r action; do
            if [[ -n "$action" ]]; then
                echo -e "    ${CYAN}$action_idx.${NC} $action" >&2
                action_array+=("$action")
                ((action_idx++))
            fi
        done <<< "$actions"
        
        echo "" >&2
        echo -ne "  ${BOLD}Select action [1-$((action_idx-1))]${NC}: " >&2
        read -r action_selection
        
        if ! [[ "$action_selection" =~ ^[0-9]+$ ]] || [[ "$action_selection" -lt 1 ]] || [[ "$action_selection" -gt ${#action_array[@]} ]]; then
            echo -e "${RED}  ✗ Invalid action selection${NC}" >&2
            continue
        fi
        
        local selected_action="${action_array[$((action_selection-1))]}"
        
        echo "" >&2
        echo -ne "  ${BOLD}Enter parameters as JSON (or Enter for {})${NC}: " >&2
        read -r params
        
        if [[ -z "$params" ]]; then
            params="{}"
        fi
        
        if ! echo "$params" | jq empty 2>/dev/null; then
            echo -e "${YELLOW}  ⚠ Invalid JSON, using empty object${NC}" >&2
            params="{}"
        fi
        
        local stack_entry
        stack_entry=$(jq -n \
            --arg plugin "$selected_plugin" \
            --arg action "$selected_action" \
            --argjson params "$params" \
            '{plugin: $plugin, operation: {($action): $params}}')
        
        stack+=("$stack_entry")
        
        echo -e "${GREEN}  ✓ Added: $selected_plugin -> $selected_action${NC}" >&2
        ((position++))
        echo "" >&2
    done
    
    # Only this output goes to stdout (captured by the caller)
    if [[ ${#stack[@]} -eq 0 ]]; then
        echo "[]"
    else
        printf '%s\n' "${stack[@]}" | jq -s '.'
    fi
}

# =============================================================================
# Create Rendition Configuration
# =============================================================================

create_rendition_config() {
    print_header "Rendition Configuration"
    
    prompt "Rendition Name" "Custom" RENDITION_NAME
    
    select_media_types
    
    if [[ ${#MEDIA_TYPES[@]} -eq 0 ]]; then
        print_error "No media types selected"
        exit 1
    fi
    
    local rendition_updates="{}"
    
    for media_type in "${MEDIA_TYPES[@]}"; do
        print_subheader "Configuring: $media_type"
        
        local rendition_entry
        rendition_entry=$(jq -n --arg name "$RENDITION_NAME" '{name: $name}')
        
        for stack_type in "${STACK_TYPES[@]}"; do
            echo ""
            if prompt_yes_no "Configure $stack_type for $media_type?" "Y"; then
                local stack_json
                stack_json=$(build_stack_for_media_type "$media_type" "$stack_type")
                rendition_entry=$(echo "$rendition_entry" | jq --argjson stack "$stack_json" --arg st "$stack_type" '. + {($st): $stack}')
            else
                rendition_entry=$(echo "$rendition_entry" | jq --arg st "$stack_type" '. + {($st): []}')
            fi
        done
        
        rendition_updates=$(echo "$rendition_updates" | jq \
            --arg mt "$media_type" \
            --argjson entry "$rendition_entry" \
            '. + {($mt): {rendition: [.[$mt].rendition[]?, $entry]}}')
    done
    
    RENDITION_JSON="$rendition_updates"
}

# =============================================================================
# Save Configuration to File
# =============================================================================

save_to_file() {
    print_header "Saving Configuration"
    
    local output_dir="$PROJECT_ROOT/config/renditions"
    mkdir -p "$output_dir"
    
    local timestamp
    timestamp=$(date +%Y%m%d-%H%M%S)
    local safe_name
    safe_name=$(echo "$RENDITION_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]/-/g')
    local output_file="$output_dir/${safe_name}-${timestamp}.json"
    
    local output
    output=$(jq -n \
        --arg name "$RENDITION_NAME" \
        --arg namespace "$NAMESPACE" \
        --arg configmap "$CONFIGMAP_NAME" \
        --arg created "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        --argjson renditions "$RENDITION_JSON" \
        '{
            metadata: {
                name: $name,
                namespace: $namespace,
                configmap: $configmap,
                createdAt: $created
            },
            renditionConfig: $renditions
        }')
    
    echo "$output" | jq '.' > "$output_file"
    print_success "Saved to: $output_file"
    
    local patch_file="$output_dir/${safe_name}-${timestamp}-patch.json"
    
    local merged_config
    if [[ -n "$RENDITION_CONFIG_JSON" && "$RENDITION_CONFIG_JSON" != "null" ]]; then
        merged_config=$(echo "$RENDITION_CONFIG_JSON" | jq --argjson new "$RENDITION_JSON" '
            . as $existing |
            $new | to_entries | reduce .[] as $entry ($existing;
                .[$entry.key].rendition = (.[$entry.key].rendition // []) + $entry.value.rendition
            )
        ')
    else
        merged_config="$RENDITION_JSON"
    fi
    
    local escaped_config
    escaped_config=$(echo "$merged_config" | jq -c '.')
    
    echo "{\"data\":{\"dam.config.dam.extensibility_rendition_config.json\":$(echo "$escaped_config" | jq -Rs '.')}}" | jq '.' > "$patch_file"
    
    print_success "Patch file: $patch_file"
    
    echo ""
    echo -e "  ${BOLD}To apply this configuration:${NC}"
    echo ""
    echo -e "    ${CYAN}kubectl patch configmap $CONFIGMAP_NAME -n $NAMESPACE --type=merge -p \"\$(cat $patch_file)\"${NC}"
    echo ""
    echo -e "  ${BOLD}Then restart the DAM service:${NC}"
    echo ""
    echo -e "    ${CYAN}kubectl rollout restart deployment/${NAMESPACE}-digital-asset-management -n $NAMESPACE${NC}"
    echo ""
}

# =============================================================================
# Summary
# =============================================================================

print_summary() {
    print_header "Registration Complete"
    
    echo ""
    echo -e "  ${BOLD}Rendition:${NC} $RENDITION_NAME"
    echo ""
    echo -e "  ${BOLD}Media Types Configured:${NC}"
    for mt in "${MEDIA_TYPES[@]}"; do
        echo -e "    ${GREEN}•${NC} $mt"
    done
    echo ""
    
    echo -e "  ${BOLD}Generated Configuration:${NC}"
    echo ""
    echo "$RENDITION_JSON" | jq '.'
}

# =============================================================================
# Main
# =============================================================================

main() {
    parse_args "$@"
    
    # Handle special commands first
    if [[ "$EXPORT_SCHEMA" == "true" ]]; then
        export_schema
        exit 0
    fi
    
    if [[ "$LIST_PLUGINS" == "true" ]]; then
        list_plugins_json
        exit 0
    fi
    
    # Non-interactive mode
    if [[ -n "$CONFIG_FILE" ]]; then
        run_non_interactive "$CONFIG_FILE"
        exit 0
    fi
    
    # Interactive mode
    echo ""
    echo -e "${BOLD}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}║           DAM Rendition Registration Wizard                   ║${NC}"
    echo -e "${BOLD}╚═══════════════════════════════════════════════════════════════╝${NC}"
    
    check_prerequisites
    query_configmap
    extract_plugins
    create_rendition_config
    save_to_file
    print_summary
}

main "$@"
