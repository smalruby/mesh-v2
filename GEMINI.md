# Mesh v2 Development Guide

## Project Overview

Mesh v2 is the backend infrastructure for the Smalruby 3.0 Mesh extension, enabling real-time data sharing and event notification between multiple clients (Nodes) within Groups. It replaces the previous SkyWay-based P2P architecture with a scalable, AWS-native serverless system.

### Tech Stack
-   **Infrastructure as Code:** AWS CDK (TypeScript)
-   **API:** AWS AppSync (GraphQL)
-   **Database:** Amazon DynamoDB
-   **Compute (Logic):** AWS Lambda (Ruby 3.4) & AppSync JS Resolvers

## Directory Structure

-   `bin/mesh-v2.ts`: CDK application entry point.
-   `lib/mesh-v2-stack.ts`: Main CDK stack definition.
-   `graphql/`: GraphQL schema definitions (`schema.graphql`).
-   `js/`: AppSync JavaScript resolvers and functions.
    -   `resolvers/`: Unit resolvers.
    -   `functions/`: AppSync Functions for pipeline resolvers.
-   `lambda/`: Lambda function source code (Ruby).
    -   `handlers/`: Lambda entry points.
    -   `domain/`, `use_cases/`, `repositories/`: Application logic.
-   `spec/`: RSpec tests for Ruby code.
-   `test/`: Jest tests for CDK infrastructure.

## Development Setup

### Prerequisites
-   Node.js 18+
-   Ruby 3.4.1 (managed via `.ruby-version`)
-   AWS CLI configured
-   AWS CDK CLI

### Installation

1.  **Node.js dependencies:**
    ```bash
    npm install
    ```

2.  **Ruby dependencies:**
    ```bash
    bundle install
    ```

## Build & Deploy Commands

### Build
Compile TypeScript to JavaScript:
```bash
npm run build
```

### Testing
-   **Infrastructure Tests (Jest):**
    ```bash
    npm test
    ```
-   **Lambda Logic Tests (RSpec):**
    ```bash
    bundle exec rspec
    ```
-   **Linting (Standard Ruby):**
    ```bash
    bundle exec standardrb
    ```

### Deployment
...
## Development Conventions

-   **Environment Management:** Resources are suffixed with the stage name (e.g., `MeshV2Table-stg`) and tagged appropriately.
-   **API Development:**
    -   Modify `graphql/schema.graphql` first.
    -   Implement simple logic using AppSync JS (`js/`).
    -   Implement complex logic using Ruby Lambda (`lambda/`).
-   **Lambda Runtime:** Uses Ruby 3.4. Ensure local development matches this version.
-   **Testing & Quality:**
    -   Unit test business logic in Ruby using RSpec.
    -   Unit test infrastructure configuration in TypeScript using Jest.
    -   **CRITICAL:** All Ruby code MUST pass `standardrb` linting. Run `bundle exec standardrb` before committing.

## Key Documentation
-   `README.md`: General project overview.
-   `DEPLOYMENT.md`: Comprehensive guide on deploying, verifying, and managing the infrastructure.
-   `SUBSCRIPTIONS.md`: Details on GraphQL subscription behaviors.
