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
import {Layer} from '../models';
import {LayerRepository} from '../repositories';

export class LayerController {
  constructor(
    @repository(LayerRepository)
    public layerRepository: LayerRepository,
  ) {}

  @post('/layers')
  @response(200, {
    description: 'Layer model instance',
    content: {'application/json': {schema: getModelSchemaRef(Layer)}},
  })
  async create(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Layer, {
            title: 'NewLayer',
            exclude: ['id'],
          }),
        },
      },
    })
    layer: Omit<Layer, 'id'>,
  ): Promise<Layer> {
    return this.layerRepository.create(layer);
  }

  @get('/layers/count')
  @response(200, {
    description: 'Layer model count',
    content: {'application/json': {schema: CountSchema}},
  })
  async count(@param.where(Layer) where?: Where<Layer>): Promise<Count> {
    return this.layerRepository.count(where);
  }

  @get('/layers')
  @response(200, {
    description: 'Array of Layer model instances',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Layer, {includeRelations: true}),
        },
      },
    },
  })
  async find(@param.filter(Layer) filter?: Filter<Layer>): Promise<Layer[]> {
    return this.layerRepository.find(filter);
  }

  @patch('/layers')
  @response(200, {
    description: 'Layer PATCH success count',
    content: {'application/json': {schema: CountSchema}},
  })
  async updateAll(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Layer, {partial: true}),
        },
      },
    })
    layer: Layer,
    @param.where(Layer) where?: Where<Layer>,
  ): Promise<Count> {
    return this.layerRepository.updateAll(layer, where);
  }

  @get('/layers/{id}')
  @response(200, {
    description: 'Layer model instance',
    content: {
      'application/json': {
        schema: getModelSchemaRef(Layer, {includeRelations: true}),
      },
    },
  })
  async findById(
    @param.path.string('id') id: string,
    @param.filter(Layer, {exclude: 'where'}) filter?: FilterExcludingWhere<Layer>,
  ): Promise<Layer> {
    return this.layerRepository.findById(id, filter);
  }

  @patch('/layers/{id}')
  @response(204, {
    description: 'Layer PATCH success',
  })
  async updateById(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Layer, {partial: true}),
        },
      },
    })
    layer: Layer,
  ): Promise<void> {
    await this.layerRepository.updateById(id, layer);
  }

  @put('/layers/{id}')
  @response(204, {
    description: 'Layer PUT success',
  })
  async replaceById(
    @param.path.string('id') id: string,
    @requestBody() layer: Layer,
  ): Promise<void> {
    await this.layerRepository.replaceById(id, layer);
  }

  @del('/layers/{id}')
  @response(204, {
    description: 'Layer DELETE success',
  })
  async deleteById(@param.path.string('id') id: string): Promise<void> {
    await this.layerRepository.deleteById(id);
  }

  // Custom: Reorder layers
  @post('/layers/reorder')
  @response(204, {
    description: 'Layers reordered successfully',
  })
  async reorderLayers(
    @requestBody({
      content: {
        'application/json': {
          schema: {
            type: 'object',
            required: ['specId', 'layerIds'],
            properties: {
              specId: {type: 'string'},
              layerIds: {
                type: 'array',
                items: {type: 'string'},
              },
            },
          },
        },
      },
    })
    body: {specId: string; layerIds: string[]},
  ): Promise<void> {
    await this.layerRepository.reorderLayers(body.specId, body.layerIds);
  }

  // Custom: Duplicate layer
  @post('/layers/{id}/duplicate')
  @response(200, {
    description: 'Duplicated layer',
    content: {'application/json': {schema: getModelSchemaRef(Layer)}},
  })
  async duplicate(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: {
            type: 'object',
            properties: {
              offsetX: {type: 'number'},
              offsetY: {type: 'number'},
            },
          },
        },
      },
    })
    options?: {offsetX?: number; offsetY?: number},
  ): Promise<Layer> {
    return this.layerRepository.duplicate(id, options);
  }

  // Custom: Move layer
  @patch('/layers/{id}/move')
  @response(204, {
    description: 'Layer moved successfully',
  })
  async move(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: {
            type: 'object',
            required: ['x', 'y'],
            properties: {
              x: {type: 'number'},
              y: {type: 'number'},
            },
          },
        },
      },
    })
    position: {x: number; y: number},
  ): Promise<void> {
    await this.layerRepository.updateById(id, {
      x: position.x,
      y: position.y,
    });
  }

  // Get layers by specification
  @get('/specifications/{specId}/layers')
  @response(200, {
    description: 'Layers for specification',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Layer),
        },
      },
    },
  })
  async findBySpecId(@param.path.string('specId') specId: string): Promise<Layer[]> {
    return this.layerRepository.findBySpecId(specId);
  }
}
