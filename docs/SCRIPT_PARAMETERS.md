# Script Parameter Standards

This document defines the standardized command-line parameters used across all DAM-Demo scripts.

## Standardization Principles

1. **Consistent short forms** - Same functionality always uses the same flag
2. **No conflicts** - Each short form (`-x`) maps to only one purpose
3. **Long-form clarity** - Ambiguous parameters use `--long-form` only
4. **Context-appropriate** - Some parameters are specific to their script's domain

## Universal Parameters

These parameters have the same meaning across all scripts:

| Short | Long | Purpose | Used In |
|-------|------|---------|---------|
| `-n` | `--namespace` | Kubernetes namespace | All deployment scripts |
| `-t` | `--tag` | Docker image tag | build.sh, deploy.sh, build-and-deploy.sh |
| `-r` | `--release` | Helm release name | deploy.sh, undeploy.sh, toggle-dam-logging.sh |
| `-h` | `--help` | Show help message | All scripts |
| `-y` | `--yes` | Skip confirmation prompts | undeploy.sh |
| `-w` | `--wait` | Wait for operation to complete | restart-dam.sh |

## Script-Specific Parameters

### Build Scripts

**build.sh:**
- `-t, --tag TAG` - Docker image tag
- `-p, --push` - Push image to registry
- `--no-cache` - Build without cache
- `--helm` - Also build and push Helm chart

**build-and-deploy.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-t, --tag TAG` - Docker image tag
- `--skip-tests` - Skip running tests
- `--skip-build` - Skip Docker build (deploy only)

### Deployment Scripts

**deploy.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-r, --release RELEASE` - Helm release name
- `-t, --tag TAG` - Docker image tag
- `-v, --values FILE` - Helm values file (changed from `-f`)
- `--remote` - Deploy from remote registry (skip build)

**undeploy.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-r, --release RELEASE` - Helm release name
- `-y, --yes` - Skip confirmation prompt

### Development Tools

**port-forward.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-l, --local-port PORT` - Local port number
- `--remote-port PORT` - Remote port number (no short form to avoid conflict)
- `-d, --deployment NAME` - Deployment name

**test-plugin.sh:**
- `-u, --url URL` - Plugin URL
- `-f, --file FILE` - Test image file
- `--callback URL` - Callback URL (no short form to avoid conflict)
- `-k, --api-key KEY` - API key

### DAM Management Scripts

**get-dam-logs.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-o, --output FILE` - Output file name
- `-t, --tail LINES` - Number of lines to tail
- `-F, --follow` - Follow logs in real-time (changed from `-f`)
- `-c, --container NAME` - Container name

**restart-dam.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-w, --wait` - Wait for rollout to complete

**toggle-dam-logging.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `-r, --release RELEASE` - DX Helm release name
- `--level LEVEL` - Log level (info|debug|error)

**register-plugin-with-dam.sh:**
- `-n, --namespace NAMESPACE` - Kubernetes namespace
- `--plugin-url URL` - Plugin service URL (no short form to avoid conflict)
- `--plugin-name NAME` - Plugin name
- `--auth-key KEY` - Plugin authentication key
- `--rendition-stack STACK` - Rendition stack name
- `--mime-types TYPES` - Comma-separated MIME types
- `--force` - Force re-registration (no short form to avoid conflict)
- `--show-config` - Display current configuration
- `--show-renditions` - Display rendition configuration

## Removed Conflicts

The following conflicts were resolved by removing short forms:

### Before (Conflicting):
- `-r` = "release" OR "remote-port" ❌
- `-f` = "file" OR "follow" OR "force" OR "values" ❌
- `-p` = "push" OR "plugin-url" OR "plugin-release" ❌
- `-c` = "callback" OR "container" ❌

### After (Standardized):
- `-r` = "release" only ✅
- `--remote-port` = remote port (long form only) ✅
- `-f` = "file" only (test scripts) ✅
- `-F` = "follow" (logs) ✅
- `--force` = force (long form only) ✅
- `-v` = "values" (Helm values file, following Helm conventions) ✅
- `-p` = "push" only (build scripts) ✅
- `--plugin-url` = plugin URL (long form only) ✅
- `-c` = "container" only (logs) ✅
- `--callback` = callback URL (long form only) ✅

## Parameter Naming Conventions

### Port Names
- Local port: `-l, --local-port`
- Remote port: `--remote-port` (no short form)
- Generic port: `-p` only in specific contexts

### File Types
- Generic file: `-f, --file`
- Values file (Helm): `-v, --values`
- Output file: `-o, --output`
- Config file: `--config` (long form only)

### URLs and Endpoints
- Generic URL: `-u, --url`
- Plugin URL: `--plugin-url` (long form only)
- Callback URL: `--callback` (long form only)

### Kubernetes Resources
- Namespace: `-n, --namespace`
- Deployment: `-d, --deployment`
- Release: `-r, --release`
- Container: `-c, --container`

### Action Modifiers
- Force: `--force` (long form only)
- Follow: `-F, --follow` (distinct from file)
- Wait: `-w, --wait`
- Yes/Skip: `-y, --yes`
- Push: `-p, --push` (build only)

## Usage Examples

### Consistent Namespace Usage
```bash
# All these use the same -n flag
./scripts/deploy.sh -n production
./scripts/get-dam-logs.sh -n production
./scripts/port-forward.sh -n production
./scripts/register-plugin-with-dam.sh -n production
```

### File vs Values vs Output
```bash
# -f = test file
./scripts/test-plugin.sh -f test.jpg

# -v = Helm values file (not -f)
./scripts/deploy.sh -v custom-values.yaml

# -o = output file
./scripts/get-dam-logs.sh -o my-logs.txt
```

### Follow vs Force vs File
```bash
# -F = follow logs (uppercase to avoid conflict)
./scripts/get-dam-logs.sh -F

# --force = force re-registration (long form only)
./scripts/register-plugin-with-dam.sh --force

# -f = file input (test scripts only)
./scripts/test-plugin.sh -f image.jpg
```

### Release vs Remote-Port
```bash
# -r = release name
./scripts/deploy.sh -r my-release

# --remote-port = remote port (no short form)
./scripts/port-forward.sh --remote-port 3000
```

## Migration Guide

If you have existing scripts or CI/CD pipelines using the old parameters:

### Changed Parameters
| Old | New | Script | Notes |
|-----|-----|--------|-------|
| `-f FILE` | `-v FILE` | deploy.sh | Helm values file now uses `-v` |
| `-f` | `-F` | get-dam-logs.sh | Follow logs now uses `-F` |
| `-r PORT` | `--remote-port PORT` | port-forward.sh | No short form |
| `-p URL` | `--plugin-url URL` | register-plugin-with-dam.sh | No short form |
| `-f` | `--force` | register-plugin-with-dam.sh | No short form |
| `-c URL` | `--callback URL` | test-plugin.sh | No short form |

### Backward Compatibility

Port-forward.sh maintains backward compatibility with positional arguments:
```bash
# Still works (deprecated)
./scripts/port-forward.sh <Namespace> 3000 3000 <PluginServiceName>

# Preferred (new style)
./scripts/port-forward.sh -n <Namespace> -l 3000 --remote-port 3000
```

## Best Practices

1. **Use .env first** - Set defaults in `.env` file, override with flags only when needed
2. **Prefer long forms in scripts** - Use `--namespace` instead of `-n` for clarity in CI/CD
3. **Use short forms interactively** - Save typing with `-n`, `-t`, `-r` etc. when running manually
4. **Always check help** - Run `script.sh -h` to see current parameters
5. **Validate config** - Run `./scripts/validate-config.sh` to check your `.env` setup

## Validation

To verify parameter standardization:

```bash
# Check all scripts have help
for script in scripts/*.sh; do 
  echo "=== $(basename $script) ==="
  grep -q "show_help" "$script" && echo "✅ Has help" || echo "❌ No help"
done

# Test help output
./scripts/deploy.sh -h
./scripts/build.sh -h
./scripts/port-forward.sh -h

# Validate configuration
./scripts/validate-config.sh
```

## References

- [Helm CLI Conventions](https://helm.sh/docs/helm/helm/) - Using `-v` for values files
- [kubectl Conventions](https://kubernetes.io/docs/reference/kubectl/) - Using `-n` for namespace
- [POSIX Utility Conventions](https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/V1_chap12.html) - Short and long option styles

---

Last Updated: 2026-01-30
