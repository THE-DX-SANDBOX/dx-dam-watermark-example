import { PluginApplication } from '../src/application';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Generate OpenAPI specification from application
 */
async function generateSpec() {
  const app = new PluginApplication({
    rest: {
      port: 3000,
      host: 'localhost',
    },
  });

  await app.boot();

  const spec = await app.restServer.getApiSpec();

  // Customize spec
  spec.info = {
    ...spec.info,
    title: 'DAM Plugin API',
    version: '1.0.0',
    description: 'API for DAM Plugin Template',
  };

  // Ensure directories exist
  const specsDir = path.join(__dirname, '../public/openapi');
  if (!fs.existsSync(specsDir)) {
    fs.mkdirSync(specsDir, { recursive: true });
  }

  // Write spec to file
  const specPath = path.join(specsDir, 'openapi.json');
  fs.writeFileSync(specPath, JSON.stringify(spec, null, 2), 'utf-8');

  console.log(`OpenAPI spec generated at: ${specPath}`);
}

generateSpec().catch((err) => {
  console.error('Failed to generate OpenAPI spec:', err);
  process.exit(1);
});
