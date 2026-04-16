import {
  Count,
  CountSchema,
  Filter,
  FilterExcludingWhere,
  repository,
  Where,
} from '@loopback/repository';
import {
  post,
  param,
  get,
  getModelSchemaRef,
  patch,
  put,
  del,
  requestBody,
  response,
  HttpErrors,
} from '@loopback/rest';
import {inject} from '@loopback/core';
import {Specification} from '../models';
import {SpecificationRepository, LayerRepository, RenderedImageRepository} from '../repositories';
import {RenderingService} from '../services';

export class SpecificationController {
  constructor(
    @repository(SpecificationRepository)
    public specificationRepository: SpecificationRepository,
    @repository(LayerRepository)
    public layerRepository: LayerRepository,
    @repository(RenderedImageRepository)
    public renderedImageRepository: RenderedImageRepository,
    @inject('services.RenderingService')
    public renderingService: RenderingService,
  ) {}

  @post('/specifications')
  @response(200, {
    description: 'Specification model instance',
    content: {'application/json': {schema: getModelSchemaRef(Specification)}},
  })
  async create(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Specification, {
            title: 'NewSpecification',
            exclude: ['id'],
          }),
        },
      },
    })
    specification: Omit<Specification, 'id'>,
  ): Promise<Specification> {
    return this.specificationRepository.create(specification);
  }

  @get('/specifications/count')
  @response(200, {
    description: 'Specification model count',
    content: {'application/json': {schema: CountSchema}},
  })
  async count(@param.where(Specification) where?: Where<Specification>): Promise<Count> {
    return this.specificationRepository.count(where);
  }

  @get('/specifications')
  @response(200, {
    description: 'Array of Specification model instances',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Specification, {includeRelations: true}),
        },
      },
    },
  })
  async find(@param.filter(Specification) filter?: Filter<Specification>): Promise<Specification[]> {
    return this.specificationRepository.find(filter);
  }

  @get('/specifications/active')
  @response(200, {
    description: 'Active specifications with details',
  })
  async findActive(): Promise<any[]> {
    return this.specificationRepository.findActiveWithDetails();
  }

  @patch('/specifications')
  @response(200, {
    description: 'Specification PATCH success count',
    content: {'application/json': {schema: CountSchema}},
  })
  async updateAll(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Specification, {partial: true}),
        },
      },
    })
    specification: Specification,
    @param.where(Specification) where?: Where<Specification>,
  ): Promise<Count> {
    return this.specificationRepository.updateAll(specification, where);
  }

  @get('/specifications/{id}')
  @response(200, {
    description: 'Specification model instance',
    content: {
      'application/json': {
        schema: getModelSchemaRef(Specification, {includeRelations: true}),
      },
    },
  })
  async findById(
    @param.path.string('id') id: string,
    @param.filter(Specification, {exclude: 'where'})
    filter?: FilterExcludingWhere<Specification>,
  ): Promise<Specification> {
    return this.specificationRepository.findById(id, filter);
  }

  @patch('/specifications/{id}')
  @response(204, {
    description: 'Specification PATCH success',
  })
  async updateById(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Specification, {partial: true}),
        },
      },
    })
    specification: Specification,
  ): Promise<void> {
    await this.specificationRepository.updateById(id, specification);
  }

  @put('/specifications/{id}')
  @response(204, {
    description: 'Specification PUT success',
  })
  async replaceById(
    @param.path.string('id') id: string,
    @requestBody() specification: Specification,
  ): Promise<void> {
    await this.specificationRepository.replaceById(id, specification);
  }

  @del('/specifications/{id}')
  @response(204, {
    description: 'Specification DELETE success',
  })
  async deleteById(@param.path.string('id') id: string): Promise<void> {
    await this.specificationRepository.deleteById(id);
  }

  // Version control
  @post('/specifications/{id}/version')
  @response(200, {
    description: 'Create new version of specification',
    content: {'application/json': {schema: getModelSchemaRef(Specification)}},
  })
  async createVersion(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Specification, {partial: true}),
        },
      },
    })
    updates: Partial<Specification>,
  ): Promise<Specification> {
    return this.specificationRepository.createVersion(id, updates);
  }

  // Layers
  @get('/specifications/{id}/layers')
  @response(200, {
    description: 'Array of Layers belonging to Specification',
  })
  async findLayers(
    @param.path.string('id') id: string,
    @param.query.object('filter') filter?: Filter,
  ): Promise<any[]> {
    return this.layerRepository.findBySpecId(id);
  }

  // Rendering
  @post('/specifications/{id}/render')
  @response(200, {
    description: 'Render specification to image',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            url: {type: 'string'},
            filePath: {type: 'string'},
            format: {type: 'string'},
            width: {type: 'number'},
            height: {type: 'number'},
            renderTimeMs: {type: 'number'},
          },
        },
      },
    },
  })
  async render(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: {
            type: 'object',
            properties: {
              format: {type: 'string', enum: ['png', 'jpg', 'webp', 'svg']},
              width: {type: 'number'},
              height: {type: 'number'},
              quality: {type: 'number'},
              useCache: {type: 'boolean'},
            },
          },
        },
      },
    })
    options: {
      format?: string;
      width?: number;
      height?: number;
      quality?: number;
      useCache?: boolean;
    },
  ): Promise<any> {
    const spec = await this.specificationRepository.findById(id, {
      include: [{relation: 'layers'}],
    });

    if (!spec) {
      throw new HttpErrors.NotFound('Specification not found');
    }

    const format: any = options.format || 'png';
    const width = options.width || spec.width;
    const height = options.height || spec.height;
    const quality: any = options.quality || 90;
    const useCache = options.useCache !== false;

    // Check cache
    if (useCache) {
      const cached = await this.renderedImageRepository.findCachedRender(
        id,
        format,
        width,
        height,
      );
      if (cached) {
        return {
          url: cached.fileUrl,
          filePath: cached.filePath,
          format: cached.format,
          width: cached.width,
          height: cached.height,
          renderTimeMs: cached.renderTimeMs,
          cached: true,
        };
      }
    }

    // Render
    const startTime = Date.now();
    const result = await this.renderingService.renderSpecification(spec, {
      format,
      width,
      height,
      quality,
    });
    const renderTimeMs = Date.now() - startTime;

    // Save to cache
    const renderedImage = await this.renderedImageRepository.create({
      specId: id,
      format,
      width,
      height,
      quality,
      filePath: result.filePath,
      fileUrl: result.url,
      fileSize: result.fileSize,
      status: 'completed',
      renderTimeMs,
      expiresAt: new Date(Date.now() + 24 * 60 * 60 * 1000), // 24 hours
    });

    return {
      ...result,
      renderTimeMs,
      cached: false,
    };
  }

  @get('/specifications/{id}/renders')
  @response(200, {
    description: 'Get all renders for a specification',
  })
  async getRenders(@param.path.string('id') id: string): Promise<any[]> {
    return this.renderedImageRepository.find({
      where: {specId: id},
      order: ['createdAt DESC'],
    });
  }
}
