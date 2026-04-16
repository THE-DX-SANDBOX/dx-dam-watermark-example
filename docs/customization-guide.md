# Customization Guide

The repository is intended to be customized. The watermark example provides the pattern, not the only acceptable behavior.

## Customize the backend processing

Start in `packages/server-v1`.

This is where you change:

- the DAM processing behavior
- business rules for transforming or analyzing assets
- persistence and API behavior

## Customize the user interface

Start in `packages/portlet-v1`.

This is where you change:

- the pages and editing flows
- the user-facing configuration experience
- the data entry model for the example app

## Customize shared domain contracts

Start in `packages/shared`.

This is where you change:

- shared TypeScript models
- deterministic calculations needed by both the UI and backend

## Customize plugin identity and deployment defaults

Start with:

- `plugin-config.json`
- `scripts/init-plugin.sh`
- `scripts/init-template.sh`

This is where you change:

- plugin name and metadata
- integration defaults
- deployment configuration generated during initialization

## Decide what is example-specific

When adapting the repo, separate these concerns:

- reusable platform and deployment structure
- DAM integration contract requirements
- example-specific watermarking behavior and UI

That separation makes it easier to preserve the template value while replacing the demo-specific implementation.