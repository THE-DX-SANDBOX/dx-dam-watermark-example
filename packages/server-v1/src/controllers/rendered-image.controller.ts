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
} from '@loopback/rest';
import {RenderedImage} from '../models';
import {RenderedImageRepository} from '../repositories';

export class RenderedImageController {
  constructor(
    @repository(RenderedImageRepository)
    public renderedImageRepository: RenderedImageRepository,
  ) {}

  @post('/rendered-images')
  @response(200, {
    description: 'RenderedImage model instance',
    content: {'application/json': {schema: getModelSchemaRef(RenderedImage)}},
  })
  async create(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(RenderedImage, {
            title: 'NewRenderedImage',
            exclude: ['id'],
          }),
        },
      },
    })
    renderedImage: Omit<RenderedImage, 'id'>,
  ): Promise<RenderedImage> {
    return this.renderedImageRepository.create(renderedImage);
  }

  @get('/rendered-images/count')
  @response(200, {
    description: 'RenderedImage model count',
    content: {'application/json': {schema: CountSchema}},
  })
  async count(@param.where(RenderedImage) where?: Where<RenderedImage>): Promise<Count> {
    return this.renderedImageRepository.count(where);
  }

  @get('/rendered-images')
  @response(200, {
    description: 'Array of RenderedImage model instances',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(RenderedImage, {includeRelations: true}),
        },
      },
    },
  })
  async find(@param.filter(RenderedImage) filter?: Filter<RenderedImage>): Promise<RenderedImage[]> {
    return this.renderedImageRepository.find(filter);
  }

  @patch('/rendered-images')
  @response(200, {
    description: 'RenderedImage PATCH success count',
    content: {'application/json': {schema: CountSchema}},
  })
  async updateAll(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(RenderedImage, {partial: true}),
        },
      },
    })
    renderedImage: RenderedImage,
    @param.where(RenderedImage) where?: Where<RenderedImage>,
  ): Promise<Count> {
    return this.renderedImageRepository.updateAll(renderedImage, where);
  }

  @get('/rendered-images/{id}')
  @response(200, {
    description: 'RenderedImage model instance',
    content: {
      'application/json': {
        schema: getModelSchemaRef(RenderedImage, {includeRelations: true}),
      },
    },
  })
  async findById(
    @param.path.string('id') id: string,
    @param.filter(RenderedImage, {exclude: 'where'})
    filter?: FilterExcludingWhere<RenderedImage>,
  ): Promise<RenderedImage> {
    return this.renderedImageRepository.findById(id, filter);
  }

  @patch('/rendered-images/{id}')
  @response(204, {
    description: 'RenderedImage PATCH success',
  })
  async updateById(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(RenderedImage, {partial: true}),
        },
      },
    })
    renderedImage: RenderedImage,
  ): Promise<void> {
    await this.renderedImageRepository.updateById(id, renderedImage);
  }

  @put('/rendered-images/{id}')
  @response(204, {
    description: 'RenderedImage PUT success',
  })
  async replaceById(
    @param.path.string('id') id: string,
    @requestBody() renderedImage: RenderedImage,
  ): Promise<void> {
    await this.renderedImageRepository.replaceById(id, renderedImage);
  }

  @del('/rendered-images/{id}')
  @response(204, {
    description: 'RenderedImage DELETE success',
  })
  async deleteById(@param.path.string('id') id: string): Promise<void> {
    await this.renderedImageRepository.deleteById(id);
  }

  // Check cache
  @get('/rendered-images/check-cache')
  @response(200, {
    description: 'Check if cached render exists',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            found: {type: 'boolean'},
            image: getModelSchemaRef(RenderedImage),
          },
        },
      },
    },
  })
  async checkCache(
    @param.query.string('specId') specId: string,
    @param.query.string('format') format: string,
    @param.query.number('width') width: number,
    @param.query.number('height') height: number,
  ): Promise<{found: boolean; image?: RenderedImage}> {
    const cached = await this.renderedImageRepository.findCachedRender(
      specId,
      format,
      width,
      height,
    );

    return {
      found: !!cached,
      image: cached || undefined,
    };
  }

  // Cleanup expired
  @post('/rendered-images/cleanup')
  @response(200, {
    description: 'Cleanup expired renders',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            deleted: {type: 'number'},
          },
        },
      },
    },
  })
  async cleanup(): Promise<{deleted: number}> {
    const deleted = await this.renderedImageRepository.cleanupExpired();
    return {deleted};
  }

  // Get render stats
  @get('/rendered-images/stats')
  @response(200, {
    description: 'Rendering statistics',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            totalRenders: {type: 'number'},
            avgRenderTime: {type: 'number'},
            byFormat: {type: 'object'},
            byStatus: {type: 'object'},
            cacheHitRate: {type: 'number'},
          },
        },
      },
    },
  })
  async getStats(): Promise<any> {
    return this.renderedImageRepository.getRenderStats();
  }
}
