import * as cdk from 'aws-cdk-lib/core';
import * as dynamodb from 'aws-cdk-lib/aws-dynamodb';
import { Construct } from 'constructs';

export class MeshV2Stack extends cdk.Stack {
  public readonly table: dynamodb.Table;

  constructor(scope: Construct, id: string, props?: cdk.StackProps) {
    super(scope, id, props);

    // DynamoDB Table for Mesh v2
    this.table = new dynamodb.Table(this, 'MeshV2Table', {
      tableName: 'MeshV2Table',
      partitionKey: {
        name: 'pk',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'sk',
        type: dynamodb.AttributeType.STRING,
      },
      billingMode: dynamodb.BillingMode.PAY_PER_REQUEST,
      removalPolicy: cdk.RemovalPolicy.DESTROY, // For development only
      pointInTimeRecoverySpecification: {
        pointInTimeRecoveryEnabled: false, // Disable for cost optimization in dev
      },
    });

    // GSI: GroupIdIndex for reverse lookup (groupId -> domain)
    this.table.addGlobalSecondaryIndex({
      indexName: 'GroupIdIndex',
      partitionKey: {
        name: 'gsi_pk',
        type: dynamodb.AttributeType.STRING,
      },
      sortKey: {
        name: 'gsi_sk',
        type: dynamodb.AttributeType.STRING,
      },
      projectionType: dynamodb.ProjectionType.ALL,
    });

    // Output table name
    new cdk.CfnOutput(this, 'TableName', {
      value: this.table.tableName,
      description: 'DynamoDB table name for Mesh v2',
    });

    // Output table ARN
    new cdk.CfnOutput(this, 'TableArn', {
      value: this.table.tableArn,
      description: 'DynamoDB table ARN for Mesh v2',
    });
  }
}
