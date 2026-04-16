/**
 * Plugin processing result that will be sent back to DAM
 */
export interface PluginResult {
  // Tags extracted from the asset
  tags: string[];
  
  // Metadata in DAM-compatible format
  metadata: {
    [key: string]: any;
  };
  
  // Optional: Confidence scores for tags
  confidence?: {
    [tag: string]: number;
  };
  
  // Optional: Additional processing information
  processingInfo?: {
    processingTime: number;
    model?: string;
    version?: string;
    watermarkApplied?: boolean;
  };
  
  // Optional: Processed file (base64 encoded)
  processedFile?: string;
}

/**
 * Callback payload sent to DAM
 */
export interface CallbackPayload {
  status: 'success' | 'error';
  assetId?: string;
  result?: PluginResult;
  error?: {
    message: string;
    code?: string;
  };
  timestamp: string;
}
