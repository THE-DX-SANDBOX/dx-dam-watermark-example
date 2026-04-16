# PostgreSQL Database Integration Guide

## Overview

The initialization system now includes PostgreSQL database configuration with smart defaults tailored for HCL DX environments. Each DX instance typically includes a PostgreSQL database for custom applications.

## Features

### Smart Defaults

The initialization wizard provides intelligent defaults based on common DX patterns:

| Setting | Default Value | Description |
|---------|---------------|-------------|
| **DB Host** | `${NAMESPACE}-dx-postgres` | Kubernetes service pattern for DX PostgreSQL |
| **DB Port** | `5432` | Standard PostgreSQL port |
| **Database Name** | `${PROJECT_NAME}` (with underscores) | Derived from project name |
| **Database User** | `${PROJECT_NAME}_user` | Project-specific user |
| **SSL Mode** | `require` (prod) / `prefer` (dev) | Secure by default |
| **Max Connections** | `10` | Conservative pool size |

### Initialization Wizard Steps

When you run `./scripts/init-template.sh`, Step 7 will prompt for PostgreSQL configuration:

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Step 7: PostgreSQL Database (Optional)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Configure PostgreSQL database? [Y/n]: y

PostgreSQL Connection Details:
  PostgreSQL Host [my-namespace-dx-postgres]: 
  PostgreSQL Port [5432]: 
  Database Name [my_project]: 
  Database User [my_project]: 
  Database Password [changeme]: ********
  Use SSL/TLS for database connection? [Y/n]: y
  Max Connections (pool size) [10]: 

Test database connection? [Y/n]: y
Testing PostgreSQL connection...
  ✓ PostgreSQL server is reachable
  ⚠ Database 'my_project' does not exist yet

Would you like guidance on creating the database? [Y/n]: y
```

### Database Creation Guide

If the database doesn't exist, the wizard can create `docs/DATABASE_SETUP.md` with:

1. **Method 1: kubectl exec** - Connect directly to PostgreSQL pod
2. **Method 2: Port forwarding** - Use local psql with port-forward
3. **Method 3: DX Admin Tools** - Use DX Portal admin console

The guide includes:
- Complete SQL commands with your actual values
- Connection examples
- Permission grants
- Backup/restore procedures
- Troubleshooting tips

## Generated Configuration

### Environment Variables (.env)

The wizard adds these variables to your `.env` file:

```bash
# PostgreSQL Database Configuration
DB_HOST=my-namespace-dx-postgres
DB_PORT=5432
DB_NAME=my_project
DB_USER=my_project
DB_PASSWORD=changeme
DB_SSL=true
DB_MAX_CONNECTIONS=10

# PostgreSQL Connection URL (for LoopBack, Prisma, TypeORM, etc.)
DATABASE_URL=postgresql://my_project:changeme@my-namespace-dx-postgres:5432/my_project?sslmode=require

# Connection Pool Settings
DB_POOL_MIN=2
DB_POOL_MAX=10
DB_IDLE_TIMEOUT_MS=30000
DB_CONNECTION_TIMEOUT_MS=5000
```

### LoopBack 4 Integration

After initialization, integrate with LoopBack:

```bash
cd packages/server-v1

# Install PostgreSQL connector
npm install --save loopback-connector-postgresql

# Create datasource
lb4 datasource
# Name: postgres
# Connector: PostgreSQL
# It will automatically use environment variables
```

Create `src/datasources/postgres.datasource.ts`:

```typescript
import {inject, lifeCycleObserver, LifeCycleObserver} from '@loopback/core';
import {juggler} from '@loopback/repository';

const config = {
  name: 'postgres',
  connector: 'postgresql',
  host: process.env.DB_HOST,
  port: process.env.DB_PORT,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ssl: process.env.DB_SSL === 'true',
  max: parseInt(process.env.DB_MAX_CONNECTIONS || '10', 10),
};

@lifeCycleObserver('datasource')
export class PostgresDataSource extends juggler.DataSource
  implements LifeCycleObserver {
  static dataSourceName = 'postgres';
  static readonly defaultConfig = config;

  constructor(
    @inject('datasources.config.postgres', {optional: true})
    dsConfig: object = config,
  ) {
    super(dsConfig);
  }
}
```

## Validation

The validation script (`./scripts/validate-deployment-readiness.sh`) includes PostgreSQL checks:

### Configuration Checks

- ✅ `DB_HOST` is set
- ✅ `DB_PORT` is set (or uses default 5432)
- ✅ `DB_NAME` is set
- ✅ `DB_USER` is set
- ✅ `DB_PASSWORD` is set
- ✅ `DATABASE_URL` is set

### Connection Tests (if psql installed)

- ✅ PostgreSQL server is reachable
- ✅ Database exists
- ⚠️ Warns if database needs to be created
- ℹ️ Gracefully handles cluster-only access

### Dependency Checks

- ✅ LoopBack PostgreSQL connector installed (if using LoopBack)
- ⚠️ Suggests installation if missing

## Database Setup Workflow

### For New Projects

1. **Run Initialization**
   ```bash
   ./scripts/init-template.sh
   ```
   - Select "Configure PostgreSQL database"
   - Enter connection details (or accept smart defaults)
   - Choose to generate database setup guide

2. **Create Database**
   ```bash
   # Connect to PostgreSQL pod
   kubectl exec -it -n my-namespace deployment/my-namespace-dx-postgres -- psql -U postgres
   
  # If generated, run SQL from docs/DATABASE_SETUP.md
   CREATE DATABASE my_project;
   CREATE USER my_project WITH PASSWORD 'changeme';
   GRANT ALL PRIVILEGES ON DATABASE my_project TO my_project;
   ```

3. **Validate**
   ```bash
   ./scripts/validate-deployment-readiness.sh
   ```
   - Should show ✅ Database exists
   - Should show ✅ Connection successful

4. **Install Dependencies**
   ```bash
   cd packages/server-v1
   npm install --save loopback-connector-postgresql
   ```

5. **Create Models & Repositories**
   ```bash
   lb4 model      # Create data model
   lb4 repository # Connect to postgres datasource
   ```

### For Existing Projects

If you already have a database:

1. Run initialization and enter existing credentials
2. Skip database creation
3. Validate connection works
4. Continue with deployment

## Security Best Practices

### 1. Use Kubernetes Secrets

Instead of plain text passwords in `.env`, use K8s secrets:

```bash
kubectl create secret generic my-project-db-credentials \
  --from-literal=username=my_project \
  --from-literal=password=changeme \
  --from-literal=database=my_project \
  -n my-namespace
```

Update Helm chart to reference secret:

```yaml
# helm/dam-plugin/templates/deployment.yaml
env:
  - name: DB_USER
    valueFrom:
      secretKeyRef:
        name: my-project-db-credentials
        key: username
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: my-project-db-credentials
        key: password
  - name: DB_NAME
    valueFrom:
      secretKeyRef:
        name: my-project-db-credentials
        key: database
```

### 2. Enable SSL/TLS

Always use SSL in production:

```bash
DB_SSL=true
```

For self-signed certificates:

```bash
DB_SSL_REJECT_UNAUTHORIZED=false
```

### 3. Limit Permissions

Create application-specific users with minimal permissions:

```sql
-- Read-only user
CREATE USER myapp_readonly WITH PASSWORD 'secret';
GRANT CONNECT ON DATABASE myapp TO myapp_readonly;
GRANT USAGE ON SCHEMA public TO myapp_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO myapp_readonly;

-- Write user (for API)
CREATE USER myapp_api WITH PASSWORD 'secret';
GRANT ALL PRIVILEGES ON DATABASE myapp TO myapp_api;
```

### 4. Connection Pooling

Configure appropriate pool sizes:

```bash
DB_MAX_CONNECTIONS=20        # Max connections in pool
DB_POOL_MIN=2                # Min connections to maintain
DB_IDLE_TIMEOUT_MS=30000     # Close idle connections after 30s
DB_CONNECTION_TIMEOUT_MS=5000 # Timeout for new connections
```

## Troubleshooting

### Cannot Connect to Database

**Issue:** `ECONNREFUSED` or connection timeout

**Solutions:**
1. Verify PostgreSQL pod is running:
   ```bash
   kubectl get pods -n my-namespace | grep postgres
   ```

2. Check if service exists:
   ```bash
   kubectl get svc -n my-namespace | grep postgres
   ```

3. Test from within cluster:
   ```bash
   kubectl run -it --rm psql-test --image=postgres:15 -n my-namespace -- \
     psql -h my-namespace-dx-postgres -p 5432 -U postgres
   ```

4. Port forward and test locally:
   ```bash
   kubectl port-forward -n my-namespace svc/my-namespace-dx-postgres 5432:5432 &
   PGPASSWORD=changeme psql -h localhost -p 5432 -U my_project -d my_project
   ```

### Database Does Not Exist

**Issue:** `FATAL: database "my_project" does not exist`

**Solution:** Create the database using `docs/DATABASE_SETUP.md` if init generated it, or follow the SQL examples in this guide

### Permission Denied

**Issue:** `ERROR: permission denied for schema public`

**Solution:** Grant schema permissions:
```sql
\c my_project
GRANT ALL ON SCHEMA public TO my_project;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO my_project;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO my_project;
```

### Connection Pool Exhausted

**Issue:** `Too many clients already`

**Solutions:**
1. Increase pool size:
   ```bash
   DB_MAX_CONNECTIONS=50
   ```

2. Check for connection leaks:
   ```sql
   SELECT count(*) FROM pg_stat_activity WHERE datname='my_project';
   ```

3. Increase PostgreSQL max_connections:
   ```bash
   kubectl exec -n my-namespace deployment/my-namespace-dx-postgres -- \
     psql -U postgres -c "ALTER SYSTEM SET max_connections = 200;"
   kubectl rollout restart deployment/my-namespace-dx-postgres -n my-namespace
   ```

## References

- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [LoopBack PostgreSQL Connector](https://loopback.io/doc/en/lb4/PostgreSQL-connector.html)
- [Kubernetes Secrets](https://kubernetes.io/docs/concepts/configuration/secret/)
- [Connection Pooling Best Practices](https://node-postgres.com/features/pooling)

## Related Documentation

- [START_HERE.md](../START_HERE.md) - Quick start guide
- [DATABASE_SETUP.md](DATABASE_SETUP.md) - Detailed database creation guide (generated during init)
- [INITIALIZATION_GUIDE.md](../scripts/INITIALIZATION_GUIDE.md) - Complete initialization walkthrough
- [QUICK_REFERENCE.md](QUICK_REFERENCE.md) - Command reference
