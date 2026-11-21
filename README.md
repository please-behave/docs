# Docs

[![build](https://github.com/please-behave/docs/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/please-behave/docs/actions/workflows/ci.yml) [![license](https://img.shields.io/badge/license-PolyForm%20Noncommercial%201.0.0-3949ab.svg)](https://polyformproject.org/licenses/noncommercial/1.0.0/) [![LOC](https://christianpflugradt.github.io/badges-and-stuff/please-behave-docs/loc.svg)](https://christianpflugradt.github.io/badges-and-stuff/)

This repository contains the user documentation for Please Behave. Read the [published documentation](https://please-behave.github.io/docs/).

> Please Behave is in early development and not ready for production use.

It will hold:

- the user documentation of the platform components,
- example setups that combine several components, such as a Docker Compose stack, and
- an integration test that runs these setups.

The purpose and principles of Please Behave, and the requirements and decisions of each component, are in the [Why repository](https://github.com/please-behave/why).

## Build locally

Run `mise install` to install the pinned tools, then `mise run build` to render the book with mdBook and check internal links with Lychee. Open `book/docs/index.html` to browse the result.

Book sources live in `src/`. Edit `src/SUMMARY.md` to change the navigation. Use `mise run test-links` to verify that a broken internal link fails the build.

GitHub Actions builds the book on pull requests and publishes it to GitHub Pages on pushes to `main`.
