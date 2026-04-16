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
import {Project} from '../models';
import {ProjectRepository} from '../repositories';

export class ProjectController {
  constructor(
    @repository(ProjectRepository)
    public projectRepository: ProjectRepository,
  ) {}

  @post('/projects')
  @response(200, {
    description: 'Project model instance',
    content: {'application/json': {schema: getModelSchemaRef(Project)}},
  })
  async create(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Project, {
            title: 'NewProject',
            exclude: ['id'],
          }),
        },
      },
    })
    project: Omit<Project, 'id'>,
  ): Promise<Project> {
    return this.projectRepository.create(project);
  }

  @get('/projects/count')
  @response(200, {
    description: 'Project model count',
    content: {'application/json': {schema: CountSchema}},
  })
  async count(@param.where(Project) where?: Where<Project>): Promise<Count> {
    return this.projectRepository.count(where);
  }

  @get('/projects')
  @response(200, {
    description: 'Array of Project model instances',
    content: {
      'application/json': {
        schema: {
          type: 'array',
          items: getModelSchemaRef(Project, {includeRelations: true}),
        },
      },
    },
  })
  async find(@param.filter(Project) filter?: Filter<Project>): Promise<Project[]> {
    return this.projectRepository.find(filter);
  }

  @get('/projects/with-latest-spec')
  @response(200, {
    description: 'Projects with their latest specification',
  })
  async findWithLatestSpec(@param.filter(Project) filter?: Filter<Project>): Promise<any[]> {
    return this.projectRepository.findWithLatestSpec(filter);
  }

  @patch('/projects')
  @response(200, {
    description: 'Project PATCH success count',
    content: {'application/json': {schema: CountSchema}},
  })
  async updateAll(
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Project, {partial: true}),
        },
      },
    })
    project: Project,
    @param.where(Project) where?: Where<Project>,
  ): Promise<Count> {
    return this.projectRepository.updateAll(project, where);
  }

  @get('/projects/{id}')
  @response(200, {
    description: 'Project model instance',
    content: {
      'application/json': {
        schema: getModelSchemaRef(Project, {includeRelations: true}),
      },
    },
  })
  async findById(
    @param.path.string('id') id: string,
    @param.filter(Project, {exclude: 'where'}) filter?: FilterExcludingWhere<Project>,
  ): Promise<Project> {
    return this.projectRepository.findById(id, filter);
  }

  @patch('/projects/{id}')
  @response(204, {
    description: 'Project PATCH success',
  })
  async updateById(
    @param.path.string('id') id: string,
    @requestBody({
      content: {
        'application/json': {
          schema: getModelSchemaRef(Project, {partial: true}),
        },
      },
    })
    project: Project,
  ): Promise<void> {
    await this.projectRepository.updateById(id, project);
  }

  @put('/projects/{id}')
  @response(204, {
    description: 'Project PUT success',
  })
  async replaceById(@param.path.string('id') id: string, @requestBody() project: Project): Promise<void> {
    // Use updateById instead of replaceById to avoid wiping unincluded fields (e.g. metadata)
    await this.projectRepository.updateById(id, project);
  }

  @put('/projects/{id}/replace')
  @response(204, {
    description: 'Project full replace success',
  })
  async fullReplaceById(@param.path.string('id') id: string, @requestBody() project: Project): Promise<void> {
    await this.projectRepository.replaceById(id, project);
  }

  @del('/projects/{id}')
  @response(204, {
    description: 'Project DELETE success',
  })
  async deleteById(@param.path.string('id') id: string): Promise<void> {
    await this.projectRepository.deleteById(id);
  }

  // Relationship endpoints
  @get('/projects/{id}/specifications')
  @response(200, {
    description: 'Array of Specifications belonging to Project',
  })
  async findSpecifications(
    @param.path.string('id') id: string,
    @param.query.object('filter') filter?: any,
  ): Promise<any[]> {
    return this.projectRepository.specifications(id).find(filter);
  }

  @get('/projects/{id}/assets')
  @response(200, {
    description: 'Array of Assets belonging to Project',
  })
  async findAssets(
    @param.path.string('id') id: string,
    @param.query.object('filter') filter?: any,
  ): Promise<any[]> {
    return this.projectRepository.assets(id).find(filter);
  }
}
