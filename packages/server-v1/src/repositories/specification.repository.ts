import {inject, Getter} from '@loopback/core';
import {DefaultCrudRepository, repository, BelongsToAccessor, HasManyRepositoryFactory} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {Specification, SpecificationRelations, Project, Layer, RenderedImage} from '../models';
import {ProjectRepository} from './project.repository';
import {LayerRepository} from './layer.repository';
import {RenderedImageRepository} from './rendered-image.repository';

export class SpecificationRepository extends DefaultCrudRepository<
  Specification,
  typeof Specification.prototype.id,
  SpecificationRelations
> {
  public readonly project: BelongsToAccessor<Project, typeof Specification.prototype.id>;

  public readonly layers: HasManyRepositoryFactory<Layer, typeof Specification.prototype.id>;

  public readonly renderedImages: HasManyRepositoryFactory<
    RenderedImage,
    typeof Specification.prototype.id
  >;

  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource,
    // Relationships commented out for local in-memory testing
    // @repository.getter('ProjectRepository')
    // protected projectRepositoryGetter: Getter<ProjectRepository>,
    // @repository.getter('LayerRepository')
    // protected layerRepositoryGetter: Getter<LayerRepository>,
    // @repository.getter('RenderedImageRepository')
    // protected renderedImageRepositoryGetter: Getter<RenderedImageRepository>,
  ) {
    super(Specification, dataSource);
    // Relationships disabled for in-memory datasource
    // this.renderedImages = this.createHasManyRepositoryFactoryFor(
    //   'renderedImages',
    //   renderedImageRepositoryGetter,
    // );
    // this.registerInclusionResolver('renderedImages', this.renderedImages.inclusionResolver);
    // this.layers = this.createHasManyRepositoryFactoryFor('layers', layerRepositoryGetter);
    // this.registerInclusionResolver('layers', this.layers.inclusionResolver);
    // this.project = this.createBelongsToAccessorFor('project', projectRepositoryGetter);
    // this.registerInclusionResolver('project', this.project.inclusionResolver);
  }

  /**
   * Find active specifications with layer count
   */
  async findActiveWithDetails(filter?: any): Promise<any[]> {
    const sql = `
      SELECT 
        s.*,
        p.name as project_name,
        (SELECT COUNT(*) FROM layers WHERE spec_id = s.id) as layer_count
      FROM specifications s
      LEFT JOIN projects p ON s.project_id = p.id
      WHERE s.is_active = true
      ORDER BY s.updated_at DESC
    `;
    
    return this.dataSource.execute(sql);
  }

  /**
   * Create a new version of a specification
   */
  async createVersion(id: string, updates: Partial<Specification>): Promise<Specification> {
    const existing = await this.findById(id);
    const newVersion = await this.create({
      ...existing,
      ...updates,
      id: undefined, // Let database generate new ID
      version: existing.version + 1,
      createdAt: new Date(),
      updatedAt: new Date(),
    });
    
    // Mark old version as inactive
    await this.updateById(id, {isActive: false});
    
    return newVersion;
  }
}
