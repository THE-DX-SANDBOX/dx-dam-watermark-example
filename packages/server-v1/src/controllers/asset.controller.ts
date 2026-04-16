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
  Request,
  RestBindings,
} from '@loopback/rest';
import {inject} from '@loopback/core';
import {Asset} from '../models';
import {AssetRepository} from '../repositories';
import {AssetStorageService} from '../services';

export class AssetController {
  constructor(
    @repository(AssetRepository)
    public assetRepository: AssetRepository,
    @inject('services.AssetStorageService')
    public assetStorageService: AssetStorageService,
  ) {}

  @post('/assets')
  @response(200, {
    description: 'Asset model instance',
    content: {'application/json': {schema: getModelSchemaRef(Asset)}},
  })
  async create(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Asset, {
            title: 'NewAsset',
            exclude: ['id'],
          }),
        },
      },
    })
    asset: Omit<Asset, 'id'>,
  ): Promise<Asset> {
    return this.assetRepository.create(asset);
  }

  @get('/assets/count')
  @response(200, {
    description: 'Asset model count',
    content: {'application/json': {schema: CountSchema}},
  })
  async count(@param.where(Asset) where?: Where<Asset>): Promise<Count> {
    return this.assetRepository.count(where);
  }

  @get('/assets')
  @response(200, {
    description: 'Array of Asset model instances',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Asset, {includeRelations: true}),
        },
      },
    },
  })
  async find(@param.filter(Asset) filter?: Filter<Asset>): Promise<Asset[]> {
    return this.assetRepository.find(filter);
  }

  @patch('/assets')
  @response(200, {
    description: 'Asset PATCH success count',
    content: {'application/json': {schema: CountSchema}},
  })
  async updateAll(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Asset, {partial: true}),
        },
      },
    })
    asset: Asset,
    @param.where(Asset) where?: Where<Asset>,
  ): Promise<Count> {
    return this.assetRepository.updateAll(asset, where);
  }

  @get('/assets/{id}')
  @response(200, {
    description: 'Asset model instance',
    content: {
      'application/json': {
        schema: getModelSchemaRef(Asset, {includeRelations: true}),
      },
    },
  })
  async findById(
    @param.path.string('id') id: string,
    @param.filter(Asset, {exclude: 'where'}) filter?: FilterExcludingWhere<Asset>,
  ): Promise<Asset> {
    return this.assetRepository.findById(id, filter);
  }

  @patch('/assets/{id}')
  @response(204, {
    description: 'Asset PATCH success',
  })
  async updateById(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Asset, {partial: true}),
        },
      },
    })
    asset: Asset,
  ): Promise<void> {
    await this.assetRepository.updateById(id, asset);
  }

  @put('/assets/{id}')
  @response(204, {
    description: 'Asset PUT success',
  })
  async replaceById(
    @param.path.string('id') id: string,
    @requestBody() asset: Asset,
  ): Promise<void> {
    await this.assetRepository.replaceById(id, asset);
  }

  @del('/assets/{id}')
  @response(204, {
    description: 'Asset DELETE success',
  })
  async deleteById(@param.path.string('id') id: string): Promise<void> {
    const asset = await this.assetRepository.findById(id);
    // Delete file from storage
    await this.assetStorageService.deleteFile(asset.storagePath);
    // Delete from database
    await this.assetRepository.deleteById(id);
  }

  // Upload asset
  @post('/assets/upload')
  @response(200, {
    description: 'Upload asset file',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            id: {type: 'string'},
            url: {type: 'string'},
            storagePath: {type: 'string'},
            fileName: {type: 'string'},
            fileSize: {type: 'number'},
            mimeType: {type: 'string'},
            width: {type: 'number'},
            height: {type: 'number'},
          },
        },
      },
    },
  })
  async upload(
    @requestBody({
      content: {
        'multipart/form-data': {
          schema: {
            type: 'object',
            properties: {
              file: {type: 'string', format: 'binary'},
              projectId: {type: 'string'},
              type: {type: 'string'},
              tags: {type: 'array', items: {type: 'string'}},
            },
          },
        },
      },
    })
    request: Request,
    @inject(RestBindings.Http.REQUEST) req: Request,
  ): Promise<any> {
    const uploadResult = await this.assetStorageService.handleUpload(req);

    const asset = await this.assetRepository.create({
      projectId: uploadResult.projectId,
      name: uploadResult.fileName,
      type: (uploadResult.type || 'image') as any,
      fileName: uploadResult.fileName,
      storagePath: uploadResult.storagePath,
      fileUrl: uploadResult.url,
      fileSize: uploadResult.fileSize,
      mimeType: uploadResult.mimeType,
      width: uploadResult.width,
      height: uploadResult.height,
      tags: uploadResult.tags || [],
      metadata: uploadResult.metadata || {},
    });

    return {
      id: asset.id,
      url: asset.fileUrl,
      storagePath: asset.storagePath,
      fileName: asset.fileName,
      fileSize: asset.fileSize,
      mimeType: asset.mimeType,
      width: asset.width,
      height: asset.height,
    };
  }

  // Search by tags
  @get('/assets/search')
  @response(200, {
    description: 'Search assets by tags',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Asset),
        },
      },
    },
  })
  async searchByTags(
    @param.query.string('tags') tagsString?: string,
    @param.query.string('projectId') projectId?: string,
  ): Promise<Asset[]> {
    const tags = tagsString ? tagsString.split(',') : [];
    return this.assetRepository.searchByTags(tags, projectId);
  }

  // Get by type
  @get('/assets/by-type/{type}')
  @response(200, {
    description: 'Assets by type',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Asset),
        },
      },
    },
  })
  async findByType(
    @param.path.string('type') type: string,
    @param.query.string('projectId') projectId?: string,
  ): Promise<Asset[]> {
    return this.assetRepository.findByType(type, projectId);
  }

  // Storage stats
  @get('/assets/stats')
  @response(200, {
    description: 'Asset storage statistics',
    content: {
      'application/json': {
        schema: {
          type: 'object',
          properties: {
            totalAssets: {type: 'number'},
            totalSize: {type: 'number'},
            byType: {type: 'object'},
            byProject: {type: 'object'},
          },
        },
      },
    },
  })
  async getStats(@param.query.string('projectId') projectId?: string): Promise<any> {
    return this.assetRepository.getStorageStats(projectId);
  }
}
