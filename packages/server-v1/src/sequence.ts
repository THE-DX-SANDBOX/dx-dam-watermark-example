import {
  FindRoute,
  InvokeMethod,
  ParseParams,
  Reject,
  RequestContext,
  Send,
  SequenceHandler,
} from '@loopback/rest';
import { inject } from '@loopback/core';

export class PluginSequence implements SequenceHandler {
  constructor(
    @inject('sequence.actions.findRoute') protected findRoute: FindRoute,
    @inject('sequence.actions.parseParams') protected parseParams: ParseParams,
    @inject('sequence.actions.invoke') protected invoke: InvokeMethod,
    @inject('sequence.actions.send') protected send: Send,
    @inject('sequence.actions.reject') protected reject: Reject,
  ) {}

  async handle(context: RequestContext): Promise<void> {
    try {
      const { request, response } = context;
      const startTime = Date.now();
      
      // Log incoming request with details
      console.log('='.repeat(80));
      console.log(`📥 INCOMING REQUEST: ${request.method} ${request.url}`);
      console.log(`   Timestamp: ${new Date().toISOString()}`);
      console.log(`   Headers:`, JSON.stringify(request.headers, null, 2));
      if (request.body && Object.keys(request.body).length > 0) {
        console.log(`   Body:`, JSON.stringify(request.body, null, 2));
      }
      console.log('='.repeat(80));
      
      // Add CORS headers
      // Use actual origin instead of * to support credentials
      const origin = request.headers.origin || '*';
      response.setHeader('Access-Control-Allow-Origin', origin);
      response.setHeader('Access-Control-Allow-Credentials', 'true');
      response.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
      response.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, X-API-Key');
      
      // Handle OPTIONS preflight
      if (request.method === 'OPTIONS') {
        console.log('✅ OPTIONS preflight - responding with 204');
        response.statusCode = 204;
        this.send(response, '');
        return;
      }

      console.log('🎯 Finding route...');
      const route = this.findRoute(request);
      console.log(`✅ Route found: ${route.verb} ${route.path}`);
      console.log(`   Operation: ${route.spec.operationId || 'unknown'}`);
      
      console.log('📝 Parsing parameters...');
      const args = await this.parseParams(request, route);
      console.log(`✅ Parameters parsed, invoking controller...`);
      
      const result = await this.invoke(route, args);
      
      const duration = Date.now() - startTime;
      console.log('='.repeat(80));
      console.log(`✅ REQUEST COMPLETED in ${duration}ms`);
      console.log(`   Response:`, JSON.stringify(result, null, 2));
      console.log('='.repeat(80));
      
      this.send(response, result);
    } catch (err) {
      const duration = Date.now() - (context as any).startTime;
      console.error('='.repeat(80));
      console.error(`❌ REQUEST FAILED`);
      console.error(`   Error: ${(err as Error).message}`);
      console.error(`   Stack:`, (err as Error).stack);
      console.error('='.repeat(80));
      this.reject(context, err as Error);
    }
  }
}
