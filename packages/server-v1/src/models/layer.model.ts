import {Entity, model, property, belongsTo} from '@loopback/repository';
import {Specification} from './specification.model';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'layers'},
    strict: false,
  },
})
export class Layer extends Entity {
  @property({
    type: 'string',
    id: true,
    postgresql: {
      dataType: 'uuid',
      defaultFn: 'uuid_generate_v4',
    },
  })
  id: string;

  @belongsTo(() => Specification)
  specId: string;

  @property({
    type: 'string',
    required: true,
  })
  name: string;

  @property({
    type: 'string',
    required: true,
  })
  type: 'image' | 'text' | 'shape' | 'group';

  @property({
    type: 'number',
    required: true,
  })
  zIndex: number;

  @property({
    type: 'boolean',
    default: true,
  })
  visible: boolean;

  @property({
    type: 'boolean',
    default: false,
  })
  locked: boolean;

  @property({
    type: 'number',
    default: 1.0,
    postgresql: {
      dataType: 'decimal(3,2)',
    },
  })
  opacity: number;

  @property({
    type: 'number',
    default: 0,
    postgresql: {
      dataType: 'decimal(10,2)',
    },
  })
  x: number;

  @property({
    type: 'number',
    default: 0,
    postgresql: {
      dataType: 'decimal(10,2)',
    },
  })
  y: number;

  @property({
    type: 'number',
    postgresql: {
      dataType: 'decimal(10,2)',
    },
  })
  width?: number;

  @property({
    type: 'number',
    postgresql: {
      dataType: 'decimal(10,2)',
    },
  })
  height?: number;

  @property({
    type: 'number',
    default: 0,
    postgresql: {
      dataType: 'decimal(10,2)',
    },
  })
  rotation: number;

  @property({
    type: 'number',
    default: 1.0,
    postgresql: {
      dataType: 'decimal(10,4)',
    },
  })
  scaleX: number;

  @property({
    type: 'number',
    default: 1.0,
    postgresql: {
      dataType: 'decimal(10,4)',
    },
  })
  scaleY: number;

  @property({
    type: 'object',
    required: true,
    postgresql: {
      dataType: 'jsonb',
    },
  })
  layerData: Record<string, any>;

  @property({
    type: 'string',
    default: 'normal',
  })
  blendMode: string;

  @property({
    type: 'array',
    itemType: 'object',
    postgresql: {
      dataType: 'jsonb',
    },
  })
  filters?: Record<string, any>[];

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

  constructor(data?: Partial<Layer>) {
    super(data);
  }
}

export interface LayerRelations {
  specification?: Specification;
}

export type LayerWithRelations = Layer & LayerRelations;
