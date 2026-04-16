import {inject, Getter} from '@loopback/core';
import {DefaultCrudRepository, repository, HasManyRepositoryFactory} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {Project, ProjectRelations, Specification, Asset} from '../models';
import {SpecificationRepository} from './specification.repository';
import {AssetRepository} from './asset.repository';

export class ProjectRepository extends DefaultCrudRepository<
  Project,
  typeof Project.prototype.id,
  ProjectRelations
> {
  public readonly specifications: HasManyRepositoryFactory<
    Specification,
    typeof Project.prototype.id
  >;

  public readonly assets: HasManyRepositoryFactory<
    Asset,
    typeof Project.prototype.id
  >;

  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource,
    // Relationships commented out for local in-memory testing
    // @repository.getter('SpecificationRepository')
    // protected specificationRepositoryGetter: Getter<SpecificationRepository>,
    // @repository.getter('AssetRepository')
    // protected assetRepositoryGetter: Getter<AssetRepository>,
  ) {
    super(Project, dataSource);
    // Relationships disabled for in-memory datasource
    // this.assets = this.createHasManyRepositoryFactoryFor('assets', assetRepositoryGetter);
    // this.registerInclusionResolver('assets', this.assets.inclusionResolver);
    // this.specifications = this.createHasManyRepositoryFactoryFor(
    //   'specifications',
    //   specificationRepositoryGetter,
    // );
    // this.registerInclusionResolver('specifications', this.specifications.inclusionResolver);
  }

  /**
   * Find projects with their latest active specification
   */
  async findWithLatestSpec(filter?: any): Promise<any[]> {
    const sql = `
      SELECT 
        p.*,
        s.id as latest_spec_id,
        s.name as latest_spec_name,
        s.version as latest_spec_version
      FROM projects p
      LEFT JOIN LATERAL (
        SELECT * FROM specifications
        WHERE project_id = p.id AND is_active = true
        ORDER BY version DESC
        LIMIT 1
      ) s ON true
      ${filter?.where ? 'WHERE ' + this.buildWhereClause(filter.where) : ''}
      ORDER BY p.created_at DESC
    `;
    
    return this.dataSource.execute(sql);
  }

  private buildWhereClause(where: any): string {
    // Simple WHERE clause builder - extend as needed
    if (!where) return '1=1';
    const conditions: string[] = [];
    for (const [key, value] of Object.entries(where)) {
      if (typeof value === 'string') {
        conditions.push(`p.${key} = '${value}'`);
      } else {
        conditions.push(`p.${key} = ${value}`);
      }
    }
    return conditions.join(' AND ');
  }
}
