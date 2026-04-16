import { inject } from '@loopback/core';
import { 
  post, 
  requestBody, 
  Response, 
  RestBindings,
  get,
  Request,
  operation
} from '@loopback/rest';
import { PluginService } from '../services/plugin.service';
import { getPluginRequestSpec } from '../models/request/plugin-req';

/**
 * Controller handling plugin API endpoints
 */
export class PluginController {
  constructor(
    @inject('services.PluginService')
    public pluginService: PluginService,
  ) {}

  /**
   * CORS preflight handler for /api/v1/process
   */
  @operation('options', '/api/v1/process', {
    responses: {
      '204': {
        description: 'CORS preflight response',
      },
    },
  })
  async processOptions(
    @inject(RestBindings.Http.REQUEST) request: Request,
    @inject(RestBindings.Http.RESPONSE) response: Response,
  ): Promise<void> {
    console.log('🔄 OPTIONS /api/v1/process - CORS preflight request');
    const origin = request.headers.origin || '*';
    response.set('Access-Control-Allow-Origin', origin);
    response.set('Access-Control-Allow-Credentials', 'true');
    response.set('Access-Control-Allow-Methods', 'GET, POST, PUT, PATCH, DELETE, OPTIONS');
    response.set('Access-Control-Allow-Headers', 'Content-Type, Authorization, Accept, X-Requested-With, X-CSRF-Token, Origin, Cookie');
    response.set('Access-Control-Max-Age', '86400');
    response.status(204).send();
  }

  /**
   * Health check endpoint
   */
  @get('/health', {
    responses: {
      '200': {
        description: 'Health check response',
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: {
                status: { type: 'string' },
                timestamp: { type: 'string' },
              },
            },
          },
        },
      },
    },
  })
  async health(): Promise<object> {
    console.log('💓 Health check requested');
    const health = {
      status: 'healthy',
      timestamp: new Date().toISOString(),
      service: 'DAM Plugin',
      version: '1.0.0',
    };
    console.log(`✅ Health check response:`, health);
    return health;
  }

  /**
   * Process asset endpoint - main plugin functionality
   */
  @post('/api/v1/process', {
    responses: {
      '200': {
        description: 'Asset processed successfully',
        content: {
          'application/json': {
            schema: {
              type: 'object',
              properties: {
                status: { type: 'string' },
                message: { type: 'string' },
                result: { type: 'object' },
              },
            },
          },
        },
      },
      '400': {
        description: 'Bad request',
      },
      '500': {
        description: 'Internal server error',
      },
    },
  })
  async processAsset(
    @inject(RestBindings.Http.REQUEST) httpRequest: Request,
    @inject(RestBindings.Http.RESPONSE) response: Response,
  ): Promise<object> {
    console.log('');
    console.log('='.repeat(80));
    console.log('🎯 [CONTROLLER] *** PLUGIN CALLED BY DAM ***');
    console.log('='.repeat(80));
    console.log('📥 [CONTROLLER] POST /api/v1/process - Request received');
    console.log('⏰ [CONTROLLER] Timestamp:', new Date().toISOString());
    console.log('📋 [CONTROLLER] Headers:', JSON.stringify(httpRequest.headers, null, 2));
    console.log('📋 [CONTROLLER] Content-Type:', httpRequest.headers['content-type']);
    console.log('📋 [CONTROLLER] Request body type:', typeof (httpRequest as any).body);
    console.log('📋 [CONTROLLER] Request keys:', Object.keys(httpRequest as any).filter(k => !k.startsWith('_')));
    
    // Log cookies from original request
    const cookies = httpRequest.headers.cookie || '';
    console.log('🍪 [CONTROLLER] *** COOKIES RECEIVED ***');
    console.log('🍪 [CONTROLLER] Cookie header:', cookies || '(none)');
    if (cookies) {
      const cookieArray = cookies.split(';').map(c => c.trim());
      console.log('🍪 [CONTROLLER] Cookie count:', cookieArray.length);
      console.log('🍪 [CONTROLLER] Cookies:', cookieArray);
    }
    console.log('🍪 [CONTROLLER] *** END COOKIES ***');
    
    try {
      // Get file from multipart form data - check multiple locations
      const file = (httpRequest as any).file || (httpRequest as any).files?.[0] || (httpRequest as any).body?.file;
      const body = (httpRequest as any).body || {};
      
      console.log(`📁 [CONTROLLER] File info:`, file ? {
        name: file.originalname || file.name,
        size: file.size,
        type: file.mimetype || file.type
      } : 'NO FILE');
      
      if (!file) {
        console.log('❌ [CONTROLLER] No file provided in request');
        console.log('📋 [CONTROLLER] Body keys:', Object.keys(body || {}));
        console.log('📋 [CONTROLLER] HttpRequest file:', (httpRequest as any).file);
        console.log('='.repeat(80));
        console.log('');
        response.status(400);
        return {
          status: 'error',
          message: 'No file provided',
        };
      }

      console.log(`📁 [CONTROLLER] File received: ${file.originalname || file.name}`);
      console.log(`📏 [CONTROLLER] File size: ${(file.size / 1024 / 1024).toFixed(2)} MB`);
      console.log(`📋 [CONTROLLER] File type: ${file.mimetype || file.type}`);

      const callbackUrl = body?.callBackURL;
      console.log(`📞 [CONTROLLER] Callback URL: ${callbackUrl || 'NOT PROVIDED'}`);
      
      const metadata = body?.metadata || {};
      console.log(`📊 [CONTROLLER] Metadata:`, JSON.stringify(metadata, null, 2));

      // Process the asset
      console.log(`🔄 [CONTROLLER] Starting asset processing...`);
      
      const result = await this.pluginService.processAsset(file.buffer, {
        filename: file.originalname || file.name,
        mimeType: file.mimetype || file.type,
        size: file.size,
      });
      
      console.log(`✅ [CONTROLLER] Asset processed successfully`);
      console.log(`📊 [CONTROLLER] Result:`, JSON.stringify(result, null, 2));

      // Send callback to DAM if URL provided
      if (callbackUrl) {
        console.log(`📤 [CONTROLLER] Sending callback to: ${callbackUrl}`);
        
        // Get processed file buffer if watermark was applied
        let processedFileBuffer: Buffer | undefined;
        if (result.processedFile) {
          console.log(`📁 [CONTROLLER] Converting base64 processed file to buffer...`);
          processedFileBuffer = Buffer.from(result.processedFile, 'base64');
          console.log(`📏 [CONTROLLER] Processed file buffer size: ${processedFileBuffer.length} bytes`);
        }
        
        await this.pluginService.sendCallback(
          callbackUrl, 
          result,
          processedFileBuffer,
          file.originalname || file.name,
          file.mimetype || file.type,
          cookies
        );
        console.log(`✅ [CONTROLLER] Callback sent successfully`);
      } else {
        console.log(`ℹ️  [CONTROLLER] No callback URL - skipping callback`);
      }

      console.log('='.repeat(80));
      console.log('');

      return {
        status: 'success',
        message: 'Asset processed successfully',
        result,
      };
    } catch (error: any) {
      console.error('❌ [CONTROLLER] ERROR in processAsset:', error.message);
      console.error('📚 [CONTROLLER] Stack trace:', error.stack);
      console.log('='.repeat(80));
      console.log('');
      response.status(500);
      return {
        status: 'error',
        message: error.message || 'Internal server error',
      };
    }
  }

  /**
   * Get plugin information
   */
  @get('/api/v1/info', {
    responses: {
      '200': {
        description: 'Plugin information',
        content: {
          'application/json': {
            schema: {
              type: 'object',
            },
          },
        },
      },
    },
  })
  async getInfo(): Promise<object> {
    console.log('📊 GET /api/v1/info - Plugin info requested');
    const info = {
      name: 'DAM Plugin Template',
      version: '1.0.0',
      apiVersion: 'v1',
      description: 'Template for building DAM plugins',
      endpoints: {
        health: '/health',
        process: '/api/v1/process',
        info: '/api/v1/info',
      },
      supportedFileTypes: [
        'image/jpeg',
        'image/png',
        'image/gif',
        'image/webp',
      ],
      maxFileSize: '100MB',
    };
    console.log(`✅ Plugin info:`, info);
    return info;
  }
}
