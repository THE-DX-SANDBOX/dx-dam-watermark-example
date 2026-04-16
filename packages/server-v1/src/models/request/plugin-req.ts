import { RequestBodyObject, SchemaObject } from '@loopback/openapi-v3';

/**
 * Request specification for plugin processing endpoint
 * 
 * Customize this to add additional parameters specific to your plugin
 */
export const getPluginRequestSpec = (): Partial<RequestBodyObject> => {
  const schema: SchemaObject = {
    type: 'object',
    required: ['file'],
    properties: {
      file: {
        type: 'string',
        format: 'binary',
        description: 'The asset file to process',
      },
      callBackURL: {
        type: 'string',
        format: 'uri',
        description: 'URL to send processing results back to DAM',
        example: 'https://your-dam-server.com/api/callback',
      },
      // Add custom parameters here
      options: {
        type: 'object',
        description: 'Optional processing parameters',
        properties: {
          // Example custom options
          quality: {
            type: 'string',
            enum: ['low', 'medium', 'high'],
            default: 'medium',
            description: 'Processing quality level',
          },
          maxTags: {
            type: 'integer',
            minimum: 1,
            maximum: 50,
            default: 10,
            description: 'Maximum number of tags to return',
          },
          language: {
            type: 'string',
            default: 'en',
            description: 'Language for tag labels',
          },
        },
      },
    },
  };

  return {
    description: 'Process an asset file and extract metadata',
    required: true,
    content: {
      'multipart/form-data': {
        schema,
      },
    },
  };
};

/**
 * TypeScript interface for plugin request
 */
export interface PluginRequest {
  file: Buffer;
  callBackURL: string;
  options?: {
    quality?: 'low' | 'medium' | 'high';
    maxTags?: number;
    language?: string;
    [key: string]: any;
  };
}
