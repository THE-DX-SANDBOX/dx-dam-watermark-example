import {inject, lifeCycleObserver, LifeCycleObserver} from '@loopback/core';
import {juggler} from '@loopback/repository';

/**
 * PostgreSQL datasource configuration
 * Local example: kubectl port-forward -n <namespace> svc/<postgres-service> 5432:5432
 */
const config = {
  name: 'postgres',
  connector: 'postgresql',
  host: process.env.DB_HOST || 'localhost',
  port: parseInt(process.env.DB_PORT || '5432'),
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || '',
  database: process.env.DB_NAME || 'dam_demo',
};

@lifeCycleObserver('datasource')
export class PostgresDataSource extends juggler.DataSource implements LifeCycleObserver {
  static dataSourceName = 'postgres';
  static readonly defaultConfig = config;

  constructor(
    @inject('datasources.config.postgres', {optional: true})
    dsConfig: object = config,
  ) {
    super(dsConfig);
    console.log('📊 PostgreSQL DataSource connecting to:', {
      host: config.host,
      port: config.port,
      database: config.database,
      user: config.user,
    });
  }
}
