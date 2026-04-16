import {inject, Getter} from '@loopback/core';
import {DefaultCrudRepository, repository, BelongsToAccessor} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {Asset, AssetRelations, Project} from '../models';
import {ProjectRepository} from './project.repository';

export class AssetRepository extends DefaultCrudRepository<
  Asset,
  typeof Asset.prototype.id,
  AssetRelations
> {
  public readonly project: BelongsToAccessor<Project, typeof Asset.prototype.id>;

  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource,
    // Relationships commented out for local in-memory testing
    // @repository.getter('ProjectRepository')
    // protected projectRepositoryGetter: Getter<ProjectRepository>,
  ) {
    super(Asset, dataSource);
    // Relationships disabled for in-memory datasource
    // this.project = this.createBelongsToAccessorFor('project', projectRepositoryGetter);
    // this.registerInclusionResolver('project', this.project.inclusionResolver);
  }

  /**
   * Find assets by type
   */
  async findByType(type: string, projectId?: string): Promise<Asset[]> {
    const where: any = {type};
    if (projectId) {
      where.projectId = projectId;
    }
    return this.find({where, order: ['createdAt DESC']});
  }

  /**
   * Search assets by tags
   */
  async searchByTags(tags: string[], projectId?: string): Promise<Asset[]> {
    const sql = projectId
      ? `SELECT * FROM assets WHERE tags && $1 AND project_id = $2 ORDER BY created_at DESC`
      : `SELECT * FROM assets WHERE tags && $1 ORDER BY created_at DESC`;
    
    const params = projectId ? [tags, projectId] : [tags];
    return this.dataSource.execute(sql, params);
  }

  /**
   * Get storage statistics
   */
  async getStorageStats(projectId?: string): Promise<any> {
    const whereClause = projectId ? `WHERE project_id = '${projectId}'` : '';
    const sql = `
      SELECT 
        type,
        COUNT(*) as count,
        SUM(file_size) as total_size,
        AVG(file_size) as avg_size
      FROM assets
      ${whereClause}
      GROUP BY type
    `;
    
    return this.dataSource.execute(sql);
  }
}
