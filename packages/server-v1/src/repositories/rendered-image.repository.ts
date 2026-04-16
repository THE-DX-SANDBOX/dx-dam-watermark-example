import {inject, Getter} from '@loopback/core';
import {DefaultCrudRepository, repository, BelongsToAccessor} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {RenderedImage, RenderedImageRelations, Specification} from '../models';
import {SpecificationRepository} from './specification.repository';

export class RenderedImageRepository extends DefaultCrudRepository<
  RenderedImage,
  typeof RenderedImage.prototype.id,
  RenderedImageRelations
> {
  public readonly specification: BelongsToAccessor<
    Specification,
    typeof RenderedImage.prototype.id
  >;

  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource,
    // Relationships commented out for local in-memory testing
    // @repository.getter('SpecificationRepository')
    // protected specificationRepositoryGetter: Getter<SpecificationRepository>,
  ) {
    super(RenderedImage, dataSource);
    // Relationships disabled for in-memory datasource
    // this.specification = this.createBelongsToAccessorFor(
    //   'specification',
    //   specificationRepositoryGetter,
    // );
    // this.registerInclusionResolver('specification', this.specification.inclusionResolver);
  }

  /**
   * Find a cached render for a specification
   */
  async findCachedRender(
    specId: string,
    format: string,
    width: number,
    height: number,
  ): Promise<RenderedImage | null> {
    const renders = await this.find({
      where: {
        specId,
        format: format as any,
        width,
        height,
        status: 'completed' as any,
      },
      order: ['createdAt DESC'],
      limit: 1,
    });

    if (renders.length > 0 && renders[0].expiresAt) {
      // Check if expired
      if (new Date() > new Date(renders[0].expiresAt)) {
        await this.deleteById(renders[0].id);
        return null;
      }
    }

    return renders.length > 0 ? renders[0] : null;
  }

  /**
   * Clean up expired renders
   */
  async cleanupExpired(): Promise<number> {
    const now = new Date();
    const expired = await this.find({
      where: {
        and: [
          {expiresAt: {neq: null as any}},
          {expiresAt: {lt: now}},
        ],
      },
    });

    await Promise.all(expired.map(render => this.deleteById(render.id)));
    return expired.length;
  }

  /**
   * Get render statistics
   */
  async getRenderStats(specId?: string): Promise<any> {
    const whereClause = specId ? `WHERE spec_id = '${specId}'` : '';
    const sql = `
      SELECT 
        format,
        status,
        COUNT(*) as count,
        AVG(render_time_ms) as avg_render_time,
        SUM(file_size) as total_size
      FROM rendered_images
      ${whereClause}
      GROUP BY format, status
    `;
    
    return this.dataSource.execute(sql);
  }
}
