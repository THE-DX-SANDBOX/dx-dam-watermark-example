import {Entity, model, property, belongsTo} from '@loopback/repository';
import {Specification} from './specification.model';

@model({
  settings: {
    postgresql: {schema: 'public', table: 'rendered_images'},
    strict: false,
  },
})
export class RenderedImage extends Entity {
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
  format: 'png' | 'jpg' | 'jpeg' | 'webp' | 'svg';

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
    type: 'number',
  })
  quality?: number;

  @property({
    type: 'string',
    required: true,
  })
  filePath: string;

  @property({
    type: 'number',
    postgresql: {
      dataType: 'bigint',
    },
  })
  fileSize?: number;

  @property({
    type: 'string',
  })
  fileUrl?: string;

  @property({
    type: 'string',
    default: 'pending',
  })
  status: 'pending' | 'processing' | 'completed' | 'failed';

  @property({
    type: 'string',
  })
  errorMessage?: string;

  @property({
    type: 'number',
  })
  renderTimeMs?: number;

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
    },
  })
  expiresAt?: Date;

  constructor(data?: Partial<RenderedImage>) {
    super(data);
  }
}

export interface RenderedImageRelations {
  specification?: Specification;
}

export type RenderedImageWithRelations = RenderedImage & RenderedImageRelations;
