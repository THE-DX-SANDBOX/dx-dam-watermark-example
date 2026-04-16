# What This App Does

This repository demonstrates how to build a custom HCL DAM rendition plugin with a companion UI and a Kubernetes-hosted backend service.

## The business example

The example implementation focuses on watermarking digital assets. It shows how an organization can:

- define watermark specifications
- manage watermark layers and layout rules
- process incoming assets through a DAM plugin callback flow
- return transformed results back into DAM

That makes the example concrete, but the repo is intended to be reused for other custom DAM processing scenarios as well.

## The technical example

The repo provides a reference implementation for a plugin-based solution with four major concerns:

- a backend API that performs processing and exposes operational endpoints
- a React-based Script Portlet for configuration and management
- a shared package for contracts and deterministic tiling math
- deployment and registration automation for Kubernetes, DX Portal, and DAM

## What the example is supposed to teach

The example is meant to teach these patterns:

1. How to structure a monorepo that contains UI, API, shared logic, and operational assets.
2. How to implement the DAM plugin request and callback model.
3. How to keep frontend preview logic and backend rendering logic aligned through a shared package.
4. How to automate deployment and DAM registration instead of relying on ad hoc manual steps.

## What it is not

This repo should not be read as just a one-off watermark demo. It is closer to a reusable starter and reference architecture for building enterprise DAM plugins on top of HCL DX-related tooling and delivery practices.