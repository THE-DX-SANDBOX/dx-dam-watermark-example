#!/bin/bash
# Script to update DAM ConfigMap with dam-demo-plugin in keywordStack

set -euo pipefail

NAMESPACE="${NAMESPACE:-default}"
CONFIGMAP="${CONFIGMAP:-${NAMESPACE}-digital-asset-management}"

# Create the new rendition config JSON
RENDITION_CONFIG='{
  "image/gif": {
    "rendition": [
      {
        "keywordStack": [
          {"operation": {"annotation": {}}, "plugin": "google-vision"},
          {"operation": {"process": {}}, "plugin": "dam-demo-plugin"}
        ],
        "name": "Original",
        "supplementalStack": [],
        "thumbnailStack": [],
        "transformationStack": []
      }
    ]
  },
  "image/jpeg": {
    "rendition": [
      {
        "keywordStack": [
          {"operation": {"annotation": {}}, "plugin": "google-vision"},
          {"operation": {"process": {}}, "plugin": "dam-demo-plugin"}
        ],
        "name": "Original",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": []
      },
      {
        "keywordStack": [],
        "name": "Desktop",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 1080, "width": 1920}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Tablet",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 768, "width": 1024}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Smartphone",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 760, "width": 360}}, "plugin": "image-processor"}]
      }
    ]
  },
  "image/png": {
    "rendition": [
      {
        "keywordStack": [
          {"operation": {"annotation": {}}, "plugin": "google-vision"},
          {"operation": {"process": {}}, "plugin": "dam-demo-plugin"}
        ],
        "name": "Original",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": []
      },
      {
        "keywordStack": [],
        "name": "Desktop",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 1080, "width": 1920}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Tablet",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 768, "width": 1024}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Smartphone",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 760, "width": 360}}, "plugin": "image-processor"}]
      }
    ]
  },
  "image/webp": {
    "rendition": [
      {
        "keywordStack": [
          {"operation": {"annotation": {}}, "plugin": "google-vision"},
          {"operation": {"process": {}}, "plugin": "dam-demo-plugin"}
        ],
        "name": "Original",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": []
      },
      {
        "keywordStack": [],
        "name": "Desktop",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 1080, "width": 1920}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Tablet",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 768, "width": 1024}}, "plugin": "image-processor"}]
      },
      {
        "keywordStack": [],
        "name": "Smartphone",
        "supplementalStack": [{"operation": {"metadata": {}}, "plugin": "image-processor"}],
        "thumbnailStack": [
          {"operation": {"crop": {"region": "CENTER"}}, "plugin": "image-processor"},
          {"operation": {"resize": {"height": 192, "width": 192}}, "plugin": "image-processor"}
        ],
        "transformationStack": [{"operation": {"resize": {"height": 760, "width": 360}}, "plugin": "image-processor"}]
      }
    ]
  },
  "image/svg+xml": {
    "rendition": [{"keywordStack": [], "name": "Original", "supplementalStack": [], "thumbnailStack": [], "transformationStack": []}]
  },
  "image/tiff": {
    "rendition": [{"keywordStack": [], "name": "Original", "supplementalStack": [], "thumbnailStack": [], "transformationStack": []}]
  },
  "video/mp4": {
    "rendition": [{
      "keywordStack": [],
      "name": "Original",
      "supplementalStack": [{"operation": {"status": {"entryId": ""}}, "plugin": "kaltura-plugin"}],
      "thumbnailStack": [{"operation": {"resize": {"entryId": "", "height": 192, "width": 192}}, "plugin": "kaltura-plugin"}],
      "transformationStack": [{"operation": {"upload": {"mediaId": ""}}, "plugin": "kaltura-plugin"}]
    }]
  },
  "video/ogg": {
    "rendition": [{
      "keywordStack": [],
      "name": "Original",
      "supplementalStack": [{"operation": {"status": {"entryId": ""}}, "plugin": "kaltura-plugin"}],
      "thumbnailStack": [{"operation": {"resize": {"entryId": "", "height": 192, "width": 192}}, "plugin": "kaltura-plugin"}],
      "transformationStack": [{"operation": {"upload": {"mediaId": ""}}, "plugin": "kaltura-plugin"}]
    }]
  },
  "video/webm": {
    "rendition": [{
      "keywordStack": [],
      "name": "Original",
      "supplementalStack": [{"operation": {"status": {"entryId": ""}}, "plugin": "kaltura-plugin"}],
      "thumbnailStack": [{"operation": {"resize": {"entryId": "", "height": 192, "width": 192}}, "plugin": "kaltura-plugin"}],
      "transformationStack": [{"operation": {"upload": {"mediaId": ""}}, "plugin": "kaltura-plugin"}]
    }]
  }
}'

echo "Updating rendition config..."
kubectl patch configmap $CONFIGMAP -n $NAMESPACE --type=merge -p "{\"data\":{\"dam.config.dam.extensibility_rendition_config.json\":$(echo "$RENDITION_CONFIG" | jq -c '.' | jq -Rs .)}}"

echo ""
echo "ConfigMap updated. Restart DAM to apply changes:"
echo "kubectl rollout restart statefulset/${CONFIGMAP} -n ${NAMESPACE}"
