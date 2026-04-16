# Contributing to DX DAM Watermark Example

Thank you for contributing. This repository is intended to be a practical reference implementation for DAM plugin development, so documentation quality, operational clarity, and maintainability matter as much as code changes.

## Code of Conduct

This project follows the guidelines in `CODE_OF_CONDUCT.md`. By participating, you agree to uphold those standards.

## How to Contribute

### Reporting Bugs

Before creating bug reports, please check existing issues. When creating a bug report, include:

- **Clear title and description**
- **Steps to reproduce** the behavior
- **Expected behavior**
- **Actual behavior**
- **Screenshots** (if applicable)
- **Environment details** (OS, Node.js version, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful**
- **List some other projects** where this enhancement exists, if applicable

### Pull Requests

1. Fork the repository and branch from `main`.
2. Make the smallest coherent change that solves the problem.
3. Update docs when behavior, setup, or operations change.
4. Add or update tests when code behavior changes.
5. Run the relevant validation commands.
6. Submit a pull request with a clear explanation of the change.

## Development Process

### Setting Up Development Environment

```bash
# Clone your fork
git clone https://github.com/your-username/dx-dam-watermark-example.git
cd dx-dam-watermark-example

# Install dependencies
npm install

# Create a branch
git checkout -b feature/my-feature
```

### Validation

```bash
# Lint code
npm run lint

# Run tests
npm test

# Build docs
npm run docs:build
```

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
feat: add support for video processing
fix: resolve callback timeout issue
docs: update API documentation
test: add unit tests for plugin service
chore: update dependencies
```

### Documentation

- Update README.md for user-facing changes
- Update docs/ for detailed documentation
- Keep published docs aligned with repo behavior and workflows

## Project Structure

```
dx-dam-watermark-example/
├── packages/server-v1/src/
│   ├── controllers/      # Add new controllers here
│   ├── services/         # Add business logic here
│   ├── models/          # Add data models here
│   └── __tests__/       # Add tests here
├── docs/                # Add documentation here
├── kubernetes/          # Add K8s manifests here
└── scripts/            # Add utility scripts here
```

## Coding Guidelines

### TypeScript

- Use TypeScript for all new code
- Define interfaces for data structures
- Use proper types (avoid `any`)
- Add JSDoc comments for public APIs

### Error Handling

- Use proper error types from `@loopback/rest`
- Log errors with appropriate context
- Provide meaningful error messages

### Testing

- Write unit tests for services
- Write integration tests for controllers
- Aim for >80% code coverage
- Mock external dependencies

### Security

- Never commit secrets or API keys
- Use environment variables for configuration
- Validate all user inputs
- Follow OWASP security guidelines

## Questions?

Open an issue for general questions or use the guidance in `SUPPORT.md`.

## License

By contributing, you agree that your contributions will be licensed under the Apache License, Version 2.0.
