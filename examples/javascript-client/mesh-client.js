/**
 * Mesh v2 Client Library
 * Pure JavaScript GraphQL client for AWS AppSync
 * No external dependencies - uses native fetch and WebSocket APIs
 */

class MeshClient {
  constructor(config) {
    this.endpoint = config.endpoint;
    this.apiKey = config.apiKey;
    this.domain = config.domain || null;
    this.connected = false;
    this.subscriptions = new Map();
    this.eventHandlers = new Map();
  }

  /**
   * Execute GraphQL query or mutation
   */
  async execute(query, variables = {}) {
    try {
      const response = await fetch(this.endpoint, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': this.apiKey
        },
        body: JSON.stringify({ query, variables })
      });

      const result = await response.json();

      if (result.errors) {
        throw new Error(result.errors[0].message);
      }

      return result.data;
    } catch (error) {
      console.error('GraphQL execution error:', error);
      throw error;
    }
  }

  /**
   * Create a new group
   */
  async createGroup(name, hostId, domain) {
    const query = `
      mutation CreateGroup($name: String!, $hostId: ID!, $domain: String!) {
        createGroup(name: $name, hostId: $hostId, domain: $domain) {
          id
          domain
          fullId
          name
          hostId
          createdAt
        }
      }
    `;

    const data = await this.execute(query, {
      name,
      hostId,
      domain: domain || this.domain
    });

    return data.createGroup;
  }

  /**
   * List groups by domain
   */
  async listGroupsByDomain(domain) {
    const query = `
      query ListGroupsByDomain($domain: String!) {
        listGroupsByDomain(domain: $domain) {
          id
          domain
          fullId
          name
          hostId
          createdAt
        }
      }
    `;

    const data = await this.execute(query, {
      domain: domain || this.domain
    });

    return data.listGroupsByDomain;
  }

  /**
   * Join a group
   */
  async joinGroup(groupId, nodeId, domain) {
    const query = `
      mutation JoinGroup($groupId: ID!, $nodeId: ID!, $domain: String!) {
        joinGroup(groupId: $groupId, nodeId: $nodeId, domain: $domain) {
          id
          name
          groupId
          domain
        }
      }
    `;

    const data = await this.execute(query, {
      groupId,
      nodeId,
      domain: domain || this.domain
    });

    return data.joinGroup;
  }

  /**
   * Dissolve a group (host only)
   */
  async dissolveGroup(groupId, hostId, domain) {
    const query = `
      mutation DissolveGroup($groupId: ID!, $hostId: ID!, $domain: String!) {
        dissolveGroup(groupId: $groupId, hostId: $hostId, domain: $domain) {
          groupId
          domain
          message
        }
      }
    `;

    const data = await this.execute(query, {
      groupId,
      hostId,
      domain: domain || this.domain
    });

    return data.dissolveGroup;
  }

  /**
   * Report sensor data
   */
  async reportDataByNode(nodeId, groupId, domain, data) {
    const query = `
      mutation ReportDataByNode($nodeId: ID!, $groupId: ID!, $domain: String!, $data: [SensorDataInput!]!) {
        reportDataByNode(nodeId: $nodeId, groupId: $groupId, domain: $domain, data: $data) {
          nodeId
          groupId
          data {
            key
            value
          }
          timestamp
        }
      }
    `;

    const result = await this.execute(query, {
      nodeId,
      groupId,
      domain: domain || this.domain,
      data
    });

    return result.reportDataByNode;
  }

  /**
   * Fire an event
   */
  async fireEventByNode(nodeId, groupId, domain, eventName, payload) {
    const query = `
      mutation FireEventByNode($nodeId: ID!, $groupId: ID!, $domain: String!, $eventName: String!, $payload: String) {
        fireEventByNode(nodeId: $nodeId, groupId: $groupId, domain: $domain, eventName: $eventName, payload: $payload) {
          name
          firedByNodeId
          groupId
          domain
          payload
          timestamp
        }
      }
    `;

    const result = await this.execute(query, {
      nodeId,
      groupId,
      domain: domain || this.domain,
      eventName,
      payload
    });

    return result.fireEventByNode;
  }

  /**
   * Subscribe to sensor data updates
   * Note: WebSocket subscriptions require additional setup
   * For prototype, we'll use polling as a fallback
   */
  subscribeToDataUpdates(groupId, domain, callback) {
    console.log('Subscription: onDataUpdateInGroup', { groupId, domain });

    // Store callback for later use
    const subscriptionId = `data-${groupId}`;
    this.eventHandlers.set(subscriptionId, callback);

    // For prototype: poll for updates every 2 seconds
    const pollInterval = setInterval(async () => {
      // In a real implementation, this would use WebSocket subscriptions
      // For now, we'll just log that we're subscribed
      console.log('Polling for data updates...');
    }, 2000);

    this.subscriptions.set(subscriptionId, pollInterval);

    return subscriptionId;
  }

  /**
   * Subscribe to events in group
   */
  subscribeToEvents(groupId, domain, callback) {
    console.log('Subscription: onEventInGroup', { groupId, domain });

    // Store callback for later use
    const subscriptionId = `event-${groupId}`;
    this.eventHandlers.set(subscriptionId, callback);

    // For prototype: poll for events every 2 seconds
    const pollInterval = setInterval(async () => {
      console.log('Polling for events...');
    }, 2000);

    this.subscriptions.set(subscriptionId, pollInterval);

    return subscriptionId;
  }

  /**
   * Subscribe to group dissolution
   */
  subscribeToGroupDissolve(groupId, domain, callback) {
    console.log('Subscription: onGroupDissolve', { groupId, domain });

    const subscriptionId = `dissolve-${groupId}`;
    this.eventHandlers.set(subscriptionId, callback);

    return subscriptionId;
  }

  /**
   * Unsubscribe from a subscription
   */
  unsubscribe(subscriptionId) {
    if (this.subscriptions.has(subscriptionId)) {
      clearInterval(this.subscriptions.get(subscriptionId));
      this.subscriptions.delete(subscriptionId);
    }
    this.eventHandlers.delete(subscriptionId);
  }

  /**
   * Disconnect and cleanup
   */
  disconnect() {
    // Clear all subscriptions
    for (const [id, interval] of this.subscriptions.entries()) {
      clearInterval(interval);
    }
    this.subscriptions.clear();
    this.eventHandlers.clear();
    this.connected = false;
  }
}

/**
 * Rate limiter utility
 */
class RateLimiter {
  constructor(maxCalls, timeWindow) {
    this.maxCalls = maxCalls;
    this.timeWindow = timeWindow; // in milliseconds
    this.calls = [];
  }

  canMakeCall() {
    const now = Date.now();
    // Remove old calls outside the time window
    this.calls = this.calls.filter(time => now - time < this.timeWindow);

    if (this.calls.length < this.maxCalls) {
      this.calls.push(now);
      return true;
    }

    return false;
  }

  getCallCount() {
    const now = Date.now();
    this.calls = this.calls.filter(time => now - time < this.timeWindow);
    return this.calls.length;
  }

  reset() {
    this.calls = [];
  }
}

/**
 * Change detector for sensor data
 */
class ChangeDetector {
  constructor() {
    this.previousValues = new Map();
  }

  hasChanged(key, value) {
    const previous = this.previousValues.get(key);
    const changed = previous !== value;

    if (changed) {
      this.previousValues.set(key, value);
    }

    return changed;
  }

  reset() {
    this.previousValues.clear();
  }
}
