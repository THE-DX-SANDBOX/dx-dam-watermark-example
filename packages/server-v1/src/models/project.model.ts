import {Entity, model, property, hasMany} from '@loopback/repository';
import {Specification} from './specification.model';
import {Asset} from './asset.model';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'projects'},
    strict: false,
  },
})
export class Project extends Entity {
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
  thumbnailUrl?: string;

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
    type: 'string',
  })
  createdBy?: string;

  @property({
    type: 'string',
    default: 'draft',
  })
  status: 'draft' | 'published' | 'archived';

  @property({
    type: 'object',
    postgresql: {
      dataType: 'jsonb',
    },
  })
  metadata?: Record<string, any>;

  @hasMany(() => Specification)
  specifications: Specification[];

  @hasMany(() => Asset)
  assets: Asset[];

  constructor(data?: Partial<Project>) {
    super(data);
  }
}

export interface ProjectRelations {
  specifications?: Specification[];
  assets?: Asset[];
}

export type ProjectWithRelations = Project & ProjectRelations;
