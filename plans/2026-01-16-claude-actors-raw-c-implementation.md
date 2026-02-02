# Claude Actors - Raw C Implementation Plan

## Overview

Build a pure C implementation of the Claude Actors system with maximum low-level control:
- Raw TCP sockets for network communication
- OpenSSL for TLS encryption (manual handshake control)
- Hand-crafted HTTP/1.1 protocol implementation
- Server-Sent Events (SSE) parsing for streaming tokens
- Custom JSON parser (no external dependencies)
- Thread-based parallelism for concurrent actor requests

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Claude Actors System                                │
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                  │
│  │   main.c     │───▶│ orchestrator │───▶│  file_output │                  │
│  │  (CLI/args)  │    │   (actors)   │    │   (.md files)│                  │
│  └──────────────┘    └──────────────┘    └──────────────┘                  │
│         │                   │                                               │
│         ▼                   ▼                                               │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                     claude_api.h                              │          │
│  │  - Build request JSON                                         │          │
│  │  - Parse response JSON                                        │          │
│  │  - Handle streaming (SSE)                                     │          │
│  └──────────────────────────────────────────────────────────────┘          │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                     http_client.h                             │          │
│  │  - HTTP/1.1 request building                                  │          │
│  │  - Header parsing                                             │          │
│  │  - Chunked transfer encoding                                  │          │
│  │  - Connection: keep-alive                                     │          │
│  └──────────────────────────────────────────────────────────────┘          │
│         │                                                                   │
│         ▼                                                                   │
│  ┌──────────────────────────────────────────────────────────────┐          │
│  │                     tls_socket.h                              │          │
│  │  - Raw TCP socket creation                                    │          │
│  │  - OpenSSL/LibreSSL TLS handshake                            │          │
│  │  - Certificate verification                                   │          │
│  │  - Non-blocking I/O support                                   │          │
│  └──────────────────────────────────────────────────────────────┘          │
│         │                                                                   │
│         ▼                                                                   │
│  ┌────────────────────────────────────┐                                    │
│  │        api.anthropic.com:443       │                                    │
│  └────────────────────────────────────┘                                    │
└─────────────────────────────────────────────────────────────────────────────┘
```

## File Structure

```
claude_actors/
├── claude_actors_main.c      # Entry point, CLI argument parsing
├── claude_actors.h           # Orchestration: actors + judge workflow
├── claude_api.h              # Claude Messages API implementation
├── http_client.h             # Raw HTTP/1.1 protocol
├── tls_socket.h              # TCP + TLS (OpenSSL)
├── json_builder.h            # JSON serialization (request building)
├── json_parser.h             # JSON parsing (response handling)
├── sse_parser.h              # Server-Sent Events stream parsing
├── README.md                 # Generated session summary
├── actor_1.md                # Actor 1 output
├── actor_2.md                # Actor 2 output
├── actor_3.md                # Actor 3 output
└── claude_judge.md           # Judge evaluation
```

## Implementation Details

### 1. TLS Socket Layer (`tls_socket.h`)

```c
// Raw socket + OpenSSL TLS wrapper
typedef struct {
    int fd;                     // Raw TCP socket file descriptor
    SSL_CTX *ssl_ctx;          // OpenSSL context
    SSL *ssl;                  // TLS session
    char host[256];            // Remote host
    uint16_t port;             // Remote port (443)
    bool connected;

    // Metrics (full visibility)
    size_t bytes_sent;
    size_t bytes_received;
    uint64_t connect_time_us;  // Connection establishment time
    uint64_t handshake_time_us; // TLS handshake time
} TLSSocket;

// Low-level operations
int tls_socket_init(TLSSocket *s);
int tls_socket_connect(TLSSocket *s, const char *host, uint16_t port);
int tls_socket_set_nonblocking(TLSSocket *s, bool nonblocking);
ssize_t tls_socket_send(TLSSocket *s, const void *data, size_t len);
ssize_t tls_socket_recv(TLSSocket *s, void *buf, size_t len);
int tls_socket_poll(TLSSocket *s, int events, int timeout_ms);
void tls_socket_close(TLSSocket *s);

// Certificate inspection
int tls_socket_get_peer_cert_info(TLSSocket *s, char *subject, char *issuer, size_t len);
const char *tls_socket_get_cipher(TLSSocket *s);
```

### 2. HTTP Client Layer (`http_client.h`)

```c
// HTTP/1.1 implementation with full header control
typedef struct {
    char method[16];
    char path[1024];
    char headers[8192];         // Raw headers (full inspection)
    size_t header_count;
    char *body;
    size_t body_len;
} HTTPRequest;

typedef struct {
    int status_code;
    char status_text[64];
    char headers[8192];         // Raw response headers
    size_t header_count;
    char *body;
    size_t body_len;
    bool chunked;               // Transfer-Encoding: chunked
    bool streaming;             // Server-Sent Events mode
} HTTPResponse;

typedef struct {
    TLSSocket socket;
    HTTPRequest request;
    HTTPResponse response;

    // Connection pooling state
    bool keep_alive;
    int requests_on_connection;

    // Timing metrics
    uint64_t request_start_us;
    uint64_t first_byte_us;     // Time to first byte
    uint64_t complete_us;
} HTTPClient;

// Request building
void http_request_init(HTTPRequest *req, const char *method, const char *path);
void http_request_add_header(HTTPRequest *req, const char *name, const char *value);
void http_request_set_body(HTTPRequest *req, const char *body, size_t len);

// Raw send/receive
int http_client_send_request(HTTPClient *c);
int http_client_recv_response(HTTPClient *c);

// Streaming support
int http_client_recv_chunk(HTTPClient *c, char *buf, size_t *len);
```

### 3. SSE Parser (`sse_parser.h`)

```c
// Server-Sent Events parsing for streaming responses
typedef struct {
    char event[64];            // Event type
    char data[65536];          // Event data
    size_t data_len;
    char id[64];               // Event ID
    int retry;                 // Retry interval
} SSEEvent;

typedef struct {
    char buffer[131072];       // Parse buffer (128KB)
    size_t buffer_pos;
    size_t buffer_len;
    bool complete;
} SSEParser;

typedef void (*SSECallback)(const SSEEvent *event, void *ctx);

int sse_parser_init(SSEParser *p);
int sse_parser_feed(SSEParser *p, const char *data, size_t len);
int sse_parser_next_event(SSEParser *p, SSEEvent *event);
```

### 4. JSON Builder/Parser (`json_builder.h`, `json_parser.h`)

```c
// Minimal JSON builder for API requests
typedef struct {
    char *buffer;
    size_t capacity;
    size_t len;
    int depth;
} JSONBuilder;

void json_builder_init(JSONBuilder *b, char *buffer, size_t capacity);
void json_obj_start(JSONBuilder *b);
void json_obj_end(JSONBuilder *b);
void json_arr_start(JSONBuilder *b, const char *key);
void json_arr_end(JSONBuilder *b);
void json_add_string(JSONBuilder *b, const char *key, const char *value);
void json_add_int(JSONBuilder *b, const char *key, int64_t value);
void json_add_float(JSONBuilder *b, const char *key, double value);
void json_add_bool(JSONBuilder *b, const char *key, bool value);

// Minimal JSON parser for API responses
typedef enum {
    JSON_NULL, JSON_BOOL, JSON_NUMBER, JSON_STRING, JSON_ARRAY, JSON_OBJECT
} JSONType;

typedef struct JSONValue {
    JSONType type;
    union {
        bool boolean;
        double number;
        struct { char *str; size_t len; } string;
        struct { struct JSONValue *items; size_t count; } array;
        struct { char **keys; struct JSONValue *values; size_t count; } object;
    };
} JSONValue;

int json_parse(const char *text, size_t len, JSONValue *out);
JSONValue *json_get(JSONValue *obj, const char *path);  // e.g., "content[0].text"
void json_free(JSONValue *v);
```

### 5. Claude API Layer (`claude_api.h`)

```c
// Claude Messages API implementation
#define CLAUDE_API_HOST "api.anthropic.com"
#define CLAUDE_API_PORT 443
#define CLAUDE_API_PATH "/v1/messages"
#define CLAUDE_API_VERSION "2023-06-01"
#define CLAUDE_MODEL "claude-opus-4-5-20250514"

typedef struct {
    char role[16];              // "user" or "assistant"
    char *content;
    size_t content_len;
} ClaudeMessage;

typedef struct {
    char model[64];
    int max_tokens;
    double temperature;
    ClaudeMessage *messages;
    size_t message_count;
    bool stream;
} ClaudeRequest;

typedef struct {
    char id[64];
    char model[64];
    char stop_reason[32];
    char *content;
    size_t content_len;

    // Usage stats (full visibility)
    int input_tokens;
    int output_tokens;

    // Timing
    uint64_t request_time_us;
    uint64_t first_token_us;
    uint64_t complete_us;
} ClaudeResponse;

// Streaming callback
typedef void (*ClaudeStreamCallback)(const char *text, size_t len, void *ctx);

typedef struct {
    HTTPClient http;
    char api_key[256];

    // Stats across all requests
    int total_requests;
    int total_input_tokens;
    int total_output_tokens;
    uint64_t total_time_us;
} ClaudeClient;

int claude_client_init(ClaudeClient *c, const char *api_key);
int claude_client_connect(ClaudeClient *c);

// Non-streaming request
int claude_send_message(ClaudeClient *c, const ClaudeRequest *req, ClaudeResponse *resp);

// Streaming request (token by token)
int claude_send_message_streaming(
    ClaudeClient *c,
    const ClaudeRequest *req,
    ClaudeStreamCallback callback,
    void *ctx,
    ClaudeResponse *resp
);

void claude_client_close(ClaudeClient *c);
```

### 6. Actors Orchestrator (`claude_actors.h`)

```c
#define MAX_ACTORS 10
#define MAX_OUTPUT_SIZE (1024 * 1024)  // 1MB per actor

typedef struct {
    int actor_num;
    pthread_t thread;
    ClaudeClient client;
    char *output;
    size_t output_len;
    ClaudeResponse response;
    int status;  // 0 = pending, 1 = running, 2 = complete, -1 = error
    char error_msg[256];

    // Per-actor timing
    uint64_t start_time_us;
    uint64_t end_time_us;
} ActorContext;

typedef struct {
    char *prompt;
    int num_actors;
    double actor_temperature;
    double judge_temperature;
    int max_tokens;
    bool verbose;
    const char *output_dir;

    ActorContext actors[MAX_ACTORS];
    char *judge_output;
    size_t judge_output_len;
    ClaudeResponse judge_response;
} ClaudeActorsSystem;

// Main entry points
int claude_actors_init(ClaudeActorsSystem *sys, const char *api_key);
int claude_actors_run(ClaudeActorsSystem *sys, const char *prompt);
int claude_actors_save_outputs(ClaudeActorsSystem *sys);
void claude_actors_cleanup(ClaudeActorsSystem *sys);

// Actor thread function
void *actor_thread_func(void *arg);

// Generate prompts with ultrathink prefix
void format_actor_prompt(char *out, size_t out_size, const char *prompt, int actor_num);
void format_judge_prompt(char *out, size_t out_size, const char *prompt,
                         ActorContext *actors, int num_actors);
```

## Build System

```makefile
# Detect platform
UNAME := $(shell uname -s)

CC = clang
CFLAGS = -Wall -Wextra -O2 -std=c11 -D_GNU_SOURCE

# OpenSSL paths
ifeq ($(UNAME),Darwin)
    # macOS with Homebrew OpenSSL
    OPENSSL_PREFIX = $(shell brew --prefix openssl@3 2>/dev/null || echo /usr/local/opt/openssl)
    CFLAGS += -I$(OPENSSL_PREFIX)/include
    LDFLAGS = -L$(OPENSSL_PREFIX)/lib -lssl -lcrypto -lpthread
else
    # Linux
    LDFLAGS = -lssl -lcrypto -lpthread
endif

# Targets
ACTORS_SRC = claude_actors/claude_actors_main.c
ACTORS_BIN = build/claude-actors

all: $(ACTORS_BIN)

$(ACTORS_BIN): $(ACTORS_SRC)
	@mkdir -p build
	$(CC) $(CFLAGS) -o $@ $< $(LDFLAGS)

clean:
	rm -rf build/
```

## Control Points Exposed

### Network Level
- Raw TCP socket creation with `socket()`
- Non-blocking I/O with `fcntl(F_SETFL, O_NONBLOCK)`
- `poll()` or `select()` for event-driven I/O
- Direct control over `send()` and `recv()` buffer sizes
- TCP_NODELAY for latency optimization

### TLS Level
- SSL_CTX configuration (cipher suites, min/max versions)
- Certificate verification callbacks
- Session resumption control
- SNI (Server Name Indication) handling
- ALPN (Application-Layer Protocol Negotiation)

### HTTP Level
- Raw header construction (full visibility)
- Custom header injection
- Connection: keep-alive pooling
- Chunked transfer encoding parsing
- Request/response timing at each stage

### Streaming Level
- Byte-by-byte token streaming
- SSE event parsing
- Backpressure handling
- Partial token buffering

### Parallelism Level
- Thread-per-actor model with pthreads
- Shared connection pool option
- Individual connection per actor option
- Synchronization primitives

## Implementation Steps

1. **Phase 1: TLS Socket Foundation**
   - Implement `tls_socket.h` with OpenSSL
   - Test raw connection to api.anthropic.com:443
   - Verify certificate chain

2. **Phase 2: HTTP Client**
   - Implement HTTP/1.1 request/response
   - Test simple GET request
   - Add POST with JSON body

3. **Phase 3: JSON Handling**
   - Implement JSON builder for requests
   - Implement JSON parser for responses
   - Handle escaped strings properly

4. **Phase 4: SSE Streaming**
   - Parse Server-Sent Events format
   - Extract delta tokens from stream
   - Handle stream completion

5. **Phase 5: Claude API**
   - Build Messages API wrapper
   - Test non-streaming request
   - Test streaming request

6. **Phase 6: Actors System**
   - Implement actor threading
   - Implement judge workflow
   - Save outputs to markdown files

7. **Phase 7: CLI Interface**
   - Parse command line arguments
   - Support file input and interactive mode
   - Add verbose output option

## Verification

1. **Build test:**
   ```bash
   make clean && make
   ```

2. **Connection test:**
   ```bash
   ./build/claude-actors --test-connection
   ```

3. **Single request test:**
   ```bash
   ./build/claude-actors --test-single "Hello"
   ```

4. **Full actors test:**
   ```bash
   export ANTHROPIC_API_KEY="sk-..."
   ./build/claude-actors "Explain recursion in three different ways"
   ```

5. **Verify outputs:**
   ```bash
   ls -la claude_actors/
   cat claude_actors/actor_1.md
   cat claude_actors/claude_judge.md
   ```

## Files to Create

| File | Purpose |
|------|---------|
| `claude_actors/tls_socket.h` | Raw TCP + OpenSSL TLS |
| `claude_actors/http_client.h` | HTTP/1.1 protocol |
| `claude_actors/json_builder.h` | JSON serialization |
| `claude_actors/json_parser.h` | JSON parsing |
| `claude_actors/sse_parser.h` | SSE stream parsing |
| `claude_actors/claude_api.h` | Claude Messages API |
| `claude_actors/claude_actors.h` | Actor/judge orchestration |
| `claude_actors/claude_actors_main.c` | Entry point |
| `Makefile` | Build configuration (update) |
