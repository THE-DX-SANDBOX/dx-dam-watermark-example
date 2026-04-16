# Reference

This page is a quick map to the files and scripts that matter most.

## Root files

- `package.json`: root scripts for build, deploy, test, and docs
- `lerna.json`: monorepo package layout
- `plugin-config.json`: plugin metadata and integration defaults
- `packages/Dockerfile`: runtime container image build

## Package entry points

- `packages/server-v1/package.json`
- `packages/portlet-v1/package.json`
- `packages/shared/package.json`

## Important scripts

- `scripts/init-template.sh`
- `scripts/init-plugin.sh`
- `scripts/build.sh`
- `scripts/deploy.sh`
- `scripts/deploy-portlet.sh`
- `scripts/register-plugin-with-dam.sh`

## Detailed documentation

- [./DEVELOPMENT.md](./DEVELOPMENT.md)
- [./DEPLOYMENT.md](./DEPLOYMENT.md)
- [./REGISTRATION.md](./REGISTRATION.md)
- [./PORTLET_DEPLOYMENT.md](./PORTLET_DEPLOYMENT.md)
- [./AI_RENDITION_INTEGRATION.md](./AI_RENDITION_INTEGRATION.md)