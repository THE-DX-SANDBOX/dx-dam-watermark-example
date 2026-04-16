import {Entity, model, property} from '@loopback/repository';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'templates'},
    strict: false,
  },
})
export class Template extends Entity {
  @property({
    type: 'string',
    id: true,
    postgresql: {
      dataType: 'uuid',
      defaultFn: 'uuid_generate_v4',
    },
  })
  id: string;

  @property({
    type: 'string',
    required: true,
  })
  name: string;

  @property({
    type: 'string',
  })
  description?: string;

  @property({
    type: 'string',
  })
  category?: string;

  @property({
    type: 'object',
    required: true,
    postgresql: {
      dataType: 'jsonb',
    },
  })
  templateSpec: Record<string, any>;

  @property({
    type: 'string',
  })
  thumbnailUrl?: string;

  @property({
    type: 'number',
    default: 0,
  })
  useCount: number;

  @property({
    type: 'array',
    itemType: 'string',
    postgresql: {
      dataType: 'text[]',
    },
  })
  tags?: string[];

  @property({
    type: 'date',
    postgresql: {
      dataType: 'timestamp',
      defaultFn: 'CURRENT_TIMESTAMP',
    },
  })
  createdAt?: Date;

  @property({
    type: 'string',
  })
  createdBy?: string;

  @property({
    type: 'boolean',
    default: false,
  })
  isPublic: boolean;

  constructor(data?: Partial<Template>) {
    super(data);
  }
}

export interface TemplateRelations {
  // describe navigational properties here
}

export type TemplateWithRelations = Template & TemplateRelations;
