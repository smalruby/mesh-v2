import * as cdk from 'aws-cdk-lib/core';
import { Template } from 'aws-cdk-lib/assertions';
import * as MeshV2 from '../lib/mesh-v2-stack';

describe('MeshV2Stack', () => {
  test('AppSync API and DynamoDB Table Created', () => {
    const app = new cdk.App();
    const stack = new MeshV2.MeshV2Stack(app, 'MyTestStack', {
      env: { account: '123456789012', region: 'us-east-1' }
    });
    const template = Template.fromStack(stack);

    template.hasResourceProperties('AWS::DynamoDB::Table', {
      TableName: 'MeshV2Table-stg'
    });

    template.hasResourceProperties('AWS::AppSync::GraphQLApi', {
      Name: 'MeshV2Api-stg'
    });
  });

  test('WAF is created when stage is prod', () => {
    const app = new cdk.App({
      context: {
        stage: 'prod'
      }
    });
    const stack = new MeshV2.MeshV2Stack(app, 'MyProdTestStack', {
      env: { account: '123456789012', region: 'us-east-1' }
    });
    const template = Template.fromStack(stack);

    template.resourceCountIs('AWS::WAFv2::WebACL', 1);
    template.hasResourceProperties('AWS::WAFv2::WebACL', {
      DefaultAction: { Block: {} },
      Scope: 'REGIONAL',
      Rules: [
        {
          Name: 'AllowSpecificOrigins',
          Priority: 1,
          Action: { Allow: {} },
          Statement: {
            OrStatement: {
              Statements: [
                {
                  ByteMatchStatement: {
                    FieldToMatch: {
                      SingleHeader: { name: 'origin' }
                    },
                    PositionalConstraint: 'EXACTLY',
                    SearchString: 'https://smalruby.app',
                    TextTransformations: [
                      {
                        Priority: 0,
                        Type: 'LOWERCASE'
                      }
                    ]
                  }
                },
                {
                  ByteMatchStatement: {
                    FieldToMatch: {
                      SingleHeader: { name: 'origin' }
                    },
                    PositionalConstraint: 'EXACTLY',
                    SearchString: 'https://smalruby.jp',
                    TextTransformations: [
                      {
                        Priority: 0,
                        Type: 'LOWERCASE'
                      }
                    ]
                  }
                }
              ]
            }
          }
        }
      ]
    });

    template.resourceCountIs('AWS::WAFv2::WebACLAssociation', 1);
  });

  test('WAF is not created when stage is stg', () => {
    const app = new cdk.App({
      context: {
        stage: 'stg'
      }
    });
    const stack = new MeshV2.MeshV2Stack(app, 'MyStgTestStack', {
      env: { account: '123456789012', region: 'us-east-1' }
    });
    const template = Template.fromStack(stack);

    template.resourceCountIs('AWS::WAFv2::WebACL', 0);
    template.resourceCountIs('AWS::WAFv2::WebACLAssociation', 0);
  });
});
