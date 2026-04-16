import {Entity, model, property, belongsTo, hasMany} from '@loopback/repository';
import {Project} from './project.model';
import {Layer} from './layer.model';
import {RenderedImage} from './rendered-image.model';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'specifications'},
    strict: false,
  },
})
export class Specification extends Entity {
  @property({
    type: 'string',
    id: true,
    postgresql: {
      dataType: 'uuid',
      defaultFn: 'uuid_generate_v4',
    },
  })
  id: string;

  @belongsTo(() => Project)
  projectId: string;

  @property({
    type: 'string',
    required: true,
  })
  name: string;

  @property({
    type: 'number',
    default: 1,
  })
  version: number;

  @property({
    type: 'number',
    required: true,
  })
  width: number;

  @property({
    type: 'number',
    required: true,
  })
  height: number;

  @property({
    type: 'string',
    default: '#FFFFFF',
  })
  backgroundColor: string;

  @property({
    type: 'boolean',
    default: false,
  })
  tilingEnabled: boolean;

  @property({
    type: 'string',
  })
  tilingPattern?: 'grid' | 'hexagonal' | 'brick' | 'diagonal' | 'random';

  @property({
    type: 'object',
    postgresql: {
      dataType: 'jsonb',
    },
  })
  tilingConfig?: Record<string, any>;

  @property({
    type: 'object',
    required: true,
    postgresql: {
      dataType: 'jsonb',
    },
  })
  specData: Record<string, any>;

  @property({
    type: 'date',
    postgresql: {
      dataType: 'timestamp',
      defaultFn: 'CURRENT_TIMESTAMP',
    },
  })
  createdAt?: Date;

  @property({
    type: 'date',
    postgresql: {
      dataType: 'timestamp',
      defaultFn: 'CURRENT_TIMESTAMP',
    },
  })
  updatedAt?: Date;

  @property({
    type: 'boolean',
    default: true,
  })
  isActive: boolean;

  @hasMany(() => Layer)
  layers: Layer[];

  @hasMany(() => RenderedImage)
  renderedImages: RenderedImage[];

  constructor(data?: Partial<Specification>) {
    super(data);
  }
}

export interface SpecificationRelations {
  project?: Project;
  layers?: Layer[];
  renderedImages?: RenderedImage[];
}

export type SpecificationWithRelations = Specification & SpecificationRelations;
