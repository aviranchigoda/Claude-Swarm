# Low-Level Background Task Control System for Claude Code + Opus 4.5

## Executive Summary

This document specifies a comprehensive low-level engineering system to maximize developer control over background tasks in Claude Code powered by Opus 4.5. The architecture provides fine-grained control at every layer of task execution.

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Core Runtime Components](#2-core-runtime-components)
3. [Agent SDK Deep Dive](#3-agent-sdk-deep-dive)
4. [MCP Server Architecture](#4-mcp-server-architecture)
5. [Hooks System Engineering](#5-hooks-system-engineering)
6. [Task Orchestration Engine](#6-task-orchestration-engine)
7. [State Management Subsystem](#7-state-management-subsystem)
8. [Resource Governance Layer](#8-resource-governance-layer)
9. [Observability Infrastructure](#9-observability-infrastructure)
10. [Security Architecture](#10-security-architecture)
11. [Implementation Patterns](#11-implementation-patterns)
12. [Verification Strategy](#12-verification-strategy)

---

## 1. System Architecture Overview

### 1.1 Layered Architecture Model

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         DEVELOPER INTERFACE LAYER                            │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │   CLI API   │  │  REST API   │  │  SDK Calls  │  │  Configuration UI   │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         ORCHESTRATION LAYER                                  │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ Task Scheduler  │  │ Priority Queue  │  │   Dependency Resolver       │  │
│  │                 │  │                 │  │                             │  │
│  │ - FIFO/LIFO     │  │ - Heap-based    │  │ - DAG execution             │  │
│  │ - Priority      │  │ - Multi-level   │  │ - Cycle detection           │  │
│  │ - Fair-share    │  │ - Aging support │  │ - Parallel branch execution │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         AGENT EXECUTION LAYER                                │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │                      Agent Runtime Environment                       │    │
│  │  ┌───────────────┐  ┌───────────────┐  ┌───────────────────────┐   │    │
│  │  │ Agent Context │  │ Tool Registry │  │ Execution Controller  │   │    │
│  │  │               │  │               │  │                       │   │    │
│  │  │ - Memory      │  │ - Built-in    │  │ - Turn management     │   │    │
│  │  │ - State       │  │ - Custom MCP  │  │ - Token tracking      │   │    │
│  │  │ - History     │  │ - Hooks       │  │ - Timeout handling    │   │    │
│  │  └───────────────┘  └───────────────┘  └───────────────────────┘   │    │
│  └─────────────────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INTERCEPTION LAYER                                   │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │   Pre-Hooks     │  │  Tool Router    │  │      Post-Hooks             │  │
│  │                 │  │                 │  │                             │  │
│  │ - Validation    │  │ - Load balance  │  │ - Result transformation    │  │
│  │ - Transform     │  │ - Failover      │  │ - Caching                  │  │
│  │ - Auth check    │  │ - Circuit break │  │ - Audit logging            │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TOOL EXECUTION LAYER                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────┐ │
│  │    Bash     │  │    Read     │  │    Edit     │  │    MCP Tools        │ │
│  │  Executor   │  │  Executor   │  │  Executor   │  │    (Custom)         │ │
│  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
                                      │
                                      ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         INFRASTRUCTURE LAYER                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │ State Storage   │  │  Message Queue  │  │   Metrics/Telemetry         │  │
│  │                 │  │                 │  │                             │  │
│  │ - SQLite        │  │ - In-process    │  │ - OpenTelemetry             │  │
│  │ - Redis         │  │ - Redis Streams │  │ - Prometheus                │  │
│  │ - PostgreSQL    │  │ - Kafka         │  │ - Custom collectors         │  │
│  └─────────────────┘  └─────────────────┘  └─────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 1.2 Data Flow Architecture

```
┌──────────────────────────────────────────────────────────────────────────────┐
│                            REQUEST LIFECYCLE                                  │
└──────────────────────────────────────────────────────────────────────────────┘

Developer Request
       │
       ▼
┌──────────────────┐
│  Request Parser  │ ─────► Validates schema, extracts parameters
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Task Classifier  │ ─────► Determines: agent type, priority, resource needs
└──────────────────┘
       │
       ▼
┌──────────────────┐
│  Queue Manager   │ ─────► Assigns to appropriate priority queue
└──────────────────┘
       │
       ▼
┌──────────────────┐
│   Scheduler      │ ─────► Selects next task based on policy
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Agent Spawner    │ ─────► Creates agent instance with context
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Execution Loop   │◄─────┐
│                  │      │
│  1. Get prompt   │      │
│  2. Call Opus4.5 │      │ Iterate until:
│  3. Parse tools  │      │ - Task complete
│  4. Execute tools│      │ - Max turns reached
│  5. Update state │──────┘ - Error/timeout
└──────────────────┘
       │
       ▼
┌──────────────────┐
│ Result Handler   │ ─────► Formats output, triggers callbacks
└──────────────────┘
       │
       ▼
┌──────────────────┐
│  State Persister │ ─────► Saves final state for resume capability
└──────────────────┘
```

---

## 2. Core Runtime Components

### 2.1 Process Manager

The Process Manager handles lifecycle of all background task processes.

```typescript
// Core Process Manager Interface
interface ProcessManager {
  // Process lifecycle
  spawn(config: ProcessConfig): Promise<ProcessHandle>;
  kill(pid: ProcessId, signal?: Signal): Promise<void>;
  suspend(pid: ProcessId): Promise<void>;
  resume(pid: ProcessId): Promise<void>;

  // Process queries
  list(filter?: ProcessFilter): Promise<ProcessInfo[]>;
  get(pid: ProcessId): Promise<ProcessInfo | null>;
  getMetrics(pid: ProcessId): Promise<ProcessMetrics>;

  // Bulk operations
  killAll(filter?: ProcessFilter): Promise<void>;
  suspendAll(filter?: ProcessFilter): Promise<void>;
}

interface ProcessConfig {
  // Identification
  id?: string;                    // Optional custom ID
  name: string;                   // Human-readable name
  tags: Record<string, string>;   // Metadata tags for filtering

  // Agent configuration
  agentType: AgentType;           // 'bash' | 'explore' | 'plan' | 'custom'
  prompt: string;                 // Initial prompt
  model?: ModelId;                // Override model (default: opus-4.5)

  // Resource limits
  limits: ResourceLimits;

  // Execution settings
  maxTurns?: number;              // Max API round-trips
  timeout?: number;               // Total timeout in ms
  workingDirectory?: string;      // CWD for file operations
  environment?: Record<string, string>;  // Environment variables

  // Background settings
  runInBackground: boolean;
  outputFile?: string;            // File path for output streaming

  // Callbacks
  onProgress?: (event: ProgressEvent) => void;
  onComplete?: (result: TaskResult) => void;
  onError?: (error: TaskError) => void;
}

interface ResourceLimits {
  // Token limits
  maxInputTokens?: number;        // Per-turn input limit
  maxOutputTokens?: number;       // Per-turn output limit
  maxTotalTokens?: number;        // Total token budget

  // Compute limits
  maxCpuPercent?: number;         // CPU usage cap (0-100)
  maxMemoryMb?: number;           // Memory limit
  maxDiskIoMbps?: number;         // Disk I/O limit

  // Time limits
  maxTurnDurationMs?: number;     // Single turn timeout
  maxTotalDurationMs?: number;    // Total task timeout

  // Concurrency limits
  maxParallelTools?: number;      // Parallel tool executions
  maxChildProcesses?: number;     // Spawned subprocess limit
}

interface ProcessHandle {
  pid: ProcessId;
  stdin: WritableStream;          // Send input to process
  stdout: ReadableStream;         // Read output stream
  stderr: ReadableStream;         // Read error stream

  // Control methods
  write(data: string): Promise<void>;
  signal(sig: Signal): Promise<void>;
  waitForExit(): Promise<ExitResult>;

  // State queries
  isRunning(): boolean;
  getState(): ProcessState;
  getMetrics(): ProcessMetrics;
}

// Process states with transitions
enum ProcessState {
  INITIALIZING = 'initializing',  // Setting up context
  QUEUED = 'queued',              // Waiting in scheduler
  RUNNING = 'running',            // Actively executing
  SUSPENDED = 'suspended',        // Paused by user/system
  WAITING_INPUT = 'waiting_input',// Blocked on user input
  WAITING_TOOL = 'waiting_tool',  // Blocked on tool execution
  COMPLETING = 'completing',      // Finalizing results
  COMPLETED = 'completed',        // Successfully finished
  FAILED = 'failed',              // Error termination
  KILLED = 'killed',              // User-initiated termination
  TIMED_OUT = 'timed_out'         // Timeout termination
}

// State transition matrix
const VALID_TRANSITIONS: Record<ProcessState, ProcessState[]> = {
  [ProcessState.INITIALIZING]: [
    ProcessState.QUEUED,
    ProcessState.FAILED
  ],
  [ProcessState.QUEUED]: [
    ProcessState.RUNNING,
    ProcessState.KILLED
  ],
  [ProcessState.RUNNING]: [
    ProcessState.SUSPENDED,
    ProcessState.WAITING_INPUT,
    ProcessState.WAITING_TOOL,
    ProcessState.COMPLETING,
    ProcessState.FAILED,
    ProcessState.KILLED,
    ProcessState.TIMED_OUT
  ],
  [ProcessState.SUSPENDED]: [
    ProcessState.RUNNING,
    ProcessState.KILLED
  ],
  [ProcessState.WAITING_INPUT]: [
    ProcessState.RUNNING,
    ProcessState.KILLED,
    ProcessState.TIMED_OUT
  ],
  [ProcessState.WAITING_TOOL]: [
    ProcessState.RUNNING,
    ProcessState.FAILED,
    ProcessState.KILLED,
    ProcessState.TIMED_OUT
  ],
  [ProcessState.COMPLETING]: [
    ProcessState.COMPLETED,
    ProcessState.FAILED
  ],
  // Terminal states - no transitions
  [ProcessState.COMPLETED]: [],
  [ProcessState.FAILED]: [],
  [ProcessState.KILLED]: [],
  [ProcessState.TIMED_OUT]: []
};
```

### 2.2 Memory Architecture

```typescript
// Memory management for agent contexts
interface MemoryManager {
  // Allocation
  allocate(size: number, type: MemoryType): MemoryBlock;
  reallocate(block: MemoryBlock, newSize: number): MemoryBlock;
  free(block: MemoryBlock): void;

  // Context windows
  createContextWindow(config: ContextWindowConfig): ContextWindow;
  compressContext(window: ContextWindow): CompressedContext;
  expandContext(compressed: CompressedContext): ContextWindow;

  // Garbage collection
  gc(strategy?: GCStrategy): GCResult;
  getFragmentation(): number;
}

interface ContextWindow {
  // Window management
  readonly capacity: number;      // Max tokens
  readonly used: number;          // Current usage
  readonly available: number;     // Remaining capacity

  // Content management
  append(content: Message): boolean;
  prepend(content: Message): boolean;
  truncateOldest(tokens: number): Message[];
  truncateNewest(tokens: number): Message[];

  // Summarization
  summarize(strategy: SummarizationStrategy): Promise<Message>;

  // Serialization
  serialize(): SerializedContext;
  static deserialize(data: SerializedContext): ContextWindow;
}

// Context window configuration
interface ContextWindowConfig {
  maxTokens: number;              // Hard limit
  reservedTokens: number;         // Reserved for system prompts

  // Overflow handling
  overflowStrategy: 'truncate_oldest' | 'summarize' | 'error';

  // Prioritization
  messagePriority: {
    system: number;               // System message priority (highest)
    user: number;                 // User message priority
    assistant: number;            // Assistant message priority
    tool_result: number;          // Tool result priority
  };

  // Compression settings
  compressionThreshold: number;   // Trigger compression at this %
  compressionRatio: number;       // Target compression ratio
}

// Memory block for raw allocations
interface MemoryBlock {
  readonly id: string;
  readonly address: number;       // Virtual address
  readonly size: number;          // Allocated size
  readonly type: MemoryType;

  read(offset: number, length: number): Buffer;
  write(offset: number, data: Buffer): void;

  // Memory-mapped operations
  map(): MappedMemory;
  unmap(): void;
}

enum MemoryType {
  CONTEXT = 'context',            // Agent context storage
  TOOL_RESULT = 'tool_result',    // Tool execution results
  STATE = 'state',                // Agent state
  CACHE = 'cache',                // Cached data
  SCRATCH = 'scratch'             // Temporary working memory
}
```

### 2.3 Inter-Process Communication (IPC)

```typescript
// IPC system for agent communication
interface IPCManager {
  // Channel management
  createChannel(config: ChannelConfig): IPCChannel;
  getChannel(name: string): IPCChannel | null;
  destroyChannel(name: string): void;

  // Direct messaging
  send(target: ProcessId, message: IPCMessage): Promise<void>;
  broadcast(message: IPCMessage, filter?: ProcessFilter): Promise<void>;

  // Request-response
  request(target: ProcessId, request: IPCRequest): Promise<IPCResponse>;

  // Pub-sub
  subscribe(topic: string, handler: MessageHandler): Subscription;
  publish(topic: string, message: IPCMessage): Promise<void>;
}

interface IPCChannel {
  readonly name: string;
  readonly type: ChannelType;

  // Bidirectional communication
  send(message: IPCMessage): Promise<void>;
  receive(): AsyncIterator<IPCMessage>;

  // Flow control
  pause(): void;
  resume(): void;

  // Lifecycle
  close(): void;
  readonly closed: boolean;
}

enum ChannelType {
  PIPE = 'pipe',                  // Unidirectional byte stream
  SOCKET = 'socket',              // Bidirectional message stream
  SHARED_MEMORY = 'shared_memory',// Direct memory sharing
  MESSAGE_QUEUE = 'message_queue' // Persistent queue
}

interface ChannelConfig {
  name: string;
  type: ChannelType;

  // Buffer settings
  bufferSize?: number;            // In-memory buffer size
  maxPendingMessages?: number;    // Max queued messages

  // Persistence
  persistent?: boolean;           // Survive process restart
  persistencePath?: string;       // Storage location

  // Security
  allowedProcesses?: ProcessId[]; // Whitelist
  encryption?: EncryptionConfig;
}

// Message format
interface IPCMessage {
  id: string;
  timestamp: number;
  source: ProcessId;
  type: MessageType;
  payload: unknown;

  // Routing
  correlationId?: string;         // For request-response
  replyTo?: string;               // Reply channel

  // Metadata
  priority?: number;
  ttl?: number;                   // Time-to-live in ms
  headers?: Record<string, string>;
}

enum MessageType {
  // Control messages
  PING = 'ping',
  PONG = 'pong',
  SHUTDOWN = 'shutdown',
  SUSPEND = 'suspend',
  RESUME = 'resume',

  // Data messages
  TASK_UPDATE = 'task_update',
  STATE_SYNC = 'state_sync',
  RESULT = 'result',
  ERROR = 'error',

  // Coordination
  LOCK_REQUEST = 'lock_request',
  LOCK_GRANT = 'lock_grant',
  LOCK_RELEASE = 'lock_release',

  // Custom
  CUSTOM = 'custom'
}
```

---

## 3. Agent SDK Deep Dive

### 3.1 Agent Lifecycle Architecture

```typescript
// Complete agent lifecycle management
abstract class BaseAgent {
  protected readonly id: AgentId;
  protected readonly config: AgentConfig;
  protected readonly context: AgentContext;
  protected readonly tools: ToolRegistry;

  // Lifecycle hooks - override in subclasses
  protected abstract onInitialize(): Promise<void>;
  protected abstract onBeforeTurn(turn: number): Promise<void>;
  protected abstract onAfterTurn(turn: number, result: TurnResult): Promise<void>;
  protected abstract onToolCall(call: ToolCall): Promise<ToolCallDecision>;
  protected abstract onToolResult(call: ToolCall, result: ToolResult): Promise<void>;
  protected abstract onError(error: AgentError): Promise<ErrorRecovery>;
  protected abstract onComplete(result: AgentResult): Promise<void>;
  protected abstract onTerminate(reason: TerminationReason): Promise<void>;

  // Main execution loop
  async execute(): Promise<AgentResult> {
    await this.onInitialize();
    let turn = 0;

    try {
      while (turn < this.config.maxTurns) {
        await this.onBeforeTurn(turn);

        const turnResult = await this.executeTurn(turn);

        await this.onAfterTurn(turn, turnResult);

        if (turnResult.isComplete) {
          const result = this.buildResult(turnResult);
          await this.onComplete(result);
          return result;
        }

        turn++;
      }

      // Max turns reached
      return this.buildPartialResult('max_turns_reached');
    } catch (error) {
      const recovery = await this.onError(error as AgentError);
      return this.handleRecovery(recovery, error);
    }
  }

  private async executeTurn(turn: number): Promise<TurnResult> {
    // 1. Prepare messages for API call
    const messages = await this.prepareMessages(turn);

    // 2. Call Opus 4.5
    const response = await this.callModel(messages);

    // 3. Parse and execute tool calls
    const toolCalls = this.parseToolCalls(response);
    const toolResults: ToolResult[] = [];

    for (const call of toolCalls) {
      const decision = await this.onToolCall(call);

      if (decision.action === 'execute') {
        const result = await this.executeToolCall(call, decision.modifiedParams);
        await this.onToolResult(call, result);
        toolResults.push(result);
      } else if (decision.action === 'skip') {
        toolResults.push(this.createSkippedResult(call, decision.reason));
      } else if (decision.action === 'substitute') {
        const result = await this.executeToolCall(decision.substituteTool!, decision.modifiedParams);
        await this.onToolResult(call, result);
        toolResults.push(result);
      }
    }

    // 4. Update context
    await this.updateContext(response, toolResults);

    // 5. Check completion
    return {
      turn,
      response,
      toolCalls,
      toolResults,
      isComplete: this.checkCompletion(response, toolResults),
      metrics: this.collectTurnMetrics()
    };
  }
}

// Agent configuration
interface AgentConfig {
  // Identity
  id?: AgentId;
  name: string;
  type: AgentType;

  // Model settings
  model: ModelConfig;

  // Execution limits
  maxTurns: number;
  turnTimeout: number;
  totalTimeout: number;

  // Tool access
  allowedTools: ToolPermissions;
  toolTimeout: number;

  // Context management
  contextConfig: ContextWindowConfig;

  // Behavior flags
  enableAutoRetry: boolean;
  enableCheckpointing: boolean;
  enableParallelTools: boolean;
}

interface ModelConfig {
  modelId: string;                // 'claude-opus-4-5-20251101'
  maxTokens: number;
  temperature?: number;
  topP?: number;
  topK?: number;
  stopSequences?: string[];

  // Thinking mode
  thinkingMode?: 'disabled' | 'enabled' | 'interleaved';
  thinkingBudget?: number;

  // System prompt
  systemPrompt?: string;
  systemPromptTokens?: number;
}

interface ToolPermissions {
  // Whitelist/blacklist
  mode: 'allow_all' | 'allow_list' | 'deny_list';
  tools?: string[];               // Tool names

  // Granular permissions
  permissions: Record<string, ToolPermission>;
}

interface ToolPermission {
  enabled: boolean;

  // Parameter restrictions
  parameterRestrictions?: {
    [param: string]: {
      allowedValues?: unknown[];
      deniedValues?: unknown[];
      pattern?: string;           // Regex for strings
      min?: number;               // For numbers
      max?: number;
    };
  };

  // Rate limiting
  rateLimit?: {
    maxCalls: number;
    windowMs: number;
  };

  // Require approval
  requireApproval?: boolean;
  approvalCallback?: (call: ToolCall) => Promise<boolean>;
}
```

### 3.2 Custom Agent Implementation

```typescript
// Example: Custom agent with full control
class CustomBackgroundAgent extends BaseAgent {
  private stateManager: StateManager;
  private checkpointManager: CheckpointManager;
  private metricsCollector: MetricsCollector;
  private toolRouter: ToolRouter;

  constructor(config: CustomAgentConfig) {
    super(config);
    this.stateManager = new StateManager(config.stateConfig);
    this.checkpointManager = new CheckpointManager(config.checkpointConfig);
    this.metricsCollector = new MetricsCollector(config.metricsConfig);
    this.toolRouter = new ToolRouter(config.routingConfig);
  }

  protected async onInitialize(): Promise<void> {
    // Load previous state if resuming
    if (this.config.resumeFromCheckpoint) {
      await this.loadCheckpoint(this.config.resumeFromCheckpoint);
    }

    // Initialize subsystems
    await this.stateManager.initialize();
    await this.toolRouter.initialize();

    // Register custom tools
    for (const tool of this.config.customTools) {
      this.tools.register(tool);
    }

    // Start metrics collection
    this.metricsCollector.start();

    // Emit initialization event
    this.emit('initialized', { agentId: this.id, timestamp: Date.now() });
  }

  protected async onBeforeTurn(turn: number): Promise<void> {
    // Record turn start
    this.metricsCollector.recordTurnStart(turn);

    // Check resource limits
    const resources = await this.checkResources();
    if (resources.exceeded) {
      throw new ResourceLimitError(resources.details);
    }

    // Create checkpoint before turn
    if (this.config.enableCheckpointing && turn % this.config.checkpointInterval === 0) {
      await this.createCheckpoint(`turn_${turn}_start`);
    }

    // Apply any pending configuration changes
    await this.applyPendingConfig();
  }

  protected async onToolCall(call: ToolCall): Promise<ToolCallDecision> {
    // 1. Validate against permissions
    const permitted = await this.validatePermissions(call);
    if (!permitted.allowed) {
      return { action: 'skip', reason: permitted.reason };
    }

    // 2. Apply rate limiting
    const rateLimited = await this.checkRateLimit(call);
    if (rateLimited.limited) {
      if (rateLimited.retryAfter) {
        await this.sleep(rateLimited.retryAfter);
      } else {
        return { action: 'skip', reason: 'rate_limited' };
      }
    }

    // 3. Route through tool router
    const route = await this.toolRouter.route(call);
    if (route.redirect) {
      return {
        action: 'substitute',
        substituteTool: route.redirectTool,
        modifiedParams: route.modifiedParams
      };
    }

    // 4. Transform parameters if needed
    const transformedParams = await this.transformParams(call, route);

    // 5. Check for approval requirement
    if (this.requiresApproval(call)) {
      const approved = await this.requestApproval(call);
      if (!approved) {
        return { action: 'skip', reason: 'approval_denied' };
      }
    }

    return { action: 'execute', modifiedParams: transformedParams };
  }

  protected async onToolResult(call: ToolCall, result: ToolResult): Promise<void> {
    // Record metrics
    this.metricsCollector.recordToolExecution({
      tool: call.name,
      duration: result.duration,
      success: result.success,
      tokenUsage: result.tokenUsage
    });

    // Cache result if cacheable
    if (this.isCacheable(call)) {
      await this.cacheResult(call, result);
    }

    // Update state
    await this.stateManager.recordToolExecution(call, result);

    // Trigger webhooks
    await this.triggerWebhooks('tool_result', { call, result });
  }

  protected async onError(error: AgentError): Promise<ErrorRecovery> {
    // Log error
    this.metricsCollector.recordError(error);

    // Classify error
    const classification = this.classifyError(error);

    switch (classification.type) {
      case 'transient':
        // Retry with backoff
        return {
          action: 'retry',
          backoff: this.calculateBackoff(classification.retryCount),
          maxRetries: 3
        };

      case 'recoverable':
        // Rollback to last checkpoint and retry
        return {
          action: 'rollback',
          checkpointId: await this.getLastCheckpoint(),
          then: 'retry'
        };

      case 'fatal':
        // Cannot recover, terminate
        return {
          action: 'terminate',
          reason: error.message,
          preserveState: true
        };

      default:
        return { action: 'terminate', reason: 'unknown_error' };
    }
  }

  protected async onComplete(result: AgentResult): Promise<void> {
    // Final metrics
    this.metricsCollector.recordCompletion(result);

    // Persist final state
    await this.stateManager.persistFinalState(result);

    // Create completion checkpoint
    await this.createCheckpoint('completed');

    // Cleanup resources
    await this.cleanup();

    // Trigger completion webhooks
    await this.triggerWebhooks('completed', result);
  }
}

// Error classification
interface ErrorClassification {
  type: 'transient' | 'recoverable' | 'fatal';
  category: ErrorCategory;
  retryCount: number;
  details: Record<string, unknown>;
}

enum ErrorCategory {
  NETWORK = 'network',            // API connectivity issues
  RATE_LIMIT = 'rate_limit',      // API rate limiting
  TOKEN_LIMIT = 'token_limit',    // Context window exceeded
  TOOL_FAILURE = 'tool_failure',  // Tool execution failed
  TIMEOUT = 'timeout',            // Operation timed out
  PERMISSION = 'permission',      // Permission denied
  VALIDATION = 'validation',      // Invalid input/output
  INTERNAL = 'internal'           // Internal agent error
}
```

### 3.3 Agent Composition Patterns

```typescript
// Hierarchical agent composition
class CompositeAgent extends BaseAgent {
  private childAgents: Map<string, BaseAgent> = new Map();
  private coordinator: AgentCoordinator;

  async spawnChild(config: AgentConfig): Promise<AgentHandle> {
    const child = AgentFactory.create(config);
    const handle = new AgentHandle(child);

    this.childAgents.set(child.id, child);
    this.coordinator.register(child);

    // Set up bidirectional communication
    this.setupIPC(child);

    return handle;
  }

  async delegateTask(childId: string, task: Task): Promise<TaskResult> {
    const child = this.childAgents.get(childId);
    if (!child) throw new Error(`Child agent ${childId} not found`);

    // Create task context
    const taskContext = this.createTaskContext(task);

    // Execute on child
    return await child.executeTask(taskContext);
  }

  async coordinateParallel(tasks: Task[]): Promise<TaskResult[]> {
    // Launch all tasks in parallel
    const promises = tasks.map(async (task) => {
      const childId = await this.selectOptimalChild(task);
      return this.delegateTask(childId, task);
    });

    return Promise.all(promises);
  }

  async coordinateSequential(tasks: Task[]): Promise<TaskResult[]> {
    const results: TaskResult[] = [];

    for (const task of tasks) {
      const childId = await this.selectOptimalChild(task);
      const result = await this.delegateTask(childId, task);
      results.push(result);

      // Allow subsequent tasks to use previous results
      this.updateSharedContext(result);
    }

    return results;
  }

  private async selectOptimalChild(task: Task): Promise<string> {
    // Load-based selection
    const loads = await this.coordinator.getChildLoads();

    // Capability matching
    const capable = this.filterByCapability(task.requiredTools);

    // Select least loaded capable agent
    return capable.reduce((best, id) =>
      loads.get(id)! < loads.get(best)! ? id : best
    );
  }
}

// Agent coordination patterns
interface AgentCoordinator {
  // Registration
  register(agent: BaseAgent): void;
  deregister(agentId: string): void;

  // Load balancing
  getChildLoads(): Promise<Map<string, number>>;
  rebalance(): Promise<void>;

  // Synchronization
  acquireLock(resource: string, timeout?: number): Promise<Lock>;
  releaseLock(lock: Lock): Promise<void>;

  // State sharing
  shareState(key: string, value: unknown): Promise<void>;
  getSharedState(key: string): Promise<unknown>;

  // Event coordination
  waitForAll(agentIds: string[], event: string): Promise<void>;
  waitForAny(agentIds: string[], event: string): Promise<string>;
  barrier(agentIds: string[]): Promise<void>;
}
```

---

## 4. MCP Server Architecture

### 4.1 MCP Protocol Deep Dive

```typescript
// MCP Server implementation
class MCPServer {
  private transport: MCPTransport;
  private toolRegistry: Map<string, MCPTool> = new Map();
  private resourceRegistry: Map<string, MCPResource> = new Map();
  private promptRegistry: Map<string, MCPPrompt> = new Map();

  constructor(config: MCPServerConfig) {
    this.transport = this.createTransport(config.transport);
    this.setupHandlers();
  }

  // Tool registration with full metadata
  registerTool(tool: MCPTool): void {
    this.toolRegistry.set(tool.name, tool);
  }

  // Resource registration
  registerResource(resource: MCPResource): void {
    this.resourceRegistry.set(resource.uri, resource);
  }

  // Prompt registration
  registerPrompt(prompt: MCPPrompt): void {
    this.promptRegistry.set(prompt.name, prompt);
  }

  private setupHandlers(): void {
    // Initialize handler
    this.transport.on('initialize', async (params: InitializeParams) => {
      return {
        protocolVersion: '2024-11-05',
        serverInfo: {
          name: this.config.name,
          version: this.config.version
        },
        capabilities: {
          tools: { listChanged: true },
          resources: { subscribe: true, listChanged: true },
          prompts: { listChanged: true },
          logging: {}
        }
      };
    });

    // Tools handlers
    this.transport.on('tools/list', async () => {
      return {
        tools: Array.from(this.toolRegistry.values()).map(t => ({
          name: t.name,
          description: t.description,
          inputSchema: t.inputSchema
        }))
      };
    });

    this.transport.on('tools/call', async (params: ToolCallParams) => {
      const tool = this.toolRegistry.get(params.name);
      if (!tool) {
        throw new MCPError('ToolNotFound', `Tool ${params.name} not found`);
      }

      // Validate input
      this.validateInput(params.arguments, tool.inputSchema);

      // Execute tool
      const result = await tool.execute(params.arguments);

      return {
        content: this.formatContent(result),
        isError: false
      };
    });

    // Resources handlers
    this.transport.on('resources/list', async () => {
      return {
        resources: Array.from(this.resourceRegistry.values()).map(r => ({
          uri: r.uri,
          name: r.name,
          description: r.description,
          mimeType: r.mimeType
        }))
      };
    });

    this.transport.on('resources/read', async (params: ResourceReadParams) => {
      const resource = this.resourceRegistry.get(params.uri);
      if (!resource) {
        throw new MCPError('ResourceNotFound', `Resource ${params.uri} not found`);
      }

      const content = await resource.read();
      return {
        contents: [{
          uri: params.uri,
          mimeType: resource.mimeType,
          text: content
        }]
      };
    });
  }
}

// MCP Tool definition
interface MCPTool {
  name: string;
  description: string;
  inputSchema: JSONSchema;

  // Execution
  execute(params: Record<string, unknown>): Promise<ToolOutput>;

  // Optional hooks
  beforeExecute?(params: Record<string, unknown>): Promise<Record<string, unknown>>;
  afterExecute?(result: ToolOutput): Promise<ToolOutput>;

  // Metadata
  metadata?: {
    category?: string;
    tags?: string[];
    estimatedDuration?: number;
    resourceRequirements?: ResourceRequirements;
  };
}

// Complete tool output types
interface ToolOutput {
  type: 'text' | 'image' | 'resource' | 'error';

  // Text output
  text?: string;

  // Image output
  image?: {
    data: string;                 // Base64 encoded
    mimeType: string;
  };

  // Resource reference
  resource?: {
    uri: string;
    mimeType: string;
  };

  // Error output
  error?: {
    code: string;
    message: string;
    details?: unknown;
  };

  // Metadata
  metadata?: Record<string, unknown>;
}

// MCP Resource definition
interface MCPResource {
  uri: string;
  name: string;
  description?: string;
  mimeType: string;

  // Reading
  read(): Promise<string>;

  // Subscription support
  subscribe?(callback: (update: ResourceUpdate) => void): Unsubscribe;
}

// MCP Prompt definition
interface MCPPrompt {
  name: string;
  description?: string;
  arguments?: PromptArgument[];

  // Generate prompt
  generate(args: Record<string, string>): Promise<PromptMessage[]>;
}

interface PromptArgument {
  name: string;
  description?: string;
  required?: boolean;
}
```

### 4.2 Advanced MCP Patterns

```typescript
// Tool virtualization layer
class VirtualToolLayer {
  private realTools: Map<string, MCPTool> = new Map();
  private virtualizations: Map<string, ToolVirtualization> = new Map();

  // Wrap a tool with custom behavior
  virtualize(toolName: string, virtualization: ToolVirtualization): void {
    this.virtualizations.set(toolName, virtualization);
  }

  async execute(toolName: string, params: Record<string, unknown>): Promise<ToolOutput> {
    const virtualization = this.virtualizations.get(toolName);
    const realTool = this.realTools.get(toolName);

    if (!realTool) {
      throw new Error(`Tool ${toolName} not found`);
    }

    // Pre-execution
    let modifiedParams = params;
    if (virtualization?.beforeExecute) {
      modifiedParams = await virtualization.beforeExecute(params);
    }

    // Caching
    if (virtualization?.cache) {
      const cached = await virtualization.cache.get(toolName, modifiedParams);
      if (cached) {
        return cached;
      }
    }

    // Rate limiting
    if (virtualization?.rateLimit) {
      await virtualization.rateLimit.acquire(toolName);
    }

    // Circuit breaker
    if (virtualization?.circuitBreaker) {
      const state = virtualization.circuitBreaker.getState(toolName);
      if (state === 'open') {
        throw new CircuitOpenError(toolName);
      }
    }

    // Execute with timeout
    let result: ToolOutput;
    try {
      result = await this.executeWithTimeout(
        realTool,
        modifiedParams,
        virtualization?.timeout ?? 30000
      );

      // Circuit breaker success
      virtualization?.circuitBreaker?.recordSuccess(toolName);
    } catch (error) {
      // Circuit breaker failure
      virtualization?.circuitBreaker?.recordFailure(toolName);

      // Fallback
      if (virtualization?.fallback) {
        result = await virtualization.fallback(toolName, modifiedParams, error);
      } else {
        throw error;
      }
    }

    // Post-execution
    if (virtualization?.afterExecute) {
      result = await virtualization.afterExecute(result);
    }

    // Cache result
    if (virtualization?.cache && result.type !== 'error') {
      await virtualization.cache.set(toolName, modifiedParams, result);
    }

    return result;
  }
}

interface ToolVirtualization {
  // Transformation
  beforeExecute?(params: Record<string, unknown>): Promise<Record<string, unknown>>;
  afterExecute?(result: ToolOutput): Promise<ToolOutput>;

  // Caching
  cache?: ToolCache;

  // Rate limiting
  rateLimit?: RateLimiter;

  // Circuit breaker
  circuitBreaker?: CircuitBreaker;

  // Timeout
  timeout?: number;

  // Fallback
  fallback?(tool: string, params: Record<string, unknown>, error: unknown): Promise<ToolOutput>;

  // Retry policy
  retry?: RetryPolicy;
}

// Circuit breaker implementation
class CircuitBreaker {
  private states: Map<string, CircuitState> = new Map();
  private failures: Map<string, number> = new Map();
  private lastFailure: Map<string, number> = new Map();

  constructor(private config: CircuitBreakerConfig) {}

  getState(toolName: string): CircuitState {
    const state = this.states.get(toolName) ?? 'closed';

    // Check if half-open should transition
    if (state === 'open') {
      const lastFail = this.lastFailure.get(toolName) ?? 0;
      if (Date.now() - lastFail > this.config.resetTimeout) {
        this.states.set(toolName, 'half-open');
        return 'half-open';
      }
    }

    return state;
  }

  recordSuccess(toolName: string): void {
    const state = this.states.get(toolName);

    if (state === 'half-open') {
      // Success in half-open closes the circuit
      this.states.set(toolName, 'closed');
      this.failures.set(toolName, 0);
    }
  }

  recordFailure(toolName: string): void {
    const failures = (this.failures.get(toolName) ?? 0) + 1;
    this.failures.set(toolName, failures);
    this.lastFailure.set(toolName, Date.now());

    if (failures >= this.config.failureThreshold) {
      this.states.set(toolName, 'open');
    }
  }
}

type CircuitState = 'closed' | 'open' | 'half-open';

interface CircuitBreakerConfig {
  failureThreshold: number;       // Failures before opening
  resetTimeout: number;           // Ms before trying half-open
  halfOpenRequests: number;       // Requests to try in half-open
}

// Caching layer
interface ToolCache {
  get(tool: string, params: Record<string, unknown>): Promise<ToolOutput | null>;
  set(tool: string, params: Record<string, unknown>, result: ToolOutput): Promise<void>;
  invalidate(tool: string, params?: Record<string, unknown>): Promise<void>;
  clear(): Promise<void>;
}

class LRUToolCache implements ToolCache {
  private cache: Map<string, CacheEntry> = new Map();
  private accessOrder: string[] = [];

  constructor(
    private maxSize: number,
    private ttl: number
  ) {}

  private generateKey(tool: string, params: Record<string, unknown>): string {
    return `${tool}:${JSON.stringify(params, Object.keys(params).sort())}`;
  }

  async get(tool: string, params: Record<string, unknown>): Promise<ToolOutput | null> {
    const key = this.generateKey(tool, params);
    const entry = this.cache.get(key);

    if (!entry) return null;

    // Check TTL
    if (Date.now() - entry.timestamp > this.ttl) {
      this.cache.delete(key);
      return null;
    }

    // Update access order
    this.accessOrder = this.accessOrder.filter(k => k !== key);
    this.accessOrder.push(key);

    return entry.result;
  }

  async set(tool: string, params: Record<string, unknown>, result: ToolOutput): Promise<void> {
    const key = this.generateKey(tool, params);

    // Evict if at capacity
    while (this.cache.size >= this.maxSize) {
      const oldest = this.accessOrder.shift();
      if (oldest) this.cache.delete(oldest);
    }

    this.cache.set(key, { result, timestamp: Date.now() });
    this.accessOrder.push(key);
  }

  async invalidate(tool: string, params?: Record<string, unknown>): Promise<void> {
    if (params) {
      const key = this.generateKey(tool, params);
      this.cache.delete(key);
      this.accessOrder = this.accessOrder.filter(k => k !== key);
    } else {
      // Invalidate all entries for this tool
      for (const key of this.cache.keys()) {
        if (key.startsWith(`${tool}:`)) {
          this.cache.delete(key);
        }
      }
      this.accessOrder = this.accessOrder.filter(k => !k.startsWith(`${tool}:`));
    }
  }

  async clear(): Promise<void> {
    this.cache.clear();
    this.accessOrder = [];
  }
}

interface CacheEntry {
  result: ToolOutput;
  timestamp: number;
}
```

---

## 5. Hooks System Engineering

### 5.1 Hook Architecture

```typescript
// Comprehensive hook system
class HookManager {
  private hooks: Map<HookType, HookHandler[]> = new Map();
  private middleware: MiddlewareChain;
  private contextProvider: HookContextProvider;

  constructor(config: HookManagerConfig) {
    this.middleware = new MiddlewareChain();
    this.contextProvider = new HookContextProvider(config.contextConfig);
    this.initializeDefaultHooks();
  }

  // Register a hook
  register(type: HookType, handler: HookHandler, options?: HookOptions): HookRegistration {
    const registration: HookRegistration = {
      id: this.generateId(),
      type,
      handler,
      options: options ?? {},
      priority: options?.priority ?? 0,
      enabled: true
    };

    const handlers = this.hooks.get(type) ?? [];
    handlers.push(registration);

    // Sort by priority (higher first)
    handlers.sort((a, b) => b.priority - a.priority);
    this.hooks.set(type, handlers);

    return registration;
  }

  // Execute hooks for an event
  async execute<T extends HookType>(
    type: T,
    context: HookContext<T>
  ): Promise<HookResult<T>> {
    const handlers = this.hooks.get(type) ?? [];
    const enabledHandlers = handlers.filter(h => h.enabled);

    let currentContext = context;
    const results: HookExecutionResult[] = [];

    for (const handler of enabledHandlers) {
      const startTime = Date.now();

      try {
        // Check preconditions
        if (handler.options.condition && !await handler.options.condition(currentContext)) {
          results.push({ handlerId: handler.id, skipped: true, reason: 'condition_failed' });
          continue;
        }

        // Apply timeout
        const timeout = handler.options.timeout ?? 30000;
        const result = await this.executeWithTimeout(
          () => handler.handler(currentContext),
          timeout
        );

        // Handle result
        if (result.modified) {
          currentContext = result.context;
        }

        if (result.abort) {
          return {
            aborted: true,
            reason: result.abortReason,
            finalContext: currentContext,
            executions: results
          };
        }

        results.push({
          handlerId: handler.id,
          success: true,
          duration: Date.now() - startTime,
          modified: result.modified
        });

      } catch (error) {
        results.push({
          handlerId: handler.id,
          success: false,
          error: error as Error,
          duration: Date.now() - startTime
        });

        // Handle error based on options
        if (handler.options.critical) {
          throw error;
        }

        if (handler.options.abortOnError) {
          return {
            aborted: true,
            reason: `Hook ${handler.id} failed: ${(error as Error).message}`,
            finalContext: currentContext,
            executions: results
          };
        }
      }
    }

    return {
      aborted: false,
      finalContext: currentContext,
      executions: results
    };
  }
}

// Hook types for all interception points
enum HookType {
  // Agent lifecycle
  AGENT_INIT = 'agent:init',
  AGENT_BEFORE_TURN = 'agent:before_turn',
  AGENT_AFTER_TURN = 'agent:after_turn',
  AGENT_COMPLETE = 'agent:complete',
  AGENT_ERROR = 'agent:error',

  // Tool execution
  TOOL_BEFORE_CALL = 'tool:before_call',
  TOOL_AFTER_CALL = 'tool:after_call',
  TOOL_ERROR = 'tool:error',

  // Specific tools
  BASH_BEFORE = 'bash:before',
  BASH_AFTER = 'bash:after',
  READ_BEFORE = 'read:before',
  READ_AFTER = 'read:after',
  EDIT_BEFORE = 'edit:before',
  EDIT_AFTER = 'edit:after',
  WRITE_BEFORE = 'write:before',
  WRITE_AFTER = 'write:after',

  // API calls
  API_BEFORE_REQUEST = 'api:before_request',
  API_AFTER_RESPONSE = 'api:after_response',
  API_ERROR = 'api:error',

  // State changes
  STATE_BEFORE_CHANGE = 'state:before_change',
  STATE_AFTER_CHANGE = 'state:after_change',

  // Resource events
  RESOURCE_LIMIT_WARNING = 'resource:limit_warning',
  RESOURCE_LIMIT_EXCEEDED = 'resource:limit_exceeded',

  // User interaction
  USER_INPUT_RECEIVED = 'user:input_received',
  USER_OUTPUT_SENT = 'user:output_sent'
}

// Hook handler signature
type HookHandler<T extends HookType = HookType> = (
  context: HookContext<T>
) => Promise<HookHandlerResult<T>>;

// Context types for different hooks
interface HookContextMap {
  [HookType.TOOL_BEFORE_CALL]: {
    toolName: string;
    parameters: Record<string, unknown>;
    agentId: string;
    turn: number;
  };
  [HookType.TOOL_AFTER_CALL]: {
    toolName: string;
    parameters: Record<string, unknown>;
    result: ToolResult;
    duration: number;
    agentId: string;
    turn: number;
  };
  [HookType.BASH_BEFORE]: {
    command: string;
    workingDirectory: string;
    environment: Record<string, string>;
    timeout: number;
  };
  [HookType.BASH_AFTER]: {
    command: string;
    exitCode: number;
    stdout: string;
    stderr: string;
    duration: number;
  };
  // ... more context types
}

type HookContext<T extends HookType> = T extends keyof HookContextMap
  ? HookContextMap[T]
  : Record<string, unknown>;

// Hook handler result
interface HookHandlerResult<T extends HookType> {
  // Continue or abort
  abort?: boolean;
  abortReason?: string;

  // Context modification
  modified?: boolean;
  context?: HookContext<T>;

  // Metadata
  metadata?: Record<string, unknown>;
}

// Hook configuration options
interface HookOptions {
  // Execution order (higher = earlier)
  priority?: number;

  // Timeout for handler execution
  timeout?: number;

  // Conditional execution
  condition?: (context: unknown) => Promise<boolean>;

  // Error handling
  critical?: boolean;             // Throw on error
  abortOnError?: boolean;         // Abort pipeline on error
  retryOnError?: number;          // Retry count

  // Metadata
  name?: string;
  description?: string;
  tags?: string[];
}
```

### 5.2 Shell Command Hooks Integration

```typescript
// Integration with Claude Code's shell command hooks
interface ShellHookConfig {
  // Hook trigger points
  PreToolExecution: ShellCommand[];
  PostToolExecution: ShellCommand[];
  PrePromptSubmit: ShellCommand[];
  PostPromptSubmit: ShellCommand[];

  // Error handling
  onHookFailure: 'abort' | 'warn' | 'ignore';
  timeout: number;
}

interface ShellCommand {
  command: string;
  args?: string[];
  env?: Record<string, string>;
  workingDir?: string;

  // Input/output
  stdin?: 'none' | 'context_json' | 'tool_params';
  captureStdout?: boolean;
  captureStderr?: boolean;

  // Conditions
  toolFilter?: string[];          // Only run for these tools
  eventFilter?: string[];         // Only run for these events
}

// Hook executor for shell commands
class ShellHookExecutor {
  async execute(
    hook: ShellCommand,
    context: HookContext<any>
  ): Promise<ShellHookResult> {
    const process = spawn(hook.command, hook.args ?? [], {
      cwd: hook.workingDir ?? process.cwd(),
      env: { ...process.env, ...hook.env },
      stdio: ['pipe', 'pipe', 'pipe']
    });

    // Write context to stdin if configured
    if (hook.stdin === 'context_json') {
      process.stdin.write(JSON.stringify(context));
      process.stdin.end();
    } else if (hook.stdin === 'tool_params' && 'parameters' in context) {
      process.stdin.write(JSON.stringify(context.parameters));
      process.stdin.end();
    }

    // Collect output
    const stdout = hook.captureStdout ? await this.collectStream(process.stdout) : '';
    const stderr = hook.captureStderr ? await this.collectStream(process.stderr) : '';

    // Wait for exit
    const exitCode = await new Promise<number>((resolve) => {
      process.on('exit', resolve);
    });

    return {
      exitCode,
      stdout,
      stderr,
      blocked: exitCode !== 0,
      blockMessage: exitCode !== 0 ? stderr || stdout : undefined
    };
  }
}

interface ShellHookResult {
  exitCode: number;
  stdout: string;
  stderr: string;
  blocked: boolean;
  blockMessage?: string;
}
```

---

## 6. Task Orchestration Engine

### 6.1 Scheduler Architecture

```typescript
// Advanced task scheduler
class TaskScheduler {
  private queues: Map<string, PriorityQueue<ScheduledTask>> = new Map();
  private workers: WorkerPool;
  private policies: SchedulingPolicy[];

  constructor(config: SchedulerConfig) {
    this.initializeQueues(config.queues);
    this.workers = new WorkerPool(config.workers);
    this.policies = config.policies.map(p => this.createPolicy(p));
  }

  // Submit a task for scheduling
  async submit(task: Task, options?: SubmitOptions): Promise<TaskHandle> {
    // Create scheduled task
    const scheduledTask: ScheduledTask = {
      id: this.generateId(),
      task,
      submittedAt: Date.now(),
      priority: options?.priority ?? task.defaultPriority ?? 0,
      deadline: options?.deadline,
      dependencies: options?.dependencies ?? [],
      state: TaskState.PENDING,
      retryCount: 0,
      metadata: options?.metadata ?? {}
    };

    // Select queue based on policies
    const queueName = await this.selectQueue(scheduledTask);
    const queue = this.queues.get(queueName)!;

    // Add to queue
    queue.enqueue(scheduledTask, scheduledTask.priority);

    // Create handle
    const handle = new TaskHandle(scheduledTask, this);

    // Trigger scheduling
    this.scheduleNext();

    return handle;
  }

  // Main scheduling loop
  private async scheduleNext(): Promise<void> {
    while (true) {
      // Find available worker
      const worker = await this.workers.acquireWorker();
      if (!worker) break;

      // Find next task
      const task = await this.selectNextTask();
      if (!task) {
        this.workers.releaseWorker(worker);
        break;
      }

      // Execute task on worker
      this.executeOnWorker(worker, task).catch(error => {
        this.handleTaskError(task, error);
      });
    }
  }

  // Task selection algorithm
  private async selectNextTask(): Promise<ScheduledTask | null> {
    // Apply all policies to get candidate tasks
    let candidates: ScheduledTask[] = [];

    for (const queue of this.queues.values()) {
      const tasks = queue.peekAll();
      candidates.push(...tasks);
    }

    // Filter by dependencies
    candidates = candidates.filter(t => this.dependenciesMet(t));

    // Apply scheduling policies
    for (const policy of this.policies) {
      candidates = await policy.filter(candidates);
      if (candidates.length === 0) return null;
    }

    // Sort by composite score
    candidates.sort((a, b) => this.calculateScore(b) - this.calculateScore(a));

    // Return highest scoring task
    const selected = candidates[0];
    if (selected) {
      const queue = this.findQueueContaining(selected);
      queue?.remove(selected.id);
    }

    return selected;
  }

  // Composite scoring
  private calculateScore(task: ScheduledTask): number {
    let score = task.priority * 1000;

    // Aging: increase priority based on wait time
    const waitTime = Date.now() - task.submittedAt;
    score += Math.floor(waitTime / 1000) * 10;  // +10 per second waiting

    // Deadline urgency
    if (task.deadline) {
      const timeToDeadline = task.deadline - Date.now();
      if (timeToDeadline < 60000) {
        score += 10000;  // Critical urgency
      } else if (timeToDeadline < 300000) {
        score += 5000;   // High urgency
      }
    }

    // Fairness: penalize tasks from over-represented submitters
    const submitterLoad = this.getSubmitterLoad(task.metadata.submitter);
    score -= submitterLoad * 100;

    return score;
  }
}

// Task states
enum TaskState {
  PENDING = 'pending',            // Waiting in queue
  READY = 'ready',                // Dependencies met, ready to run
  RUNNING = 'running',            // Currently executing
  PAUSED = 'paused',              // Execution paused
  COMPLETED = 'completed',        // Successfully finished
  FAILED = 'failed',              // Failed after retries
  CANCELLED = 'cancelled',        // User cancelled
  TIMED_OUT = 'timed_out'         // Deadline missed
}

// Scheduling policies
interface SchedulingPolicy {
  name: string;
  filter(tasks: ScheduledTask[]): Promise<ScheduledTask[]>;
  score?(task: ScheduledTask): number;
}

// FIFO Policy
class FIFOPolicy implements SchedulingPolicy {
  name = 'fifo';

  async filter(tasks: ScheduledTask[]): Promise<ScheduledTask[]> {
    return tasks.sort((a, b) => a.submittedAt - b.submittedAt);
  }
}

// Priority Policy
class PriorityPolicy implements SchedulingPolicy {
  name = 'priority';

  async filter(tasks: ScheduledTask[]): Promise<ScheduledTask[]> {
    return tasks.sort((a, b) => b.priority - a.priority);
  }
}

// Fair Share Policy
class FairSharePolicy implements SchedulingPolicy {
  name = 'fair_share';
  private shares: Map<string, number> = new Map();
  private usage: Map<string, number> = new Map();

  constructor(shareConfig: Record<string, number>) {
    for (const [user, share] of Object.entries(shareConfig)) {
      this.shares.set(user, share);
    }
  }

  async filter(tasks: ScheduledTask[]): Promise<ScheduledTask[]> {
    // Group by submitter
    const bySubmitter = new Map<string, ScheduledTask[]>();
    for (const task of tasks) {
      const submitter = task.metadata.submitter ?? 'default';
      const group = bySubmitter.get(submitter) ?? [];
      group.push(task);
      bySubmitter.set(submitter, group);
    }

    // Calculate deficit (share - usage) for each submitter
    const deficits: Array<[string, number]> = [];
    for (const [submitter, group] of bySubmitter) {
      const share = this.shares.get(submitter) ?? 1;
      const usage = this.usage.get(submitter) ?? 0;
      const deficit = share - usage;
      deficits.push([submitter, deficit]);
    }

    // Sort by deficit (highest deficit gets priority)
    deficits.sort((a, b) => b[1] - a[1]);

    // Return tasks from highest deficit submitter first
    const result: ScheduledTask[] = [];
    for (const [submitter] of deficits) {
      result.push(...(bySubmitter.get(submitter) ?? []));
    }

    return result;
  }
}

// Deadline-aware Policy
class DeadlinePolicy implements SchedulingPolicy {
  name = 'deadline';

  async filter(tasks: ScheduledTask[]): Promise<ScheduledTask[]> {
    const now = Date.now();

    // Separate deadline and non-deadline tasks
    const withDeadline = tasks.filter(t => t.deadline != null);
    const withoutDeadline = tasks.filter(t => t.deadline == null);

    // Sort deadline tasks by urgency
    withDeadline.sort((a, b) => {
      const urgencyA = a.deadline! - now;
      const urgencyB = b.deadline! - now;
      return urgencyA - urgencyB;
    });

    // Deadline tasks first
    return [...withDeadline, ...withoutDeadline];
  }
}
```

### 6.2 Dependency Graph Execution

```typescript
// DAG-based task execution
class DependencyGraph {
  private nodes: Map<string, GraphNode> = new Map();
  private edges: Map<string, Set<string>> = new Map();  // task -> dependencies
  private reverseEdges: Map<string, Set<string>> = new Map();  // task -> dependents

  // Add task to graph
  addTask(task: ScheduledTask): void {
    this.nodes.set(task.id, {
      task,
      state: 'pending',
      result: null
    });

    // Add edges for dependencies
    const deps = new Set(task.dependencies);
    this.edges.set(task.id, deps);

    // Update reverse edges
    for (const dep of deps) {
      const dependents = this.reverseEdges.get(dep) ?? new Set();
      dependents.add(task.id);
      this.reverseEdges.set(dep, dependents);
    }
  }

  // Get tasks ready for execution
  getReadyTasks(): ScheduledTask[] {
    const ready: ScheduledTask[] = [];

    for (const [id, node] of this.nodes) {
      if (node.state !== 'pending') continue;

      const deps = this.edges.get(id) ?? new Set();
      const allDepsComplete = Array.from(deps).every(depId => {
        const depNode = this.nodes.get(depId);
        return depNode?.state === 'completed';
      });

      if (allDepsComplete) {
        ready.push(node.task);
      }
    }

    return ready;
  }

  // Mark task complete and propagate
  markComplete(taskId: string, result: unknown): string[] {
    const node = this.nodes.get(taskId);
    if (!node) return [];

    node.state = 'completed';
    node.result = result;

    // Find newly unblocked tasks
    const dependents = this.reverseEdges.get(taskId) ?? new Set();
    const newlyReady: string[] = [];

    for (const depId of dependents) {
      const depNode = this.nodes.get(depId);
      if (!depNode || depNode.state !== 'pending') continue;

      const deps = this.edges.get(depId) ?? new Set();
      const allComplete = Array.from(deps).every(d => {
        const n = this.nodes.get(d);
        return n?.state === 'completed';
      });

      if (allComplete) {
        newlyReady.push(depId);
      }
    }

    return newlyReady;
  }

  // Detect cycles
  detectCycles(): string[][] {
    const visited = new Set<string>();
    const recStack = new Set<string>();
    const cycles: string[][] = [];

    const dfs = (nodeId: string, path: string[]): void => {
      visited.add(nodeId);
      recStack.add(nodeId);

      const deps = this.edges.get(nodeId) ?? new Set();
      for (const dep of deps) {
        if (!visited.has(dep)) {
          dfs(dep, [...path, nodeId]);
        } else if (recStack.has(dep)) {
          // Found cycle
          const cycleStart = path.indexOf(dep);
          cycles.push([...path.slice(cycleStart), nodeId, dep]);
        }
      }

      recStack.delete(nodeId);
    };

    for (const nodeId of this.nodes.keys()) {
      if (!visited.has(nodeId)) {
        dfs(nodeId, []);
      }
    }

    return cycles;
  }

  // Topological sort for execution order
  topologicalSort(): ScheduledTask[] {
    const inDegree = new Map<string, number>();
    const queue: string[] = [];
    const result: ScheduledTask[] = [];

    // Calculate in-degrees
    for (const [id] of this.nodes) {
      const deps = this.edges.get(id) ?? new Set();
      inDegree.set(id, deps.size);

      if (deps.size === 0) {
        queue.push(id);
      }
    }

    // Process queue
    while (queue.length > 0) {
      const id = queue.shift()!;
      const node = this.nodes.get(id)!;
      result.push(node.task);

      const dependents = this.reverseEdges.get(id) ?? new Set();
      for (const dep of dependents) {
        const degree = (inDegree.get(dep) ?? 0) - 1;
        inDegree.set(dep, degree);

        if (degree === 0) {
          queue.push(dep);
        }
      }
    }

    // Check for cycles
    if (result.length !== this.nodes.size) {
      throw new Error('Graph contains cycles - cannot topologically sort');
    }

    return result;
  }
}

interface GraphNode {
  task: ScheduledTask;
  state: 'pending' | 'running' | 'completed' | 'failed';
  result: unknown;
}
```

---

## 7. State Management Subsystem

### 7.1 State Store Architecture

```typescript
// Hierarchical state management
class StateStore {
  private localStorage: LocalStateBackend;
  private persistentStorage: PersistentStateBackend;
  private distributedStorage?: DistributedStateBackend;
  private transactionLog: TransactionLog;

  constructor(config: StateStoreConfig) {
    this.localStorage = new LocalStateBackend(config.local);
    this.persistentStorage = new PersistentStateBackend(config.persistent);

    if (config.distributed) {
      this.distributedStorage = new DistributedStateBackend(config.distributed);
    }

    this.transactionLog = new TransactionLog(config.transactionLog);
  }

  // Hierarchical get with fallback
  async get<T>(key: string, options?: GetOptions): Promise<T | null> {
    // Check local cache first
    const local = await this.localStorage.get<T>(key);
    if (local !== null) return local;

    // Check persistent storage
    const persistent = await this.persistentStorage.get<T>(key);
    if (persistent !== null) {
      // Populate local cache
      await this.localStorage.set(key, persistent, { ttl: options?.cacheTtl });
      return persistent;
    }

    // Check distributed storage
    if (this.distributedStorage) {
      const distributed = await this.distributedStorage.get<T>(key);
      if (distributed !== null) {
        await this.localStorage.set(key, distributed, { ttl: options?.cacheTtl });
        await this.persistentStorage.set(key, distributed);
        return distributed;
      }
    }

    return null;
  }

  // Transactional set
  async set<T>(key: string, value: T, options?: SetOptions): Promise<void> {
    const transaction = await this.transactionLog.begin();

    try {
      // Write to all levels
      await this.localStorage.set(key, value, options);
      await this.persistentStorage.set(key, value, options);

      if (this.distributedStorage && options?.distribute !== false) {
        await this.distributedStorage.set(key, value, options);
      }

      await this.transactionLog.commit(transaction);
    } catch (error) {
      await this.transactionLog.rollback(transaction);
      throw error;
    }
  }

  // Atomic operations
  async atomicUpdate<T>(
    key: string,
    updater: (current: T | null) => T
  ): Promise<T> {
    const lock = await this.acquireLock(key);

    try {
      const current = await this.get<T>(key);
      const updated = updater(current);
      await this.set(key, updated);
      return updated;
    } finally {
      await this.releaseLock(lock);
    }
  }

  // Watch for changes
  watch<T>(
    key: string,
    callback: (value: T | null, oldValue: T | null) => void
  ): Unsubscribe {
    return this.localStorage.watch(key, callback);
  }
}

// State backends
interface StateBackend {
  get<T>(key: string): Promise<T | null>;
  set<T>(key: string, value: T, options?: SetOptions): Promise<void>;
  delete(key: string): Promise<void>;
  exists(key: string): Promise<boolean>;
  keys(pattern?: string): Promise<string[]>;
}

// Local in-memory backend with LRU eviction
class LocalStateBackend implements StateBackend {
  private cache: Map<string, CacheEntry> = new Map();
  private accessOrder: string[] = [];
  private watchers: Map<string, Set<WatchCallback>> = new Map();

  constructor(private config: LocalBackendConfig) {}

  async get<T>(key: string): Promise<T | null> {
    const entry = this.cache.get(key);
    if (!entry) return null;

    // Check TTL
    if (entry.expiresAt && Date.now() > entry.expiresAt) {
      this.cache.delete(key);
      return null;
    }

    // Update access order
    this.updateAccessOrder(key);

    return entry.value as T;
  }

  async set<T>(key: string, value: T, options?: SetOptions): Promise<void> {
    const oldValue = await this.get<T>(key);

    // Evict if needed
    while (this.cache.size >= this.config.maxSize) {
      this.evictOldest();
    }

    const entry: CacheEntry = {
      value,
      expiresAt: options?.ttl ? Date.now() + options.ttl : undefined,
      createdAt: Date.now()
    };

    this.cache.set(key, entry);
    this.updateAccessOrder(key);

    // Notify watchers
    this.notifyWatchers(key, value, oldValue);
  }

  watch<T>(key: string, callback: WatchCallback<T>): Unsubscribe {
    const watchers = this.watchers.get(key) ?? new Set();
    watchers.add(callback as WatchCallback);
    this.watchers.set(key, watchers);

    return () => {
      watchers.delete(callback as WatchCallback);
    };
  }
}

// SQLite persistent backend
class SQLitePersistentBackend implements StateBackend {
  private db: Database;

  constructor(config: SQLiteConfig) {
    this.db = new Database(config.path);
    this.initializeSchema();
  }

  private initializeSchema(): void {
    this.db.exec(`
      CREATE TABLE IF NOT EXISTS state (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        type TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        expires_at INTEGER,
        metadata TEXT
      );

      CREATE INDEX IF NOT EXISTS idx_expires_at ON state(expires_at);
      CREATE INDEX IF NOT EXISTS idx_key_prefix ON state(key);
    `);
  }

  async get<T>(key: string): Promise<T | null> {
    const row = this.db.prepare(`
      SELECT value, type, expires_at FROM state WHERE key = ?
    `).get(key) as StateRow | undefined;

    if (!row) return null;

    // Check expiration
    if (row.expires_at && Date.now() > row.expires_at) {
      await this.delete(key);
      return null;
    }

    return this.deserialize<T>(row.value, row.type);
  }

  async set<T>(key: string, value: T, options?: SetOptions): Promise<void> {
    const serialized = this.serialize(value);
    const now = Date.now();

    this.db.prepare(`
      INSERT OR REPLACE INTO state (key, value, type, created_at, updated_at, expires_at, metadata)
      VALUES (?, ?, ?, ?, ?, ?, ?)
    `).run(
      key,
      serialized.value,
      serialized.type,
      now,
      now,
      options?.ttl ? now + options.ttl : null,
      options?.metadata ? JSON.stringify(options.metadata) : null
    );
  }

  private serialize(value: unknown): { value: string; type: string } {
    if (typeof value === 'string') {
      return { value, type: 'string' };
    } else if (typeof value === 'number') {
      return { value: String(value), type: 'number' };
    } else if (typeof value === 'boolean') {
      return { value: String(value), type: 'boolean' };
    } else if (value instanceof Buffer) {
      return { value: value.toString('base64'), type: 'buffer' };
    } else {
      return { value: JSON.stringify(value), type: 'json' };
    }
  }

  private deserialize<T>(value: string, type: string): T {
    switch (type) {
      case 'string': return value as T;
      case 'number': return Number(value) as T;
      case 'boolean': return (value === 'true') as T;
      case 'buffer': return Buffer.from(value, 'base64') as T;
      case 'json': return JSON.parse(value) as T;
      default: throw new Error(`Unknown type: ${type}`);
    }
  }
}

interface StateRow {
  key: string;
  value: string;
  type: string;
  expires_at: number | null;
}
```

### 7.2 Checkpointing System

```typescript
// Checkpoint management for task recovery
class CheckpointManager {
  private storage: CheckpointStorage;
  private compressor: CheckpointCompressor;
  private encryptor?: CheckpointEncryptor;

  constructor(config: CheckpointConfig) {
    this.storage = new CheckpointStorage(config.storage);
    this.compressor = new CheckpointCompressor(config.compression);

    if (config.encryption) {
      this.encryptor = new CheckpointEncryptor(config.encryption);
    }
  }

  // Create checkpoint
  async create(agentId: string, state: AgentState): Promise<CheckpointId> {
    const checkpoint: Checkpoint = {
      id: this.generateId(),
      agentId,
      timestamp: Date.now(),
      version: CHECKPOINT_VERSION,

      // Core state
      state: {
        turn: state.turn,
        messages: state.messages,
        toolHistory: state.toolHistory,
        variables: state.variables
      },

      // Context
      context: {
        workingDirectory: state.workingDirectory,
        environment: state.environment,
        openFiles: state.openFiles
      },

      // Metrics
      metrics: {
        tokensUsed: state.tokensUsed,
        toolCalls: state.toolCalls,
        duration: state.duration
      }
    };

    // Serialize
    let data = this.serialize(checkpoint);

    // Compress
    data = await this.compressor.compress(data);

    // Encrypt
    if (this.encryptor) {
      data = await this.encryptor.encrypt(data);
    }

    // Store
    await this.storage.store(checkpoint.id, data, {
      agentId,
      timestamp: checkpoint.timestamp,
      size: data.length
    });

    return checkpoint.id;
  }

  // Restore from checkpoint
  async restore(checkpointId: CheckpointId): Promise<AgentState> {
    // Retrieve
    let data = await this.storage.retrieve(checkpointId);
    if (!data) {
      throw new CheckpointNotFoundError(checkpointId);
    }

    // Decrypt
    if (this.encryptor) {
      data = await this.encryptor.decrypt(data);
    }

    // Decompress
    data = await this.compressor.decompress(data);

    // Deserialize
    const checkpoint = this.deserialize(data);

    // Validate version
    if (!this.isCompatibleVersion(checkpoint.version)) {
      throw new CheckpointVersionError(checkpoint.version, CHECKPOINT_VERSION);
    }

    // Reconstruct state
    return this.reconstructState(checkpoint);
  }

  // List checkpoints for agent
  async list(agentId: string, options?: ListOptions): Promise<CheckpointMetadata[]> {
    return this.storage.list({
      agentId,
      limit: options?.limit,
      before: options?.before,
      after: options?.after
    });
  }

  // Prune old checkpoints
  async prune(agentId: string, options: PruneOptions): Promise<number> {
    const checkpoints = await this.list(agentId);

    // Determine which to keep
    const toKeep = new Set<string>();

    // Keep N most recent
    if (options.keepRecent) {
      checkpoints
        .sort((a, b) => b.timestamp - a.timestamp)
        .slice(0, options.keepRecent)
        .forEach(c => toKeep.add(c.id));
    }

    // Keep checkpoints newer than threshold
    if (options.keepNewerThan) {
      const threshold = Date.now() - options.keepNewerThan;
      checkpoints
        .filter(c => c.timestamp > threshold)
        .forEach(c => toKeep.add(c.id));
    }

    // Delete others
    let deleted = 0;
    for (const checkpoint of checkpoints) {
      if (!toKeep.has(checkpoint.id)) {
        await this.storage.delete(checkpoint.id);
        deleted++;
      }
    }

    return deleted;
  }

  // Incremental checkpoint (delta from previous)
  async createIncremental(
    agentId: string,
    state: AgentState,
    baseCheckpointId: CheckpointId
  ): Promise<CheckpointId> {
    const baseCheckpoint = await this.restore(baseCheckpointId);

    // Calculate delta
    const delta = this.calculateDelta(baseCheckpoint, state);

    const incrementalCheckpoint: IncrementalCheckpoint = {
      id: this.generateId(),
      agentId,
      timestamp: Date.now(),
      version: CHECKPOINT_VERSION,
      baseCheckpointId,
      delta
    };

    // Store (same pipeline: serialize -> compress -> encrypt)
    let data = this.serialize(incrementalCheckpoint);
    data = await this.compressor.compress(data);
    if (this.encryptor) {
      data = await this.encryptor.encrypt(data);
    }

    await this.storage.store(incrementalCheckpoint.id, data, {
      agentId,
      timestamp: incrementalCheckpoint.timestamp,
      size: data.length,
      incremental: true,
      baseCheckpointId
    });

    return incrementalCheckpoint.id;
  }

  private calculateDelta(base: AgentState, current: AgentState): StateDelta {
    return {
      // New messages since checkpoint
      newMessages: current.messages.slice(base.messages.length),

      // Changed variables
      changedVariables: this.diffObjects(base.variables, current.variables),

      // New tool history
      newToolHistory: current.toolHistory.slice(base.toolHistory.length),

      // Updated metrics
      metricsUpdate: {
        tokensUsed: current.tokensUsed - base.tokensUsed,
        toolCalls: current.toolCalls - base.toolCalls,
        duration: current.duration - base.duration
      }
    };
  }
}

interface Checkpoint {
  id: CheckpointId;
  agentId: string;
  timestamp: number;
  version: string;
  state: CheckpointState;
  context: CheckpointContext;
  metrics: CheckpointMetrics;
}

interface CheckpointState {
  turn: number;
  messages: Message[];
  toolHistory: ToolExecution[];
  variables: Record<string, unknown>;
}

interface StateDelta {
  newMessages: Message[];
  changedVariables: ObjectDiff;
  newToolHistory: ToolExecution[];
  metricsUpdate: MetricsDelta;
}
```

---

## 8. Resource Governance Layer

### 8.1 Resource Limiter Architecture

```typescript
// Multi-dimensional resource governance
class ResourceGovernor {
  private limiters: Map<ResourceType, ResourceLimiter> = new Map();
  private monitors: Map<ResourceType, ResourceMonitor> = new Map();
  private policies: ResourcePolicy[];
  private alertManager: AlertManager;

  constructor(config: ResourceGovernorConfig) {
    this.initializeLimiters(config.limits);
    this.initializeMonitors(config.monitoring);
    this.policies = config.policies.map(p => this.createPolicy(p));
    this.alertManager = new AlertManager(config.alerts);
  }

  // Check if resource acquisition is allowed
  async acquire(
    agentId: string,
    request: ResourceRequest
  ): Promise<AcquisitionResult> {
    const results: Map<ResourceType, LimitCheckResult> = new Map();

    for (const [type, amount] of Object.entries(request)) {
      const limiter = this.limiters.get(type as ResourceType);
      if (!limiter) continue;

      const result = await limiter.check(agentId, amount);
      results.set(type as ResourceType, result);

      if (!result.allowed) {
        // Apply policies
        for (const policy of this.policies) {
          const decision = await policy.onLimitExceeded(agentId, type as ResourceType, result);
          if (decision.action === 'allow') {
            results.set(type as ResourceType, { ...result, allowed: true, reason: 'policy_override' });
            break;
          }
        }
      }
    }

    // Check if all resources are available
    const allAllowed = Array.from(results.values()).every(r => r.allowed);

    if (allAllowed) {
      // Actually acquire the resources
      for (const [type, amount] of Object.entries(request)) {
        const limiter = this.limiters.get(type as ResourceType);
        await limiter?.acquire(agentId, amount);
      }
    }

    return {
      allowed: allAllowed,
      results,
      waitTime: this.calculateWaitTime(results)
    };
  }

  // Release resources
  async release(agentId: string, resources: ResourceRequest): Promise<void> {
    for (const [type, amount] of Object.entries(resources)) {
      const limiter = this.limiters.get(type as ResourceType);
      await limiter?.release(agentId, amount);
    }
  }

  // Get current usage
  async getUsage(agentId: string): Promise<ResourceUsage> {
    const usage: ResourceUsage = {};

    for (const [type, monitor] of this.monitors) {
      usage[type] = await monitor.getCurrentUsage(agentId);
    }

    return usage;
  }
}

// Resource types
enum ResourceType {
  // Token resources
  INPUT_TOKENS = 'input_tokens',
  OUTPUT_TOKENS = 'output_tokens',
  TOTAL_TOKENS = 'total_tokens',

  // Compute resources
  CPU_TIME = 'cpu_time',
  MEMORY = 'memory',
  GPU_MEMORY = 'gpu_memory',

  // I/O resources
  DISK_READ = 'disk_read',
  DISK_WRITE = 'disk_write',
  NETWORK_EGRESS = 'network_egress',
  NETWORK_INGRESS = 'network_ingress',

  // API resources
  API_CALLS = 'api_calls',
  TOOL_CALLS = 'tool_calls',

  // Concurrency
  PARALLEL_TASKS = 'parallel_tasks',
  CHILD_PROCESSES = 'child_processes',

  // Time
  WALL_TIME = 'wall_time',
  TURN_TIME = 'turn_time'
}

// Token bucket rate limiter
class TokenBucketLimiter implements ResourceLimiter {
  private buckets: Map<string, TokenBucket> = new Map();

  constructor(private config: TokenBucketConfig) {}

  async check(agentId: string, amount: number): Promise<LimitCheckResult> {
    const bucket = this.getOrCreateBucket(agentId);

    if (bucket.tokens >= amount) {
      return { allowed: true, available: bucket.tokens };
    }

    // Calculate wait time for refill
    const deficit = amount - bucket.tokens;
    const waitMs = (deficit / this.config.refillRate) * 1000;

    return {
      allowed: false,
      available: bucket.tokens,
      required: amount,
      waitTime: waitMs,
      reason: 'rate_limit_exceeded'
    };
  }

  async acquire(agentId: string, amount: number): Promise<void> {
    const bucket = this.getOrCreateBucket(agentId);
    bucket.tokens -= amount;
  }

  async release(agentId: string, amount: number): Promise<void> {
    // Token bucket doesn't support release - tokens refill over time
  }

  private getOrCreateBucket(agentId: string): TokenBucket {
    let bucket = this.buckets.get(agentId);

    if (!bucket) {
      bucket = {
        tokens: this.config.capacity,
        lastRefill: Date.now()
      };
      this.buckets.set(agentId, bucket);
    }

    // Refill tokens based on time elapsed
    const now = Date.now();
    const elapsed = (now - bucket.lastRefill) / 1000;
    bucket.tokens = Math.min(
      this.config.capacity,
      bucket.tokens + elapsed * this.config.refillRate
    );
    bucket.lastRefill = now;

    return bucket;
  }
}

interface TokenBucket {
  tokens: number;
  lastRefill: number;
}

interface TokenBucketConfig {
  capacity: number;               // Max tokens in bucket
  refillRate: number;             // Tokens per second
}

// Sliding window limiter
class SlidingWindowLimiter implements ResourceLimiter {
  private windows: Map<string, WindowEntry[]> = new Map();

  constructor(private config: SlidingWindowConfig) {}

  async check(agentId: string, amount: number): Promise<LimitCheckResult> {
    this.cleanupOldEntries(agentId);

    const entries = this.windows.get(agentId) ?? [];
    const currentUsage = entries.reduce((sum, e) => sum + e.amount, 0);

    if (currentUsage + amount <= this.config.limit) {
      return { allowed: true, available: this.config.limit - currentUsage };
    }

    // Find when oldest entry will expire
    const oldestExpiry = entries[0]?.timestamp + this.config.windowMs;
    const waitTime = oldestExpiry ? oldestExpiry - Date.now() : 0;

    return {
      allowed: false,
      available: this.config.limit - currentUsage,
      required: amount,
      waitTime,
      reason: 'window_limit_exceeded'
    };
  }

  async acquire(agentId: string, amount: number): Promise<void> {
    const entries = this.windows.get(agentId) ?? [];
    entries.push({ timestamp: Date.now(), amount });
    this.windows.set(agentId, entries);
  }

  async release(agentId: string, amount: number): Promise<void> {
    // Sliding window doesn't support early release
  }

  private cleanupOldEntries(agentId: string): void {
    const entries = this.windows.get(agentId) ?? [];
    const cutoff = Date.now() - this.config.windowMs;
    const filtered = entries.filter(e => e.timestamp > cutoff);
    this.windows.set(agentId, filtered);
  }
}

interface WindowEntry {
  timestamp: number;
  amount: number;
}

interface SlidingWindowConfig {
  windowMs: number;               // Window duration
  limit: number;                  // Max amount in window
}

// Quota limiter with hierarchical quotas
class QuotaLimiter implements ResourceLimiter {
  private quotas: Map<string, QuotaState> = new Map();

  constructor(private config: QuotaConfig) {}

  async check(agentId: string, amount: number): Promise<LimitCheckResult> {
    const state = this.getOrCreateState(agentId);

    // Check all quota levels
    const checks = [
      this.checkQuota(state.minute, this.config.perMinute, 'per_minute'),
      this.checkQuota(state.hour, this.config.perHour, 'per_hour'),
      this.checkQuota(state.day, this.config.perDay, 'per_day'),
      this.checkQuota(state.total, this.config.total, 'total')
    ];

    const failed = checks.find(c => !c.allowed);
    if (failed) {
      return failed;
    }

    const minAvailable = Math.min(...checks.map(c => c.available));
    return { allowed: true, available: minAvailable };
  }

  async acquire(agentId: string, amount: number): Promise<void> {
    const state = this.getOrCreateState(agentId);
    state.minute.used += amount;
    state.hour.used += amount;
    state.day.used += amount;
    state.total.used += amount;
  }

  async release(agentId: string, amount: number): Promise<void> {
    const state = this.quotas.get(agentId);
    if (!state) return;

    state.minute.used = Math.max(0, state.minute.used - amount);
    state.hour.used = Math.max(0, state.hour.used - amount);
    state.day.used = Math.max(0, state.day.used - amount);
    state.total.used = Math.max(0, state.total.used - amount);
  }

  private checkQuota(
    usage: QuotaUsage,
    limit: number | undefined,
    level: string
  ): LimitCheckResult {
    if (limit === undefined) {
      return { allowed: true, available: Infinity };
    }

    const available = limit - usage.used;
    return {
      allowed: available > 0,
      available,
      reason: available <= 0 ? `${level}_quota_exceeded` : undefined
    };
  }

  private getOrCreateState(agentId: string): QuotaState {
    let state = this.quotas.get(agentId);

    if (!state) {
      const now = Date.now();
      state = {
        minute: { used: 0, resetAt: now + 60000 },
        hour: { used: 0, resetAt: now + 3600000 },
        day: { used: 0, resetAt: now + 86400000 },
        total: { used: 0, resetAt: 0 }
      };
      this.quotas.set(agentId, state);
    }

    // Reset expired quotas
    const now = Date.now();
    if (now > state.minute.resetAt) {
      state.minute = { used: 0, resetAt: now + 60000 };
    }
    if (now > state.hour.resetAt) {
      state.hour = { used: 0, resetAt: now + 3600000 };
    }
    if (now > state.day.resetAt) {
      state.day = { used: 0, resetAt: now + 86400000 };
    }

    return state;
  }
}

interface QuotaState {
  minute: QuotaUsage;
  hour: QuotaUsage;
  day: QuotaUsage;
  total: QuotaUsage;
}

interface QuotaUsage {
  used: number;
  resetAt: number;
}
```

---

## 9. Observability Infrastructure

### 9.1 Metrics Collection

```typescript
// Comprehensive metrics system
class MetricsCollector {
  private registry: MetricRegistry;
  private exporters: MetricExporter[];
  private aggregators: Map<string, MetricAggregator> = new Map();

  constructor(config: MetricsConfig) {
    this.registry = new MetricRegistry();
    this.exporters = config.exporters.map(e => this.createExporter(e));
    this.initializeDefaultMetrics();
  }

  // Counter metric
  counter(name: string, tags?: Tags): Counter {
    return this.registry.getOrCreate(name, 'counter', tags) as Counter;
  }

  // Gauge metric
  gauge(name: string, tags?: Tags): Gauge {
    return this.registry.getOrCreate(name, 'gauge', tags) as Gauge;
  }

  // Histogram metric
  histogram(name: string, buckets: number[], tags?: Tags): Histogram {
    return this.registry.getOrCreate(name, 'histogram', tags, { buckets }) as Histogram;
  }

  // Summary metric (quantiles)
  summary(name: string, quantiles: number[], tags?: Tags): Summary {
    return this.registry.getOrCreate(name, 'summary', tags, { quantiles }) as Summary;
  }

  // Record a timing
  async time<T>(name: string, fn: () => Promise<T>, tags?: Tags): Promise<T> {
    const start = process.hrtime.bigint();

    try {
      const result = await fn();
      const duration = Number(process.hrtime.bigint() - start) / 1e6;

      this.histogram(`${name}_duration_ms`, [1, 5, 10, 25, 50, 100, 250, 500, 1000], tags)
        .observe(duration);

      this.counter(`${name}_total`, tags).inc();

      return result;
    } catch (error) {
      this.counter(`${name}_errors_total`, tags).inc();
      throw error;
    }
  }

  // Initialize default agent metrics
  private initializeDefaultMetrics(): void {
    // Agent metrics
    this.counter('agent_turns_total');
    this.counter('agent_completions_total');
    this.counter('agent_errors_total');
    this.histogram('agent_turn_duration_ms', [100, 500, 1000, 5000, 10000, 30000]);
    this.gauge('agent_active_count');

    // Tool metrics
    this.counter('tool_calls_total');
    this.counter('tool_errors_total');
    this.histogram('tool_duration_ms', [10, 50, 100, 500, 1000, 5000]);

    // Token metrics
    this.counter('tokens_input_total');
    this.counter('tokens_output_total');
    this.histogram('tokens_per_turn', [100, 500, 1000, 2000, 4000, 8000]);

    // Resource metrics
    this.gauge('memory_usage_bytes');
    this.gauge('cpu_usage_percent');
    this.counter('rate_limit_hits_total');

    // Task metrics
    this.counter('tasks_submitted_total');
    this.counter('tasks_completed_total');
    this.histogram('task_queue_time_ms', [100, 500, 1000, 5000, 10000]);
    this.gauge('task_queue_length');
  }

  // Export metrics
  async export(): Promise<void> {
    const metrics = this.registry.collect();

    for (const exporter of this.exporters) {
      await exporter.export(metrics);
    }
  }
}

// Metric types
interface Counter {
  inc(value?: number): void;
  get(): number;
}

interface Gauge {
  set(value: number): void;
  inc(value?: number): void;
  dec(value?: number): void;
  get(): number;
}

interface Histogram {
  observe(value: number): void;
  getBuckets(): Map<number, number>;
  getSum(): number;
  getCount(): number;
}

interface Summary {
  observe(value: number): void;
  getQuantile(q: number): number;
  getSum(): number;
  getCount(): number;
}

// Prometheus exporter
class PrometheusExporter implements MetricExporter {
  constructor(private config: PrometheusConfig) {}

  async export(metrics: CollectedMetrics): Promise<void> {
    const lines: string[] = [];

    for (const metric of metrics) {
      // Add HELP and TYPE
      lines.push(`# HELP ${metric.name} ${metric.help}`);
      lines.push(`# TYPE ${metric.name} ${metric.type}`);

      // Add metric values
      for (const sample of metric.samples) {
        const labels = this.formatLabels(sample.labels);
        lines.push(`${metric.name}${labels} ${sample.value}`);
      }
    }

    const output = lines.join('\n');

    if (this.config.pushGateway) {
      await this.pushToGateway(output);
    }

    if (this.config.httpServer) {
      this.updateHttpEndpoint(output);
    }
  }

  private formatLabels(labels: Record<string, string>): string {
    const entries = Object.entries(labels);
    if (entries.length === 0) return '';

    const formatted = entries.map(([k, v]) => `${k}="${v}"`).join(',');
    return `{${formatted}}`;
  }
}

// OpenTelemetry exporter
class OTelExporter implements MetricExporter {
  private meterProvider: MeterProvider;

  constructor(config: OTelConfig) {
    this.meterProvider = new MeterProvider({
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: config.serviceName,
        [SemanticResourceAttributes.SERVICE_VERSION]: config.serviceVersion
      })
    });

    // Add exporters
    if (config.otlpEndpoint) {
      this.meterProvider.addMetricReader(
        new PeriodicExportingMetricReader({
          exporter: new OTLPMetricExporter({ url: config.otlpEndpoint }),
          exportIntervalMillis: config.exportInterval
        })
      );
    }
  }

  async export(metrics: CollectedMetrics): Promise<void> {
    const meter = this.meterProvider.getMeter('agent-metrics');

    for (const metric of metrics) {
      switch (metric.type) {
        case 'counter':
          const counter = meter.createCounter(metric.name);
          for (const sample of metric.samples) {
            counter.add(sample.value, sample.labels);
          }
          break;

        case 'gauge':
          const gauge = meter.createObservableGauge(metric.name);
          gauge.addCallback((result) => {
            for (const sample of metric.samples) {
              result.observe(sample.value, sample.labels);
            }
          });
          break;

        case 'histogram':
          const histogram = meter.createHistogram(metric.name);
          // Histograms need raw observations, not pre-bucketed data
          break;
      }
    }
  }
}
```

### 9.2 Distributed Tracing

```typescript
// Tracing infrastructure
class TracingManager {
  private tracer: Tracer;
  private sampler: Sampler;
  private propagator: TextMapPropagator;

  constructor(config: TracingConfig) {
    this.sampler = this.createSampler(config.sampling);
    this.propagator = new W3CTraceContextPropagator();

    const provider = new BasicTracerProvider({
      sampler: this.sampler,
      resource: new Resource({
        [SemanticResourceAttributes.SERVICE_NAME]: config.serviceName
      })
    });

    // Add span processors
    if (config.jaegerEndpoint) {
      provider.addSpanProcessor(
        new BatchSpanProcessor(
          new JaegerExporter({ endpoint: config.jaegerEndpoint })
        )
      );
    }

    if (config.otlpEndpoint) {
      provider.addSpanProcessor(
        new BatchSpanProcessor(
          new OTLPTraceExporter({ url: config.otlpEndpoint })
        )
      );
    }

    provider.register({ propagator: this.propagator });
    this.tracer = trace.getTracer('agent-tracer');
  }

  // Start a new span
  startSpan(name: string, options?: SpanOptions): Span {
    return this.tracer.startSpan(name, {
      kind: options?.kind ?? SpanKind.INTERNAL,
      attributes: options?.attributes
    });
  }

  // Wrap async function with span
  async trace<T>(
    name: string,
    fn: (span: Span) => Promise<T>,
    options?: SpanOptions
  ): Promise<T> {
    const span = this.startSpan(name, options);

    try {
      const result = await context.with(
        trace.setSpan(context.active(), span),
        () => fn(span)
      );

      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({
        code: SpanStatusCode.ERROR,
        message: (error as Error).message
      });
      span.recordException(error as Error);
      throw error;
    } finally {
      span.end();
    }
  }

  // Create child span
  childSpan(parent: Span, name: string, options?: SpanOptions): Span {
    const ctx = trace.setSpan(context.active(), parent);

    return this.tracer.startSpan(name, {
      kind: options?.kind ?? SpanKind.INTERNAL,
      attributes: options?.attributes
    }, ctx);
  }
}

// Agent execution tracing
class AgentTracer {
  private tracer: TracingManager;
  private activeSpans: Map<string, Span> = new Map();

  constructor(tracer: TracingManager) {
    this.tracer = tracer;
  }

  // Trace entire agent execution
  async traceExecution<T>(
    agentId: string,
    fn: () => Promise<T>
  ): Promise<T> {
    return this.tracer.trace(
      'agent.execute',
      async (span) => {
        span.setAttribute('agent.id', agentId);
        this.activeSpans.set(agentId, span);

        try {
          return await fn();
        } finally {
          this.activeSpans.delete(agentId);
        }
      },
      { kind: SpanKind.SERVER }
    );
  }

  // Trace a turn
  async traceTurn<T>(
    agentId: string,
    turn: number,
    fn: () => Promise<T>
  ): Promise<T> {
    const parentSpan = this.activeSpans.get(agentId);
    if (!parentSpan) {
      return fn();
    }

    const span = this.tracer.childSpan(parentSpan, 'agent.turn');
    span.setAttribute('agent.turn', turn);

    try {
      const result = await fn();
      span.setStatus({ code: SpanStatusCode.OK });
      return result;
    } catch (error) {
      span.setStatus({ code: SpanStatusCode.ERROR });
      span.recordException(error as Error);
      throw error;
    } finally {
      span.end();
    }
  }

  // Trace tool call
  async traceToolCall<T>(
    agentId: string,
    toolName: string,
    params: Record<string, unknown>,
    fn: () => Promise<T>
  ): Promise<T> {
    const parentSpan = this.activeSpans.get(agentId);

    return this.tracer.trace(
      `tool.${toolName}`,
      async (span) => {
        span.setAttribute('tool.name', toolName);
        span.setAttribute('tool.params', JSON.stringify(params));

        return fn();
      },
      {
        kind: SpanKind.CLIENT,
        attributes: { 'agent.id': agentId }
      }
    );
  }

  // Trace API call
  async traceAPICall<T>(
    agentId: string,
    model: string,
    fn: () => Promise<T>
  ): Promise<T> {
    return this.tracer.trace(
      'api.call',
      async (span) => {
        span.setAttribute('api.model', model);
        span.setAttribute('agent.id', agentId);

        const result = await fn();

        // Add token usage if available
        if (typeof result === 'object' && result !== null) {
          const usage = (result as any).usage;
          if (usage) {
            span.setAttribute('api.input_tokens', usage.input_tokens);
            span.setAttribute('api.output_tokens', usage.output_tokens);
          }
        }

        return result;
      },
      { kind: SpanKind.CLIENT }
    );
  }
}
```

### 9.3 Structured Logging

```typescript
// Structured logging with context propagation
class Logger {
  private level: LogLevel;
  private outputs: LogOutput[];
  private contextStore: AsyncLocalStorage<LogContext>;

  constructor(config: LoggerConfig) {
    this.level = config.level;
    this.outputs = config.outputs.map(o => this.createOutput(o));
    this.contextStore = new AsyncLocalStorage();
  }

  // Log methods
  debug(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.DEBUG, message, data);
  }

  info(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.INFO, message, data);
  }

  warn(message: string, data?: Record<string, unknown>): void {
    this.log(LogLevel.WARN, message, data);
  }

  error(message: string, error?: Error, data?: Record<string, unknown>): void {
    this.log(LogLevel.ERROR, message, {
      ...data,
      error: error ? {
        name: error.name,
        message: error.message,
        stack: error.stack
      } : undefined
    });
  }

  // Run with context
  withContext<T>(context: Partial<LogContext>, fn: () => T): T {
    const currentContext = this.contextStore.getStore() ?? {};
    const newContext = { ...currentContext, ...context };

    return this.contextStore.run(newContext, fn);
  }

  // Create child logger with bound context
  child(context: Partial<LogContext>): Logger {
    const childLogger = new Logger({
      level: this.level,
      outputs: this.outputs.map(o => o.config)
    });

    // Bind context
    childLogger.contextStore = this.contextStore;

    return childLogger;
  }

  private log(level: LogLevel, message: string, data?: Record<string, unknown>): void {
    if (level < this.level) return;

    const context = this.contextStore.getStore() ?? {};
    const entry: LogEntry = {
      timestamp: new Date().toISOString(),
      level: LogLevel[level],
      message,
      ...context,
      ...data
    };

    for (const output of this.outputs) {
      output.write(entry);
    }
  }
}

enum LogLevel {
  DEBUG = 0,
  INFO = 1,
  WARN = 2,
  ERROR = 3
}

interface LogContext {
  agentId?: string;
  taskId?: string;
  traceId?: string;
  spanId?: string;
  userId?: string;
  turn?: number;
  tool?: string;
}

interface LogEntry extends LogContext {
  timestamp: string;
  level: string;
  message: string;
  [key: string]: unknown;
}

// JSON output
class JSONLogOutput implements LogOutput {
  constructor(private stream: NodeJS.WritableStream) {}

  write(entry: LogEntry): void {
    this.stream.write(JSON.stringify(entry) + '\n');
  }
}

// Pretty console output
class ConsoleLogOutput implements LogOutput {
  private colors: Record<string, string> = {
    DEBUG: '\x1b[36m',  // Cyan
    INFO: '\x1b[32m',   // Green
    WARN: '\x1b[33m',   // Yellow
    ERROR: '\x1b[31m'   // Red
  };

  write(entry: LogEntry): void {
    const color = this.colors[entry.level] ?? '\x1b[0m';
    const reset = '\x1b[0m';

    const contextParts = [];
    if (entry.agentId) contextParts.push(`agent=${entry.agentId}`);
    if (entry.taskId) contextParts.push(`task=${entry.taskId}`);
    if (entry.turn !== undefined) contextParts.push(`turn=${entry.turn}`);
    if (entry.tool) contextParts.push(`tool=${entry.tool}`);

    const contextStr = contextParts.length > 0 ? ` [${contextParts.join(' ')}]` : '';

    console.log(
      `${entry.timestamp} ${color}${entry.level}${reset}${contextStr}: ${entry.message}`
    );

    // Log additional data
    const { timestamp, level, message, agentId, taskId, traceId, spanId, userId, turn, tool, ...rest } = entry;
    if (Object.keys(rest).length > 0) {
      console.log('  ', JSON.stringify(rest, null, 2));
    }
  }
}
```

---

## 10. Security Architecture

### 10.1 Authentication & Authorization

```typescript
// Security layer for agent operations
class SecurityManager {
  private authenticator: Authenticator;
  private authorizer: Authorizer;
  private auditor: SecurityAuditor;

  constructor(config: SecurityConfig) {
    this.authenticator = new Authenticator(config.auth);
    this.authorizer = new Authorizer(config.rbac);
    this.auditor = new SecurityAuditor(config.audit);
  }

  // Authenticate a request
  async authenticate(credentials: Credentials): Promise<AuthResult> {
    const result = await this.authenticator.authenticate(credentials);

    await this.auditor.log({
      event: 'authentication',
      success: result.authenticated,
      principal: result.principal?.id,
      reason: result.reason
    });

    return result;
  }

  // Authorize an operation
  async authorize(
    principal: Principal,
    resource: Resource,
    action: Action
  ): Promise<AuthzResult> {
    const result = await this.authorizer.authorize(principal, resource, action);

    await this.auditor.log({
      event: 'authorization',
      success: result.allowed,
      principal: principal.id,
      resource: resource.id,
      action,
      reason: result.reason
    });

    return result;
  }

  // Check tool permissions
  async canExecuteTool(
    principal: Principal,
    tool: string,
    params: Record<string, unknown>
  ): Promise<boolean> {
    const resource: Resource = {
      id: `tool:${tool}`,
      type: 'tool',
      attributes: { tool, params }
    };

    const result = await this.authorize(principal, resource, 'execute');
    return result.allowed;
  }

  // Validate tool parameters
  validateToolParams(
    tool: string,
    params: Record<string, unknown>,
    policy: ToolPolicy
  ): ValidationResult {
    const violations: Violation[] = [];

    // Check forbidden parameters
    for (const [param, value] of Object.entries(params)) {
      const restriction = policy.parameterRestrictions?.[param];

      if (restriction) {
        // Check denied values
        if (restriction.deniedValues?.includes(value)) {
          violations.push({
            type: 'denied_value',
            param,
            value,
            message: `Value "${value}" is not allowed for parameter "${param}"`
          });
        }

        // Check allowed values
        if (restriction.allowedValues && !restriction.allowedValues.includes(value)) {
          violations.push({
            type: 'not_allowed',
            param,
            value,
            message: `Value "${value}" is not in allowed list for parameter "${param}"`
          });
        }

        // Check pattern
        if (restriction.pattern && typeof value === 'string') {
          if (!new RegExp(restriction.pattern).test(value)) {
            violations.push({
              type: 'pattern_mismatch',
              param,
              value,
              message: `Value "${value}" does not match pattern for parameter "${param}"`
            });
          }
        }
      }
    }

    // Check for dangerous patterns in bash commands
    if (tool === 'Bash' && params.command) {
      const dangerous = this.checkDangerousCommand(params.command as string);
      if (dangerous) {
        violations.push({
          type: 'dangerous_command',
          param: 'command',
          value: params.command,
          message: dangerous.message
        });
      }
    }

    return {
      valid: violations.length === 0,
      violations
    };
  }

  private checkDangerousCommand(command: string): { message: string } | null {
    const patterns = [
      { pattern: /rm\s+-rf\s+\/(?!\w)/, message: 'Recursive delete of root directory' },
      { pattern: />\s*\/dev\/sd/, message: 'Direct write to block device' },
      { pattern: /mkfs/, message: 'Filesystem format command' },
      { pattern: /dd\s+.*of=\/dev/, message: 'Direct disk write' },
      { pattern: /:(){ :|:& };:/, message: 'Fork bomb' },
      { pattern: /wget.*\|\s*bash/, message: 'Remote script execution' },
      { pattern: /curl.*\|\s*sh/, message: 'Remote script execution' }
    ];

    for (const { pattern, message } of patterns) {
      if (pattern.test(command)) {
        return { message };
      }
    }

    return null;
  }
}

// Role-based access control
class RBACAuthorizer implements Authorizer {
  private roles: Map<string, Role> = new Map();
  private assignments: Map<string, string[]> = new Map();  // principal -> roles

  constructor(config: RBACConfig) {
    this.loadRoles(config.roles);
    this.loadAssignments(config.assignments);
  }

  async authorize(
    principal: Principal,
    resource: Resource,
    action: Action
  ): Promise<AuthzResult> {
    const principalRoles = this.assignments.get(principal.id) ?? [];

    for (const roleName of principalRoles) {
      const role = this.roles.get(roleName);
      if (!role) continue;

      // Check permissions
      for (const permission of role.permissions) {
        if (this.matchesPermission(permission, resource, action)) {
          return { allowed: true, role: roleName };
        }
      }
    }

    return {
      allowed: false,
      reason: 'No matching permission found'
    };
  }

  private matchesPermission(
    permission: Permission,
    resource: Resource,
    action: Action
  ): boolean {
    // Check resource type
    if (permission.resourceType !== '*' && permission.resourceType !== resource.type) {
      return false;
    }

    // Check resource pattern
    if (permission.resourcePattern) {
      const regex = new RegExp(permission.resourcePattern);
      if (!regex.test(resource.id)) {
        return false;
      }
    }

    // Check action
    if (!permission.actions.includes('*') && !permission.actions.includes(action)) {
      return false;
    }

    // Check conditions
    if (permission.conditions) {
      for (const condition of permission.conditions) {
        if (!this.evaluateCondition(condition, resource)) {
          return false;
        }
      }
    }

    return true;
  }
}

interface Role {
  name: string;
  description?: string;
  permissions: Permission[];
  inherits?: string[];            // Inherit from other roles
}

interface Permission {
  resourceType: string;           // 'tool', 'file', '*'
  resourcePattern?: string;       // Regex pattern
  actions: Action[];              // 'execute', 'read', 'write', '*'
  conditions?: Condition[];
}

type Action = 'execute' | 'read' | 'write' | 'delete' | 'create' | '*';

interface Condition {
  type: 'attribute' | 'time' | 'ip' | 'custom';
  attribute?: string;
  operator: 'eq' | 'ne' | 'in' | 'nin' | 'regex' | 'gt' | 'lt';
  value: unknown;
}
```

### 10.2 Secrets Management

```typescript
// Secure secrets handling
class SecretsManager {
  private vault: SecretVault;
  private cache: SecretCache;
  private auditor: SecretsAuditor;

  constructor(config: SecretsConfig) {
    this.vault = this.createVault(config.vault);
    this.cache = new SecretCache(config.cache);
    this.auditor = new SecretsAuditor(config.audit);
  }

  // Get a secret
  async get(path: string, options?: GetSecretOptions): Promise<Secret> {
    // Check cache
    if (!options?.skipCache) {
      const cached = await this.cache.get(path);
      if (cached) {
        await this.auditor.log({
          action: 'get',
          path,
          source: 'cache',
          accessor: options?.accessor
        });
        return cached;
      }
    }

    // Fetch from vault
    const secret = await this.vault.get(path);

    // Cache if allowed
    if (!options?.noCache && secret.cacheable) {
      await this.cache.set(path, secret);
    }

    await this.auditor.log({
      action: 'get',
      path,
      source: 'vault',
      accessor: options?.accessor
    });

    return secret;
  }

  // Set a secret
  async set(path: string, value: string, metadata?: SecretMetadata): Promise<void> {
    await this.vault.set(path, value, metadata);
    await this.cache.invalidate(path);

    await this.auditor.log({
      action: 'set',
      path,
      accessor: metadata?.createdBy
    });
  }

  // Delete a secret
  async delete(path: string, options?: DeleteSecretOptions): Promise<void> {
    await this.vault.delete(path);
    await this.cache.invalidate(path);

    await this.auditor.log({
      action: 'delete',
      path,
      accessor: options?.accessor
    });
  }

  // Rotate a secret
  async rotate(path: string, generator: () => Promise<string>): Promise<void> {
    const newValue = await generator();
    const oldSecret = await this.vault.get(path);

    // Store new version
    await this.vault.set(path, newValue, {
      previousVersion: oldSecret.version,
      rotatedAt: Date.now()
    });

    await this.cache.invalidate(path);

    await this.auditor.log({
      action: 'rotate',
      path,
      oldVersion: oldSecret.version
    });
  }

  // Mask secrets in output
  maskSecrets(text: string, paths: string[]): Promise<string> {
    let masked = text;

    for (const path of paths) {
      const secret = this.cache.get(path);
      if (secret) {
        masked = masked.replace(
          new RegExp(escapeRegex(secret.value), 'g'),
          '[REDACTED]'
        );
      }
    }

    return masked;
  }
}

interface Secret {
  value: string;
  version: number;
  createdAt: number;
  expiresAt?: number;
  metadata?: SecretMetadata;
  cacheable: boolean;
}

interface SecretMetadata {
  description?: string;
  createdBy?: string;
  rotationPolicy?: RotationPolicy;
  tags?: Record<string, string>;
}

interface RotationPolicy {
  enabled: boolean;
  intervalDays: number;
  lastRotated?: number;
  nextRotation?: number;
}

// Environment-based secrets for tool execution
class ToolSecretsInjector {
  private secretsManager: SecretsManager;
  private mappings: Map<string, SecretMapping[]> = new Map();

  constructor(secretsManager: SecretsManager, config: InjectorConfig) {
    this.secretsManager = secretsManager;
    this.loadMappings(config.mappings);
  }

  // Inject secrets into environment
  async injectEnvironment(
    tool: string,
    env: Record<string, string>
  ): Promise<Record<string, string>> {
    const mappings = this.mappings.get(tool) ?? [];
    const injected = { ...env };

    for (const mapping of mappings) {
      const secret = await this.secretsManager.get(mapping.secretPath);
      injected[mapping.envVar] = secret.value;
    }

    return injected;
  }

  // Redact secrets from output
  async redactOutput(tool: string, output: string): Promise<string> {
    const mappings = this.mappings.get(tool) ?? [];
    let redacted = output;

    for (const mapping of mappings) {
      const secret = await this.secretsManager.get(mapping.secretPath);
      redacted = redacted.replace(
        new RegExp(escapeRegex(secret.value), 'g'),
        `[${mapping.envVar}]`
      );
    }

    return redacted;
  }
}

interface SecretMapping {
  secretPath: string;             // Path in secrets manager
  envVar: string;                 // Environment variable name
  required?: boolean;
}
```

---

## 11. Implementation Patterns

### 11.1 Plugin Architecture

```typescript
// Extensible plugin system
interface Plugin {
  name: string;
  version: string;

  // Lifecycle
  onLoad(context: PluginContext): Promise<void>;
  onUnload(): Promise<void>;

  // Extension points
  registerHooks?(hookManager: HookManager): void;
  registerTools?(toolRegistry: ToolRegistry): void;
  registerResources?(resourceRegistry: ResourceRegistry): void;
  registerPolicies?(policyRegistry: PolicyRegistry): void;
}

class PluginManager {
  private plugins: Map<string, LoadedPlugin> = new Map();
  private context: PluginContext;

  constructor(config: PluginManagerConfig) {
    this.context = this.createContext(config);
  }

  // Load plugin from path
  async load(path: string): Promise<void> {
    const module = await import(path);
    const plugin: Plugin = module.default;

    // Validate
    this.validatePlugin(plugin);

    // Load
    await plugin.onLoad(this.context);

    // Register extensions
    if (plugin.registerHooks) {
      plugin.registerHooks(this.context.hookManager);
    }
    if (plugin.registerTools) {
      plugin.registerTools(this.context.toolRegistry);
    }
    if (plugin.registerResources) {
      plugin.registerResources(this.context.resourceRegistry);
    }
    if (plugin.registerPolicies) {
      plugin.registerPolicies(this.context.policyRegistry);
    }

    this.plugins.set(plugin.name, { plugin, path, loadedAt: Date.now() });
  }

  // Unload plugin
  async unload(name: string): Promise<void> {
    const loaded = this.plugins.get(name);
    if (!loaded) return;

    await loaded.plugin.onUnload();
    this.plugins.delete(name);
  }

  // Hot reload plugin
  async reload(name: string): Promise<void> {
    const loaded = this.plugins.get(name);
    if (!loaded) return;

    await this.unload(name);
    await this.load(loaded.path);
  }
}

// Example plugin: Rate Limit Override
const RateLimitOverridePlugin: Plugin = {
  name: 'rate-limit-override',
  version: '1.0.0',

  async onLoad(context) {
    console.log('Rate limit override plugin loaded');
  },

  async onUnload() {
    console.log('Rate limit override plugin unloaded');
  },

  registerHooks(hookManager) {
    hookManager.register(HookType.TOOL_BEFORE_CALL, async (ctx) => {
      // Check if this is a high-priority task
      if (ctx.metadata?.priority === 'critical') {
        // Bypass rate limiting for critical tasks
        return {
          modified: true,
          context: { ...ctx, bypassRateLimit: true }
        };
      }
      return { modified: false };
    });
  },

  registerPolicies(policyRegistry) {
    policyRegistry.register({
      name: 'critical-task-override',
      async onLimitExceeded(agentId, resourceType, result) {
        // Check if agent is running critical task
        const agent = await this.getAgent(agentId);
        if (agent?.metadata?.priority === 'critical') {
          return { action: 'allow', reason: 'critical_task_override' };
        }
        return { action: 'deny' };
      }
    });
  }
};
```

### 11.2 Middleware Pattern

```typescript
// Composable middleware chain
type Middleware<T> = (context: T, next: () => Promise<T>) => Promise<T>;

class MiddlewareChain<T> {
  private middlewares: Middleware<T>[] = [];

  use(middleware: Middleware<T>): this {
    this.middlewares.push(middleware);
    return this;
  }

  async execute(context: T): Promise<T> {
    let index = 0;

    const dispatch = async (ctx: T): Promise<T> => {
      if (index >= this.middlewares.length) {
        return ctx;
      }

      const middleware = this.middlewares[index++];
      return middleware(ctx, () => dispatch(ctx));
    };

    return dispatch(context);
  }
}

// Example: Tool execution middleware chain
const toolMiddleware = new MiddlewareChain<ToolExecutionContext>();

// Logging middleware
toolMiddleware.use(async (ctx, next) => {
  console.log(`Starting tool: ${ctx.toolName}`);
  const startTime = Date.now();

  const result = await next();

  console.log(`Completed tool: ${ctx.toolName} in ${Date.now() - startTime}ms`);
  return result;
});

// Validation middleware
toolMiddleware.use(async (ctx, next) => {
  const validation = validateParams(ctx.params, ctx.schema);
  if (!validation.valid) {
    throw new ValidationError(validation.errors);
  }
  return next();
});

// Rate limiting middleware
toolMiddleware.use(async (ctx, next) => {
  const allowed = await rateLimiter.check(ctx.agentId, ctx.toolName);
  if (!allowed) {
    throw new RateLimitError(ctx.toolName);
  }
  return next();
});

// Caching middleware
toolMiddleware.use(async (ctx, next) => {
  if (ctx.cacheable) {
    const cached = await cache.get(ctx.cacheKey);
    if (cached) return { ...ctx, result: cached };
  }

  const result = await next();

  if (ctx.cacheable && result.success) {
    await cache.set(ctx.cacheKey, result.result);
  }

  return result;
});
```

### 11.3 Event-Driven Architecture

```typescript
// Event bus for decoupled components
class EventBus {
  private handlers: Map<string, Set<EventHandler>> = new Map();
  private asyncHandlers: Map<string, Set<AsyncEventHandler>> = new Map();

  // Synchronous event handling
  on(event: string, handler: EventHandler): Unsubscribe {
    const handlers = this.handlers.get(event) ?? new Set();
    handlers.add(handler);
    this.handlers.set(event, handlers);

    return () => handlers.delete(handler);
  }

  // Async event handling
  onAsync(event: string, handler: AsyncEventHandler): Unsubscribe {
    const handlers = this.asyncHandlers.get(event) ?? new Set();
    handlers.add(handler);
    this.asyncHandlers.set(event, handlers);

    return () => handlers.delete(handler);
  }

  // Emit event (fire and forget)
  emit(event: string, data?: unknown): void {
    const handlers = this.handlers.get(event);
    if (handlers) {
      for (const handler of handlers) {
        try {
          handler(data);
        } catch (error) {
          console.error(`Error in event handler for ${event}:`, error);
        }
      }
    }

    // Fire async handlers without waiting
    const asyncHandlers = this.asyncHandlers.get(event);
    if (asyncHandlers) {
      for (const handler of asyncHandlers) {
        handler(data).catch(error => {
          console.error(`Error in async event handler for ${event}:`, error);
        });
      }
    }
  }

  // Emit and wait for all handlers
  async emitAsync(event: string, data?: unknown): Promise<void> {
    // Run sync handlers
    this.emit(event, data);

    // Wait for async handlers
    const asyncHandlers = this.asyncHandlers.get(event);
    if (asyncHandlers) {
      await Promise.all(
        Array.from(asyncHandlers).map(handler => handler(data))
      );
    }
  }
}

// Event types
const AgentEvents = {
  STARTED: 'agent:started',
  TURN_STARTED: 'agent:turn_started',
  TURN_COMPLETED: 'agent:turn_completed',
  TOOL_CALLED: 'agent:tool_called',
  TOOL_COMPLETED: 'agent:tool_completed',
  COMPLETED: 'agent:completed',
  FAILED: 'agent:failed',
  SUSPENDED: 'agent:suspended',
  RESUMED: 'agent:resumed'
} as const;

const TaskEvents = {
  SUBMITTED: 'task:submitted',
  SCHEDULED: 'task:scheduled',
  STARTED: 'task:started',
  PROGRESS: 'task:progress',
  COMPLETED: 'task:completed',
  FAILED: 'task:failed',
  CANCELLED: 'task:cancelled'
} as const;

const ResourceEvents = {
  LIMIT_WARNING: 'resource:limit_warning',
  LIMIT_EXCEEDED: 'resource:limit_exceeded',
  QUOTA_RESET: 'resource:quota_reset'
} as const;
```

### 11.4 Configuration Management

```typescript
// Hierarchical configuration with hot reload
class ConfigManager {
  private configs: Map<string, ConfigLayer> = new Map();
  private cache: Map<string, unknown> = new Map();
  private watchers: Map<string, FileWatcher> = new Map();

  constructor(private layers: ConfigLayerDefinition[]) {
    this.initializeLayers();
  }

  // Get config value with dot notation
  get<T>(path: string, defaultValue?: T): T {
    // Check cache
    if (this.cache.has(path)) {
      return this.cache.get(path) as T;
    }

    // Search layers (higher priority first)
    for (const layer of this.sortedLayers()) {
      const value = this.getFromLayer(layer, path);
      if (value !== undefined) {
        this.cache.set(path, value);
        return value as T;
      }
    }

    return defaultValue as T;
  }

  // Set config value
  set(path: string, value: unknown, layer: string = 'runtime'): void {
    const config = this.configs.get(layer);
    if (!config) throw new Error(`Unknown config layer: ${layer}`);

    this.setInLayer(config, path, value);
    this.cache.delete(path);

    // Persist if layer supports it
    if (config.persistent) {
      this.persistLayer(layer);
    }
  }

  // Watch for changes
  watch(path: string, callback: (newValue: unknown, oldValue: unknown) => void): Unsubscribe {
    // Implementation
    return () => {};
  }

  // Reload all configs
  async reload(): Promise<void> {
    this.cache.clear();

    for (const [name, layer] of this.configs) {
      if (layer.source) {
        await this.loadLayer(name, layer.source);
      }
    }
  }
}

// Configuration schema
interface ConfigSchema {
  agent: {
    maxTurns: number;
    turnTimeout: number;
    model: {
      id: string;
      maxTokens: number;
      temperature: number;
    };
  };
  tools: {
    timeout: number;
    retries: number;
    parallelLimit: number;
  };
  resources: {
    tokens: {
      perMinute: number;
      perHour: number;
      perDay: number;
    };
    rateLimits: {
      apiCalls: number;
      toolCalls: number;
    };
  };
  observability: {
    metrics: {
      enabled: boolean;
      endpoint: string;
    };
    tracing: {
      enabled: boolean;
      samplingRate: number;
    };
    logging: {
      level: string;
      format: string;
    };
  };
}
```

---

## 12. Verification Strategy

### 12.1 Unit Testing

```typescript
// Test framework for agent components
describe('Agent Lifecycle', () => {
  let agent: TestAgent;
  let mockModel: MockModelClient;

  beforeEach(() => {
    mockModel = new MockModelClient();
    agent = new TestAgent({
      model: mockModel,
      maxTurns: 10,
      tools: [mockTool('read'), mockTool('write')]
    });
  });

  it('should execute turns until completion', async () => {
    mockModel.setResponses([
      { text: 'Let me read the file', toolCalls: [{ name: 'read', params: { path: '/test.txt' } }] },
      { text: 'Done reading', toolCalls: [] }
    ]);

    const result = await agent.execute('Read /test.txt');

    expect(result.turns).toBe(2);
    expect(result.completed).toBe(true);
    expect(agent.getToolCalls()).toHaveLength(1);
  });

  it('should respect max turns limit', async () => {
    mockModel.setResponses(Array(15).fill({
      text: 'Still working...',
      toolCalls: [{ name: 'read', params: { path: '/test.txt' } }]
    }));

    const result = await agent.execute('Infinite task');

    expect(result.turns).toBe(10);
    expect(result.completed).toBe(false);
    expect(result.reason).toBe('max_turns_reached');
  });

  it('should handle tool errors gracefully', async () => {
    mockModel.setResponses([
      { text: 'Let me try', toolCalls: [{ name: 'read', params: { path: '/nonexistent.txt' } }] },
      { text: 'File not found, trying alternative', toolCalls: [] }
    ]);

    // Make read tool throw error
    agent.getTools().get('read')!.execute = async () => {
      throw new Error('File not found');
    };

    const result = await agent.execute('Read missing file');

    expect(result.completed).toBe(true);
    expect(agent.getErrors()).toHaveLength(1);
  });
});

// Hook testing
describe('Hook System', () => {
  let hookManager: HookManager;

  beforeEach(() => {
    hookManager = new HookManager({});
  });

  it('should execute hooks in priority order', async () => {
    const order: number[] = [];

    hookManager.register(HookType.TOOL_BEFORE_CALL, async () => {
      order.push(1);
      return { modified: false };
    }, { priority: 10 });

    hookManager.register(HookType.TOOL_BEFORE_CALL, async () => {
      order.push(2);
      return { modified: false };
    }, { priority: 20 });

    await hookManager.execute(HookType.TOOL_BEFORE_CALL, { toolName: 'test' });

    expect(order).toEqual([2, 1]);  // Higher priority first
  });

  it('should allow hooks to modify context', async () => {
    hookManager.register(HookType.TOOL_BEFORE_CALL, async (ctx) => {
      return {
        modified: true,
        context: { ...ctx, params: { ...ctx.params, modified: true } }
      };
    });

    const result = await hookManager.execute(HookType.TOOL_BEFORE_CALL, {
      toolName: 'test',
      params: { original: true }
    });

    expect(result.finalContext.params.modified).toBe(true);
  });

  it('should abort on hook request', async () => {
    hookManager.register(HookType.TOOL_BEFORE_CALL, async () => {
      return { abort: true, abortReason: 'Blocked by policy' };
    });

    const result = await hookManager.execute(HookType.TOOL_BEFORE_CALL, { toolName: 'test' });

    expect(result.aborted).toBe(true);
    expect(result.reason).toBe('Blocked by policy');
  });
});
```

### 12.2 Integration Testing

```typescript
// End-to-end integration tests
describe('Integration: Background Task Execution', () => {
  let system: TestSystem;

  beforeAll(async () => {
    system = await TestSystem.create({
      useRealAPI: false,
      mockResponses: true
    });
  });

  afterAll(async () => {
    await system.shutdown();
  });

  it('should execute background task and return results', async () => {
    const taskId = await system.submitTask({
      prompt: 'List files in /tmp',
      runInBackground: true
    });

    // Wait for completion
    const result = await system.waitForTask(taskId, { timeout: 30000 });

    expect(result.status).toBe('completed');
    expect(result.output).toContain('files');
  });

  it('should handle task dependencies correctly', async () => {
    const task1Id = await system.submitTask({ prompt: 'Create file /tmp/test.txt' });
    const task2Id = await system.submitTask({
      prompt: 'Read file /tmp/test.txt',
      dependencies: [task1Id]
    });

    // Task 2 should wait for task 1
    const status = await system.getTaskStatus(task2Id);
    expect(status.state).toBe('pending');

    // Complete task 1
    await system.waitForTask(task1Id);

    // Now task 2 should run
    const result = await system.waitForTask(task2Id);
    expect(result.status).toBe('completed');
  });

  it('should respect resource limits', async () => {
    // Set low token limit
    system.setResourceLimit('tokens', 100);

    const result = await system.submitAndWait({
      prompt: 'Write a very long essay'
    });

    expect(result.status).toBe('failed');
    expect(result.error).toContain('token limit');
  });
});
```

### 12.3 Performance Testing

```typescript
// Performance benchmarks
describe('Performance', () => {
  it('should handle 100 concurrent tasks', async () => {
    const system = await TestSystem.create({ maxWorkers: 10 });

    const tasks = Array(100).fill(null).map((_, i) =>
      system.submitTask({ prompt: `Task ${i}` })
    );

    const start = Date.now();
    const results = await Promise.all(tasks.map(id => system.waitForTask(id)));
    const duration = Date.now() - start;

    expect(results.filter(r => r.status === 'completed')).toHaveLength(100);
    expect(duration).toBeLessThan(60000);  // Under 1 minute
  });

  it('should maintain low latency under load', async () => {
    const system = await TestSystem.create();
    const latencies: number[] = [];

    for (let i = 0; i < 50; i++) {
      const start = Date.now();
      await system.submitAndWait({ prompt: `Quick task ${i}` });
      latencies.push(Date.now() - start);
    }

    const avgLatency = latencies.reduce((a, b) => a + b) / latencies.length;
    const p99Latency = latencies.sort((a, b) => a - b)[Math.floor(latencies.length * 0.99)];

    expect(avgLatency).toBeLessThan(5000);
    expect(p99Latency).toBeLessThan(10000);
  });
});
```

### 12.4 Verification Checklist

```markdown
## Pre-Deployment Checklist

### Core Functionality
- [ ] Agent lifecycle (init, execute, complete, error) works correctly
- [ ] Tool execution succeeds for all registered tools
- [ ] Background tasks run and complete successfully
- [ ] Task resume functionality works after restart
- [ ] Checkpoint creation and restoration works

### Resource Management
- [ ] Token limits are enforced correctly
- [ ] Rate limiting prevents excessive API calls
- [ ] Memory usage stays within bounds
- [ ] Concurrent task limits are respected

### Security
- [ ] Authentication works for all credential types
- [ ] Authorization correctly blocks unauthorized operations
- [ ] Dangerous commands are blocked
- [ ] Secrets are not leaked in logs or output

### Observability
- [ ] Metrics are exported correctly
- [ ] Traces capture full request lifecycle
- [ ] Logs contain sufficient context for debugging
- [ ] Alerts fire on threshold breaches

### Integration
- [ ] MCP servers connect and respond
- [ ] Hooks execute in correct order
- [ ] Plugin loading/unloading works
- [ ] Configuration hot-reload works

### Performance
- [ ] Latency meets SLA under normal load
- [ ] System handles burst traffic
- [ ] No memory leaks during extended operation
- [ ] Graceful degradation under overload
```

---

## Critical Files to Modify

When implementing this system, the following files/modules are critical:

1. **Agent Runtime**: `src/agent/runtime.ts`
2. **Process Manager**: `src/process/manager.ts`
3. **MCP Server**: `src/mcp/server.ts`
4. **Hook Manager**: `src/hooks/manager.ts`
5. **Task Scheduler**: `src/scheduler/scheduler.ts`
6. **State Store**: `src/state/store.ts`
7. **Resource Governor**: `src/resources/governor.ts`
8. **Metrics Collector**: `src/observability/metrics.ts`
9. **Security Manager**: `src/security/manager.ts`
10. **Configuration**: `src/config/manager.ts`

---

## Summary

This architecture provides comprehensive low-level control over Claude Code background tasks through:

1. **Agent SDK** - Full lifecycle control, custom agent types, composition patterns
2. **MCP Servers** - Standardized tool extension with virtualization, caching, circuit breakers
3. **Hooks System** - Pre/post execution interception at all levels
4. **Task Orchestration** - Priority scheduling, dependency graphs, fair-share policies
5. **State Management** - Hierarchical storage, checkpointing, recovery
6. **Resource Governance** - Multi-dimensional limiting (tokens, compute, I/O)
7. **Observability** - Metrics, tracing, structured logging
8. **Security** - RBAC, secrets management, audit logging

The modular design allows selective adoption of components based on your specific requirements.
