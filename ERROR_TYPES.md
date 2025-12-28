# Mesh V2 GraphQL Error Types

This document lists the GraphQL error types returned by the Mesh V2 backend and the expected behavior for the client.

## Error Type Reference

| Error Type | Description | Client Action | Defined In |
| :--- | :--- | :--- | :--- |
| `GroupNotFound` | The group does not exist, has expired, or the host's heartbeat has timed out. | **Disconnect immediately.** | `js/functions/checkGroupExists.js` |
| `Unauthorized` | An operation was attempted by a node that is not authorized (e.g., a non-host trying to renew the group heartbeat). | **Disconnect immediately.** | `js/functions/renewHeartbeatFunction.js` |
| `NodeNotFound` | The specified node (client) does not exist in the group. | **Disconnect immediately.** | `js/functions/updateNodeTTL.js` |
| `ValidationError` | The provided parameters failed validation (e.g., domain string too long). | Log the error and continue (do **NOT** disconnect). | Various resolvers |

## Implementation Details

The client (`scratch-vm`) implements a `shouldDisconnectOnError(error)` helper method in `MeshV2Service` to handle these errors.

### Disconnect logic in `mesh-service.js`

```javascript
const DISCONNECT_ERROR_TYPES = new Set([
    'GroupNotFound',
    'Unauthorized',
    'NodeNotFound'
]);

shouldDisconnectOnError (error) {
    if (!error) return false;

    // Primary check: GraphQL errorType (most reliable)
    if (error.graphQLErrors && error.graphQLErrors.length > 0) {
        const errorType = error.graphQLErrors[0].errorType;
        if (DISCONNECT_ERROR_TYPES.has(errorType)) {
            return true;
        }
    }

    // Fallback: check message string (backward compatibility)
    if (error.message) {
        const message = error.message.toLowerCase();
        if (message.includes('not found') ||
            message.includes('expired') ||
            message.includes('unauthorized')) {
            return true;
        }
    }

    return false;
}
```

## Adding New Error Types

When adding a new error type to the backend that requires the client to disconnect:

1.  Define the error in the appropriate AppSync function using `util.error(message, errorType)`.
2.  Add the new error type to this documentation.
3.  Update the `DISCONNECT_ERROR_TYPES` set in `gui/scratch-vm/src/extensions/scratch3_mesh_v2/mesh-service.js`.
