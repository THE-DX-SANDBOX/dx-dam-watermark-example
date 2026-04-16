# Plugin Registration

Plugin registration is how the deployed service becomes visible to HCL DAM as an extensibility plugin.

## What registration does

The registration flow updates the DAM configuration so DAM knows:

- the plugin name
- the plugin service URL
- the callback host DAM should use
- which actions the plugin exposes
- whether the plugin is enabled

In this repository, that logic is automated by `scripts/register-plugin-with-dam.sh`.

## Registration lifecycle

### 1. Initialize plugin metadata

`scripts/init-plugin.sh` creates or updates `plugin-config.json` with the plugin's identity and integration defaults.

That file includes:

- plugin name and display name
- description and author
- service port and API version
- DAM integration constraints such as supported file types and callback requirements
- Kubernetes deployment defaults such as namespace and resource settings

### 2. Deploy the service

The registration script assumes the service is already deployed and reachable. If no explicit plugin URL is provided, the script auto-detects the `dam-plugin` Kubernetes service and constructs an in-cluster URL.

### 3. Locate the DAM ConfigMap

The script finds the DX release in the target namespace and derives the Digital Asset Management ConfigMap name from that release.

### 4. Write the plugin registration entry

The script updates the `dam.config.dam.extensibility_plugin_config.json` key in the DAM ConfigMap.

The generated entry includes the plugin action mapping, callback host, enablement flag, authentication key, and base plugin URL.

## Why this matters

This is one of the least obvious parts of the repository. Without registration, the service may be healthy and deployed, but DAM will not know that it exists or where to send processing requests.

## What to verify after registration

- the plugin service health endpoint responds
- the service URL in the ConfigMap is correct
- the plugin appears in DAM configuration as expected
- the configured action path resolves to `/api/v1/process`

## Related files

- `plugin-config.json`
- `scripts/init-plugin.sh`
- `scripts/register-plugin-with-dam.sh`
- [./REGISTRATION.md](./REGISTRATION.md)