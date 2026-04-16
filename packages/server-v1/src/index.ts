import { ApplicationConfig, PluginApplication } from './application';

export * from './application';

export async function main(options: ApplicationConfig = {}) {
  console.log('='.repeat(80));
  console.log('🚀 STARTING DAM PLUGIN SERVER');
  console.log('='.repeat(80));
  console.log(`   Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`   Port: ${options.rest?.port || process.env.PORT || 3000}`);
  console.log(`   Host: ${options.rest?.host || process.env.HOST || '0.0.0.0'}`);
  console.log(`   Log Level: ${process.env.LOG_LEVEL || 'info'}`);
  console.log('='.repeat(80));
  
  const app = new PluginApplication(options);
  
  console.log('⚙️  Booting application...');
  await app.boot();
  console.log('✅ Application booted');
  
  console.log('▶️  Starting server...');
  await app.start();
  console.log('✅ Server started');

  const url = app.restServer.url;
  console.log('='.repeat(80));
  console.log('✅ DAM PLUGIN SERVER IS READY');
  console.log('='.repeat(80));
  console.log(`   Server URL: ${url}`);
  console.log(`   API Explorer: ${url}/explorer`);
  console.log(`   Health Check: ${url}/health`);
  console.log(`   Plugin Info: ${url}/api/v1/info`);
  console.log('='.repeat(80));
  console.log('📡 Waiting for incoming requests...');
  console.log('='.repeat(80));

  return app;
}

if (require.main === module) {
  // Load configuration from environment
  const basePath = process.env.API_BASE_PATH || '';
  
  const config: ApplicationConfig = {
    rest: {
      port: +(process.env.PORT ?? 3000),
      host: process.env.HOST || '0.0.0.0',
      basePath: basePath,  // Support path prefix for ingress passthrough
      gracePeriodForClose: 5000,
      openApiSpec: {
        setServersFromRequest: true,
      },
      cors: {
        origin: ['http://localhost:5173', 'http://127.0.0.1:5173'],
        credentials: true,
      },
      requestBodyParser: {
        json: { limit: '10mb' },
      },
    },
  };
  
  if (basePath) {
    console.log(`   API Base Path: ${basePath}`);
  }

  main(config).catch((err) => {
    console.error('Cannot start the application:', err);
    process.exit(1);
  });
}
