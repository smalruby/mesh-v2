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

  test('Polling Resolvers and Environment Variables', () => {
    const app = new cdk.App();
    const stack = new MeshV2.MeshV2Stack(app, 'MyTestStack', {
      env: { account: '123456789012', region: 'us-east-1' }
    });
    const template = Template.fromStack(stack);

    // Environment Variables
    template.hasResourceProperties('AWS::AppSync::GraphQLApi', {
      EnvironmentVariables: {
        MESH_EVENT_TTL_SECONDS: '10',
        MESH_POLLING_INTERVAL_SECONDS: '2'
      }
    });

    // Resolvers
    // 1. listGroupsByDomain (Unit)
    // 2. listGroupStatuses (Unit)
    // 3. findNodeMetadata (Function for getNodeStatus) -> Wait, this is Function, not Resolver
    // 4. fetchNodeStatus (Function for getNodeStatus) -> Wait, this is Function, not Resolver
    // 5. getNodeStatus (Pipeline Resolver)
    // 6. listNodesInGroup (Unit)
    // 7. createGroup (Pipeline Resolver)
    // 8. joinGroup (Pipeline Resolver)
    // 9. renewHeartbeat (Pipeline Resolver)
    // 10. sendMemberHeartbeat (Pipeline Resolver)
    // 11. reportDataByNode (Pipeline Resolver)
    // 12. fireEventsByNode (Pipeline Resolver)
    // 13. recordEventsByNode (Pipeline Resolver)
    // 14. getEventsSince (Unit)
    // 15. dissolveGroup (Lambda)
    // 16. createDomain (Lambda)
    // 17. leaveGroup (Lambda)
    // Functions are different resources (AWS::AppSync::Function)

    // Let's count Resolvers again:
    // listGroupsByDomain, listGroupStatuses, getNodeStatus, listNodesInGroup, createGroup,
    // joinGroup, renewHeartbeat, sendMemberHeartbeat, reportDataByNode, fireEventsByNode,
    // recordEventsByNode, getEventsSince, dissolveGroup, createDomain, leaveGroup.
    // That's 15.

    template.resourceCountIs('AWS::AppSync::Resolver', 15);

    template.hasResourceProperties('AWS::AppSync::Resolver', {
      FieldName: 'recordEventsByNode',
      TypeName: 'Mutation'
    });

    template.hasResourceProperties('AWS::AppSync::Resolver', {
      FieldName: 'getEventsSince',
      TypeName: 'Query'
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
