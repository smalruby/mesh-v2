# Mesh v2

AWS AppSync GraphQL backend for Smalruby 3.0 Mesh extension.

## Overview

Mesh v2 is a cloud-based backend system that enables real-time data sharing and event notification between multiple clients (Nodes) within Groups. It replaces the existing Mesh extension's SkyWay-based P2P architecture with a scalable AWS AppSync GraphQL API.

## Architecture

- **AWS AppSync**: GraphQL API with real-time subscriptions
- **Amazon DynamoDB**: NoSQL database for Groups, Nodes, and NodeStatus
- **AWS Lambda**: Serverless functions for complex business logic (e.g., group dissolution)
- **TypeScript CDK**: Infrastructure as Code

## Key Concepts

- **Domain**: Scope for group discovery (auto: global IP, manual: custom string)
- **Group**: Container for Nodes with shared data
- **Node**: Abstract client (sensor, browser tab, etc.)
- **NodeStatus**: Latest data from a Node
- **Event**: Notification payload fired by Nodes

## Performance Requirements

- **Max Clients**: 40 nodes/group
- **Concurrent Groups**: 10 groups
- **Data Update Rate**: 15 updates/sec/group
- **Event Rate**: 2 events/sec/group
- **Total Write Load**: 170 TPS

## Setup

### Prerequisites

- Node.js 18+ and npm
- AWS CLI configured with credentials
- AWS CDK CLI: `npm install -g aws-cdk`

### Installation

```bash
npm install
```

### Build

```bash
npm run build
```

### Deploy

```bash
# Bootstrap CDK (first time only)
cdk bootstrap

# Deploy stack
cdk deploy
```

## Useful Commands

- `npm run build` - Compile TypeScript to JavaScript
- `npm run watch` - Watch for changes and compile
- `npm run test` - Perform Jest unit tests
- `npx cdk deploy` - Deploy this stack to your AWS account/region
- `npx cdk diff` - Compare deployed stack with current state
- `npx cdk synth` - Emits the synthesized CloudFormation template

## Project Structure

```
mesh-v2/
├── bin/
│   └── mesh-v2.ts          # CDK app entry point
├── lib/
│   └── mesh-v2-stack.ts    # Main stack definition
├── graphql/
│   └── schema.graphql      # GraphQL schema
├── js/
│   └── resolvers/          # AppSync JavaScript resolvers
├── lambda/
│   └── leave_group_logic/  # Lambda functions
└── test/
    └── mesh-v2.test.ts     # Unit tests
```

## Related

- EPIC Issue: [smalruby/smalruby3-gui#444](https://github.com/smalruby/smalruby3-gui/issues/444)
- Phase 1-1: [smalruby/smalruby3-gui#446](https://github.com/smalruby/smalruby3-gui/issues/446)

## License

MIT
