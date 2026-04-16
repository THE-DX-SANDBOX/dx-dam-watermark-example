import {inject} from '@loopback/core';
import {DefaultCrudRepository} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {Template, TemplateRelations} from '../models';

export class TemplateRepository extends DefaultCrudRepository<
  Template,
  typeof Template.prototype.id,
  TemplateRelations
> {
  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource
  ) {
    super(Template, dataSource);
  }

  /**
   * Find public templates
   */
  async findPublic(category?: string): Promise<Template[]> {
    const where: any = {isPublic: true};
    if (category) {
      where.category = category;
    }
    return this.find({
      where,
      order: ['useCount DESC', 'name ASC'],
    });
  }

  /**
   * Search templates by tags
   */
  async searchByTags(tags: string[], category?: string): Promise<Template[]> {
    let sql = `
      SELECT * FROM templates 
      WHERE tags && $1 AND is_public = true
    `;
    
    const params: any[] = [tags];
    
    if (category) {
      sql += ` AND category = $2`;
      params.push(category);
    }
    
    sql += ` ORDER BY use_count DESC, name ASC`;
    
    return this.dataSource.execute(sql, params);
  }

  /**
   * Increment use count when template is used
   */
  async incrementUseCount(id: string): Promise<void> {
    const template = await this.findById(id);
    await this.updateById(id, {useCount: (template.useCount || 0) + 1});
  }

  /**
   * Get popular templates
   */
  async getPopular(limit: number = 10): Promise<Template[]> {
    return this.find({
      where: {isPublic: true},
      order: ['useCount DESC'],
      limit,
    });
  }
}
