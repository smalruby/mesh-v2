#!/opt/homebrew/opt/node/bin/node
import * as cdk from 'aws-cdk-lib/core';
import { MeshV2Stack } from '../lib/mesh-v2-stack';
import * as dotenv from 'dotenv';
import * as path from 'path';

// Load .env file
dotenv.config({ path: path.join(__dirname, '../.env'), override: true });

const app = new cdk.App();

// Stage取得（優先順位: --context stage=..., .envのSTAGE, デフォルト: stg）
const stage = app.node.tryGetContext('stage') || process.env.STAGE || 'stg';
const stackName = stage === 'prod' ? 'MeshV2Stack' : `MeshV2Stack-${stage}`;

new MeshV2Stack(app, stackName, {
  stackName: stackName,
  /* If you don't specify 'env', this stack will be environment-agnostic.
   * Account/Region-dependent features and context lookups will not work,
   * but a single synthesized template can be deployed anywhere. */

  /* Uncomment the next line to specialize this stack for the AWS Account
   * and Region that are implied by the current CLI configuration. */
  // env: { account: process.env.CDK_DEFAULT_ACCOUNT, region: process.env.CDK_DEFAULT_REGION },

  /* Uncomment the next line if you know exactly what Account and Region you
   * want to deploy the stack to. */
  // env: { account: '123456789012', region: 'us-east-1' },

  /* For more information, see https://docs.aws.amazon.com/cdk/latest/guide/environments.html */
});
