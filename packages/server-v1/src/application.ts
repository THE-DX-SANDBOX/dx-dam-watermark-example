import { BootMixin } from '@loopback/boot';
import { ApplicationConfig } from '@loopback/core';
import { RepositoryMixin } from '@loopback/repository';
import { RestApplication, RestBindings } from '@loopback/rest';
import { RestExplorerBindings, RestExplorerComponent } from '@loopback/rest-explorer';
import { ServiceMixin } from '@loopback/service-proxy';
import path from 'path';
import { PluginSequence } from './sequence';
import { RenderingService, AssetStorageService, PluginService } from './services';
import multer from 'multer';
import cors from 'cors';

export { ApplicationConfig };

export class PluginApplication extends BootMixin(
  ServiceMixin(RepositoryMixin(RestApplication)),
) {
  constructor(options: ApplicationConfig = {}) {
    super(options);

    // Configure CORS with credentials support for preflight requests
    const corsOptions: cors.CorsOptions = {
      origin: true, // Reflect request origin
      credentials: true,
      methods: ['GET', 'POST', 'PUT', 'PATCH', 'DELETE', 'OPTIONS'],
      allowedHeaders: [
        'Content-Type',
        'Authorization',
        'Accept',
        'X-Requested-With',
        'X-CSRF-Token',
        'Origin',
        'Cookie',
      ],
      exposedHeaders: ['Set-Cookie'],
      maxAge: 86400, // 24 hours
      preflightContinue: false,
      optionsSuccessStatus: 204,
    };
    
    // Add CORS middleware
    this.expressMiddleware('middleware.cors', cors(corsOptions), {
      injectConfiguration: false,
      key: 'cors',
    });

    // Bind services
    this.bind('services.RenderingService').toClass(RenderingService);
    this.bind('services.AssetStorageService').toClass(AssetStorageService);
    this.bind('services.PluginService').toClass(PluginService);

    // Configure multer for multipart/form-data
    const upload = multer({ storage: multer.memoryStorage() });
    
    // Add multer middleware for file uploads
    this.expressMiddleware('middleware.multer', upload.any(), {
      injectConfiguration: false,
      key: 'multer',
    });

    // Bind the sequence class
    this.bind(RestBindings.SEQUENCE).toClass(PluginSequence);

    // Set up default home page
    this.static('/', path.join(__dirname, '../public'));

    // Customize @loopback/rest-explorer configuration
    this.configure(RestExplorerBindings.COMPONENT).to({
      path: '/explorer',
    });
    this.component(RestExplorerComponent);

    this.projectRoot = __dirname;
    
    // Customize Boot Conventions
    // Support both .js (compiled) and .ts (dev mode with ts-node-dev)
    this.bootOptions = {
      controllers: {
        dirs: ['controllers'],
        extensions: ['.controller.js', '.controller.ts'],
        nested: true,
      },
      repositories: {
        dirs: ['repositories'],
        extensions: ['.repository.js', '.repository.ts'],
        nested: true,
      },
      datasources: {
        dirs: ['datasources'],
        extensions: ['.datasource.js', '.datasource.ts'],
        nested: true,
      },
    };
  }
}
