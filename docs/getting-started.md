# Getting Started

If you are new to this repository, the fastest way to orient yourself is:

1. Read [First Clone Setup](./first-clone-setup.md) to see which files you must create or edit.
2. Read [What This App Does](./what-this-app-does.md) to understand the example and the larger template.
3. Read [Repo Structure](./repo-structure.md) to see how the monorepo is laid out.
4. Read [Architecture](./architecture.md) to understand the runtime flow.
5. Use [Deployment Overview](./deployment-overview.md) and [Plugin Registration](./plugin-registration.md) when you are ready to operate it.

## Quick setup path

The repository is designed around an initialization-first workflow:

```bash
cp .env.example .env
./scripts/init-template.sh
./scripts/validate-deployment-readiness.sh
./scripts/build-and-deploy.sh
```

If you prefer environment-specific profiles instead of a single `.env`, create `.env.local`, `.env.dev`, `.env.uat`, or `.env.prod` from the matching example file and use the profile-aware commands such as `./scripts/build-and-deploy.sh dev`.

Those scripts collect configuration, validate prerequisites, and drive the initial deployment path.

## Existing onboarding material

These original repo documents are still useful:

- [First Clone Setup](./first-clone-setup.md)
- `START_HERE.md`
- `scripts/INITIALIZATION_GUIDE.md`
- [./INITIALIZATION_SYSTEM.md](./INITIALIZATION_SYSTEM.md)
- [./ENVIRONMENT_SETUP.md](./ENVIRONMENT_SETUP.md)

## Primary audiences

### Engineers evaluating the repo

Start with:

- [What This App Does](./what-this-app-does.md)
- [Repo Structure](./repo-structure.md)
- [Components](./components.md)

### Developers customizing the example

Start with:

- [Components](./components.md)
- [Runtime Flow](./runtime-flow.md)
- [Customization Guide](./customization-guide.md)

### Platform engineers deploying the system

Start with:

- [First Clone Setup](./first-clone-setup.md)
- [Deployment Overview](./deployment-overview.md)
- [Plugin Registration](./plugin-registration.md)
- [Reference](./reference.md)