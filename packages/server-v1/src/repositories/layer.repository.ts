import {inject, Getter} from '@loopback/core';
import {DefaultCrudRepository, repository, BelongsToAccessor} from '@loopback/repository';
import {PostgresDataSource} from '../datasources';
import {Layer, LayerRelations, Specification} from '../models';
import {SpecificationRepository} from './specification.repository';

export class LayerRepository extends DefaultCrudRepository<
  Layer,
  typeof Layer.prototype.id,
  LayerRelations
> {
  public readonly specification: BelongsToAccessor<
    Specification,
    typeof Layer.prototype.id
  >;

  constructor(
    @inject('datasources.postgres') dataSource: PostgresDataSource,
    // Relationships commented out for local in-memory testing
    // @repository.getter('SpecificationRepository')
    // protected specificationRepositoryGetter: Getter<SpecificationRepository>,
  ) {
    super(Layer, dataSource);
    // Relationships disabled for in-memory datasource
    // this.specification = this.createBelongsToAccessorFor(
    //   'specification',
    //   specificationRepositoryGetter,
    // );
    // this.registerInclusionResolver('specification', this.specification.inclusionResolver);
  }

  /**
   * Find layers by specification, ordered by z-index
   */
  async findBySpecId(specId: string): Promise<Layer[]> {
    return this.find({
      where: {specId},
      order: ['zIndex ASC'],
    });
  }

  /**
   * Update z-index for multiple layers (reordering)
   */
  async reorderLayers(specId: string, layerIds: string[]): Promise<void> {
    const updates = layerIds.map((id, index) => ({id, zIndex: index}));
    await Promise.all(
      updates.map(({id, zIndex}) => this.updateById(id, {zIndex})),
    );
  }

  /**
   * Duplicate a layer
   */
  async duplicate(id: string, options?: {offsetX?: number; offsetY?: number}): Promise<Layer> {
    const layer = await this.findById(id);
    const maxZIndex = await this.getMaxZIndex(layer.specId);
    
    const offsetX = options?.offsetX || 10;
    const offsetY = options?.offsetY || 10;
    
    return this.create({
      ...layer,
      id: undefined, // Let database generate new ID
      name: `${layer.name} (Copy)`,
      zIndex: maxZIndex + 1,
      x: (layer.x || 0) + offsetX,
      y: (layer.y || 0) + offsetY,
    });
  }

  private async getMaxZIndex(specId: string): Promise<number> {
    const layers = await this.find({
      where: {specId},
      order: ['zIndex DESC'],
      limit: 1,
    });
    return layers.length > 0 ? layers[0].zIndex : 0;
  }
}
