import {Entity, model, property, belongsTo} from '@loopback/repository';
import {Project} from './project.model';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'assets'},
    strict: false,
  },
})
export class Asset extends Entity {
  @property({
    type: 'string',
    id: true,
    postgresql: {
      dataType: 'uuid',
      defaultFn: 'uuid_generate_v4',
    },
  })
  id: string;

  @belongsTo(() => Project, {name: 'project'})
  projectId?: string;

  @property({
    type: 'string',
    required: true,
  })
  name: string;

  @property({
    type: 'string',
    required: true,
  })
  type: 'image' | 'font' | 'texture' | 'template' | 'icon';

  @property({
    type: 'string',
  })
  mimeType?: string;

  @property({
    type: 'string',
    required: true,
  })
  storagePath: string;

  @property({
    type: 'string',
  })
  fileUrl?: string;

  @property({
    type: 'string',
  })
  fileName?: string;

  @property({
    type: 'string',
    default: 'local',
  })
  storageProvider: string;

  @property({
    type: 'number',
    postgresql: {
      dataType: 'bigint',
    },
  })
  fileSize?: number;

  @property({
    type: 'number',
  })
  width?: number;

  @property({
    type: 'number',
  })
  height?: number;

  @property({
    type: 'object',
    postgresql: {
      dataType: 'jsonb',
    },
  })
  metadata?: Record<string, any>;

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

  constructor(data?: Partial<Asset>) {
    super(data);
  }
}

export interface AssetRelations {
  project?: Project;
}

export type AssetWithRelations = Asset & AssetRelations;
