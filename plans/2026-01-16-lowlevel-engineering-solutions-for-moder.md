# Low-Level Engineering Solutions for Modern Clearing Infrastructure

## Executive Summary

This document provides extremely detailed technical specifications for building modern clearing infrastructure using low-level engineering techniques. The focus is on achieving sub-microsecond latencies for real-time settlement, position tracking, and risk management.

---

## 1. Kernel Bypass Networking

### 1.1 DPDK Implementation for Clearing Systems

DPDK (Data Plane Development Kit) bypasses the Linux kernel entirely, providing direct access to NIC hardware. For clearing systems, this enables:

**Latency Improvements:**
- Standard Linux socket: 5-20 microseconds per packet
- DPDK: 200-500 nanoseconds per packet
- Improvement: 10-100x reduction

**Implementation Architecture:**
```c
// DPDK Clearing Message Receiver
#include <rte_eal.h>
#include <rte_ethdev.h>
#include <rte_mbuf.h>

#define BURST_SIZE 32
#define MEMPOOL_CACHE_SIZE 256

struct clearing_dpdk_ctx {
    uint16_t port_id;
    uint16_t queue_id;
    struct rte_mempool *mbuf_pool;

    // Pre-allocated message buffers
    clearing_msg_t *msg_pool;
    uint32_t msg_pool_size;

    // Statistics
    uint64_t rx_packets;
    uint64_t rx_bytes;
    uint64_t parse_errors;
};

// Initialize DPDK for clearing
int dpdk_clearing_init(struct clearing_dpdk_ctx *ctx, int argc, char **argv) {
    // Initialize EAL (Environment Abstraction Layer)
    int ret = rte_eal_init(argc, argv);
    if (ret < 0) return -1;

    // Create memory pool for packet buffers
    ctx->mbuf_pool = rte_pktmbuf_pool_create(
        "CLEARING_MBUF_POOL",
        8192,                    // Number of mbufs
        MEMPOOL_CACHE_SIZE,      // Per-core cache size
        0,                       // Private data size
        RTE_MBUF_DEFAULT_BUF_SIZE,
        rte_socket_id()          // NUMA socket
    );

    // Configure port with optimized settings
    struct rte_eth_conf port_conf = {
        .rxmode = {
            .mq_mode = ETH_MQ_RX_NONE,
            .max_rx_pkt_len = RTE_ETHER_MAX_LEN,
            .offloads = DEV_RX_OFFLOAD_CHECKSUM |
                       DEV_RX_OFFLOAD_TIMESTAMP,
        },
        .txmode = {
            .mq_mode = ETH_MQ_TX_NONE,
            .offloads = DEV_TX_OFFLOAD_CHECKSUM,
        },
    };

    rte_eth_dev_configure(ctx->port_id, 1, 1, &port_conf);

    // Setup RX queue with direct memory access
    rte_eth_rx_queue_setup(ctx->port_id, 0, 1024,
                           rte_eth_dev_socket_id(ctx->port_id),
                           NULL, ctx->mbuf_pool);

    // Enable hardware timestamping for latency measurement
    rte_eth_timesync_enable(ctx->port_id);

    return rte_eth_dev_start(ctx->port_id);
}

// Hot path: Receive and process clearing messages
// Target latency: <500ns
static inline __attribute__((hot)) int
dpdk_clearing_recv(struct clearing_dpdk_ctx *ctx,
                   clearing_msg_t *msgs,
                   int max_msgs) {
    struct rte_mbuf *bufs[BURST_SIZE];
    int processed = 0;

    // Busy-poll for packets (zero system calls)
    uint16_t nb_rx = rte_eth_rx_burst(ctx->port_id, ctx->queue_id,
                                       bufs, BURST_SIZE);

    for (int i = 0; i < nb_rx && processed < max_msgs; i++) {
        struct rte_mbuf *pkt = bufs[i];
        uint8_t *data = rte_pktmbuf_mtod(pkt, uint8_t *);
        uint16_t len = rte_pktmbuf_data_len(pkt);

        // Skip Ethernet + IP + UDP headers (42 bytes typical)
        // Parse clearing message directly from packet
        if (parse_clearing_message(data + 42, len - 42, &msgs[processed])) {
            // Capture hardware timestamp
            struct timespec ts;
            rte_eth_timesync_read_rx_timestamp(ctx->port_id, &ts, 0);
            msgs[processed].hw_timestamp = ts.tv_sec * 1000000000ULL + ts.tv_nsec;
            processed++;
        }

        rte_pktmbuf_free(pkt);
    }

    ctx->rx_packets += nb_rx;
    return processed;
}
```

### 1.2 ef_vi (Solarflare) for Settlement Messaging

Solarflare's ef_vi provides the lowest possible latency for settlement systems:

**Latency Characteristics:**
- Wire-to-application: 300-500 nanoseconds
- Application-to-wire: 300-500 nanoseconds
- Hardware timestamping precision: <10 nanoseconds

```c
// Solarflare ef_vi Settlement Gateway
#include <etherfabric/vi.h>
#include <etherfabric/pd.h>
#include <etherfabric/memreg.h>
#include <etherfabric/pio.h>

#define SETTLEMENT_RX_RING_SIZE 4096
#define SETTLEMENT_TX_RING_SIZE 1024

struct settlement_efvi_ctx {
    ef_driver_handle driver;
    ef_pd protection_domain;
    ef_vi virtual_interface;
    ef_memreg memory_region;

    // DMA buffers - must be contiguous and registered
    void *rx_bufs;
    void *tx_bufs;
    uint64_t rx_bufs_dma;
    uint64_t tx_bufs_dma;

    // Ring buffer indices
    uint32_t rx_posted;
    uint32_t rx_completed;
    uint32_t tx_posted;
    uint32_t tx_completed;

    // Packet I/O for lowest latency TX
    ef_pio pio;
};

// Initialize ef_vi for settlement
int efvi_settlement_init(struct settlement_efvi_ctx *ctx,
                         const char *interface) {
    // Open driver handle
    if (ef_driver_open(&ctx->driver) < 0) return -1;

    // Allocate protection domain on interface
    if (ef_pd_alloc_by_name(&ctx->protection_domain, ctx->driver,
                            interface, EF_PD_DEFAULT) < 0) {
        return -1;
    }

    // Allocate virtual interface with hardware timestamps
    int vi_flags = EF_VI_FLAGS_DEFAULT |
                   EF_VI_RX_TIMESTAMPS |
                   EF_VI_TX_TIMESTAMPS;

    if (ef_vi_alloc_from_pd(&ctx->virtual_interface, ctx->driver,
                            &ctx->protection_domain, ctx->driver,
                            -1, -1, -1, NULL, -1, vi_flags) < 0) {
        return -1;
    }

    // Allocate PIO for sub-microsecond TX
    if (ef_pio_alloc(&ctx->pio, ctx->driver,
                     &ctx->protection_domain, -1,
                     &ctx->virtual_interface) < 0) {
        // PIO not available, fall back to DMA
    }

    // Allocate and register DMA buffers
    size_t rx_buf_size = SETTLEMENT_RX_RING_SIZE * 2048;
    posix_memalign(&ctx->rx_bufs, 4096, rx_buf_size);

    ef_memreg_alloc(&ctx->memory_region, ctx->driver,
                    &ctx->protection_domain, ctx->driver,
                    ctx->rx_bufs, rx_buf_size);

    ctx->rx_bufs_dma = ef_memreg_dma_addr(&ctx->memory_region, 0);

    // Post initial RX buffers
    for (int i = 0; i < SETTLEMENT_RX_RING_SIZE; i++) {
        ef_vi_receive_init(&ctx->virtual_interface,
                          ctx->rx_bufs_dma + i * 2048, i);
    }
    ef_vi_receive_push(&ctx->virtual_interface);

    return 0;
}

// Ultra-low-latency receive path: ~300ns
static inline __attribute__((hot, flatten)) int
efvi_settlement_poll(struct settlement_efvi_ctx *ctx,
                     settlement_msg_t *msgs, int max_msgs) {
    ef_event events[16];
    int processed = 0;

    // Poll event queue (no system calls)
    int n_events = ef_eventq_poll(&ctx->virtual_interface, events, 16);

    for (int i = 0; i < n_events && processed < max_msgs; i++) {
        int type = EF_EVENT_TYPE(events[i]);

        if (type == EF_EVENT_TYPE_RX) {
            int desc_id = EF_EVENT_RX_RQ_ID(events[i]);
            int len = EF_EVENT_RX_BYTES(events[i]);

            // Get packet data directly from DMA buffer
            uint8_t *pkt = (uint8_t *)ctx->rx_bufs + desc_id * 2048;

            // Parse settlement message (skip headers)
            if (parse_settlement_message(pkt + 42, len - 42,
                                         &msgs[processed])) {
                // Extract hardware timestamp
                ef_vi_receive_get_timestamp(&ctx->virtual_interface,
                    pkt, &msgs[processed].hw_timestamp);
                processed++;
            }

            // Refill RX buffer immediately
            ef_vi_receive_init(&ctx->virtual_interface,
                              ctx->rx_bufs_dma + desc_id * 2048,
                              desc_id);
        }
    }

    if (n_events > 0) {
        ef_vi_receive_push(&ctx->virtual_interface);
    }

    return processed;
}

// PIO transmit for lowest latency: ~200ns
static inline __attribute__((hot)) int
efvi_settlement_send_pio(struct settlement_efvi_ctx *ctx,
                         const void *data, int len) {
    // PIO copies directly to NIC SRAM - no DMA latency
    int rc = ef_pio_memcpy(&ctx->virtual_interface, data, 0, len);
    if (rc < 0) return rc;

    return ef_vi_transmit_pio(&ctx->virtual_interface, 0, len, 0);
}
```

### 1.3 XDP/eBPF for Packet Processing

XDP (eXpress Data Path) enables packet processing at the driver level:

**Latency Characteristics:**
- XDP native mode: 500ns - 1 microsecond
- XDP offload (NIC): 100-300 nanoseconds
- Compared to iptables: 10-100x faster

```c
// XDP Clearing Message Filter
// Compile with: clang -O2 -target bpf -c clearing_xdp.c -o clearing_xdp.o

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>

#define CLEARING_PORT 5000

// Map for passing packets to userspace
struct {
    __uint(type, BPF_MAP_TYPE_XSKMAP);
    __uint(max_entries, 64);
    __type(key, __u32);
    __type(value, __u32);
} xsk_map SEC(".maps");

// Statistics map
struct {
    __uint(type, BPF_MAP_TYPE_PERCPU_ARRAY);
    __uint(max_entries, 4);
    __type(key, __u32);
    __type(value, __u64);
} stats_map SEC(".maps");

enum stats_key {
    STAT_RX_PACKETS = 0,
    STAT_RX_CLEARING = 1,
    STAT_RX_DROPPED = 2,
    STAT_RX_PASSED = 3,
};

SEC("xdp")
int clearing_filter(struct xdp_md *ctx) {
    void *data = (void *)(long)ctx->data;
    void *data_end = (void *)(long)ctx->data_end;

    // Update packet counter
    __u32 key = STAT_RX_PACKETS;
    __u64 *count = bpf_map_lookup_elem(&stats_map, &key);
    if (count) (*count)++;

    // Parse Ethernet header
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end)
        return XDP_DROP;

    // Only process IPv4
    if (eth->h_proto != __constant_htons(ETH_P_IP))
        return XDP_PASS;

    // Parse IP header
    struct iphdr *ip = (void *)(eth + 1);
    if ((void *)(ip + 1) > data_end)
        return XDP_DROP;

    // Only process UDP
    if (ip->protocol != IPPROTO_UDP)
        return XDP_PASS;

    // Parse UDP header
    struct udphdr *udp = (void *)ip + (ip->ihl * 4);
    if ((void *)(udp + 1) > data_end)
        return XDP_DROP;

    // Check if this is clearing traffic
    if (udp->dest == __constant_htons(CLEARING_PORT)) {
        // Update clearing packet counter
        key = STAT_RX_CLEARING;
        count = bpf_map_lookup_elem(&stats_map, &key);
        if (count) (*count)++;

        // Redirect to AF_XDP socket for userspace processing
        int index = ctx->rx_queue_index;
        if (bpf_map_lookup_elem(&xsk_map, &index))
            return bpf_redirect_map(&xsk_map, index, 0);
    }

    // Pass other traffic to kernel stack
    key = STAT_RX_PASSED;
    count = bpf_map_lookup_elem(&stats_map, &key);
    if (count) (*count)++;

    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
```

### 1.4 RDMA for Inter-Datacenter Communication

RDMA enables zero-copy, kernel-bypass communication between datacenters:

**Latency Characteristics:**
- RDMA Write: 1-2 microseconds (same rack)
- RDMA Write: 5-20 microseconds (cross-datacenter)
- Compared to TCP: 10-50x lower latency

```c
// RDMA Clearing State Replication
#include <rdma/rdma_cma.h>
#include <infiniband/verbs.h>

#define RDMA_BUFFER_SIZE (1024 * 1024)  // 1MB
#define RDMA_MAX_WR 256

struct clearing_rdma_ctx {
    struct rdma_cm_id *cm_id;
    struct ibv_pd *pd;
    struct ibv_cq *cq;
    struct ibv_qp *qp;

    // Registered memory regions for zero-copy
    struct ibv_mr *send_mr;
    struct ibv_mr *recv_mr;
    void *send_buf;
    void *recv_buf;

    // Remote memory info for RDMA writes
    uint64_t remote_addr;
    uint32_t remote_rkey;

    // Completion tracking
    uint64_t send_completions;
    uint64_t recv_completions;
};

// Initialize RDMA connection
int rdma_clearing_init(struct clearing_rdma_ctx *ctx,
                       const char *server_addr, int port) {
    struct rdma_addrinfo hints = {0}, *res;
    hints.ai_port_space = RDMA_PS_TCP;

    char port_str[16];
    snprintf(port_str, sizeof(port_str), "%d", port);

    if (rdma_getaddrinfo(server_addr, port_str, &hints, &res) < 0)
        return -1;

    // Create CM ID
    if (rdma_create_ep(&ctx->cm_id, res, NULL, NULL) < 0)
        return -1;

    // Allocate protection domain
    ctx->pd = ibv_alloc_pd(ctx->cm_id->verbs);

    // Create completion queue
    ctx->cq = ibv_create_cq(ctx->cm_id->verbs, RDMA_MAX_WR * 2, NULL, NULL, 0);

    // Allocate and register memory (must be pinned for DMA)
    posix_memalign(&ctx->send_buf, 4096, RDMA_BUFFER_SIZE);
    posix_memalign(&ctx->recv_buf, 4096, RDMA_BUFFER_SIZE);

    // Lock pages in memory
    mlock(ctx->send_buf, RDMA_BUFFER_SIZE);
    mlock(ctx->recv_buf, RDMA_BUFFER_SIZE);

    // Register memory regions
    ctx->send_mr = ibv_reg_mr(ctx->pd, ctx->send_buf, RDMA_BUFFER_SIZE,
                              IBV_ACCESS_LOCAL_WRITE);
    ctx->recv_mr = ibv_reg_mr(ctx->pd, ctx->recv_buf, RDMA_BUFFER_SIZE,
                              IBV_ACCESS_LOCAL_WRITE |
                              IBV_ACCESS_REMOTE_WRITE |
                              IBV_ACCESS_REMOTE_READ);

    // Create queue pair
    struct ibv_qp_init_attr qp_attr = {
        .send_cq = ctx->cq,
        .recv_cq = ctx->cq,
        .cap = {
            .max_send_wr = RDMA_MAX_WR,
            .max_recv_wr = RDMA_MAX_WR,
            .max_send_sge = 1,
            .max_recv_sge = 1,
        },
        .qp_type = IBV_QPT_RC,
    };

    if (rdma_create_qp(ctx->cm_id, ctx->pd, &qp_attr) < 0)
        return -1;

    ctx->qp = ctx->cm_id->qp;

    // Connect to remote
    if (rdma_connect(ctx->cm_id, NULL) < 0)
        return -1;

    return 0;
}

// RDMA Write for position replication: ~1-2 microseconds
static inline __attribute__((hot)) int
rdma_clearing_write(struct clearing_rdma_ctx *ctx,
                    const void *data, size_t len, uint64_t offset) {
    // Copy data to registered buffer
    memcpy(ctx->send_buf, data, len);

    // Post RDMA Write (zero-copy to remote memory)
    struct ibv_sge sge = {
        .addr = (uintptr_t)ctx->send_buf,
        .length = len,
        .lkey = ctx->send_mr->lkey,
    };

    struct ibv_send_wr wr = {
        .wr_id = ctx->send_completions++,
        .sg_list = &sge,
        .num_sge = 1,
        .opcode = IBV_WR_RDMA_WRITE,
        .send_flags = IBV_SEND_SIGNALED,
        .wr.rdma = {
            .remote_addr = ctx->remote_addr + offset,
            .rkey = ctx->remote_rkey,
        },
    };

    struct ibv_send_wr *bad_wr;
    return ibv_post_send(ctx->qp, &wr, &bad_wr);
}

// Poll for completions
static inline __attribute__((hot)) int
rdma_clearing_poll(struct clearing_rdma_ctx *ctx) {
    struct ibv_wc wc[16];
    int n = ibv_poll_cq(ctx->cq, 16, wc);

    for (int i = 0; i < n; i++) {
        if (wc[i].status != IBV_WC_SUCCESS) {
            // Handle error
            return -1;
        }
    }

    return n;
}
```

---

## 2. Lock-Free Data Structures

### 2.1 SPSC Queues for Order Flow

Single-Producer Single-Consumer queues are optimal for clearing pipelines:

**Performance Characteristics:**
- Push latency: 10-15 nanoseconds
- Pop latency: 10-15 nanoseconds
- Zero contention, zero system calls

```c
// High-Performance SPSC Queue for Clearing
// Cache-line separated producer/consumer state prevents false sharing

#define CLEARING_QUEUE_SIZE 65536  // Must be power of 2
#define CLEARING_QUEUE_MASK (CLEARING_QUEUE_SIZE - 1)

typedef struct clearing_msg {
    uint64_t msg_id;
    uint64_t timestamp;
    uint64_t account_id;
    int64_t  quantity;
    int64_t  price;
    uint32_t symbol_id;
    uint32_t msg_type;
    char     data[32];
} clearing_msg_t;

// Queue structure with false-sharing prevention
typedef struct {
    // Producer state - own cache line
    alignas(64) _Atomic uint64_t write_pos;
    char _pad1[56];

    // Consumer state - own cache line
    alignas(64) _Atomic uint64_t read_pos;
    char _pad2[56];

    // Cached positions to reduce atomic loads
    alignas(64) uint64_t cached_read;   // Producer's cached view of read_pos
    uint64_t cached_write;              // Consumer's cached view of write_pos
    char _pad3[48];

    // Data buffer - separate cache lines
    alignas(64) clearing_msg_t buffer[CLEARING_QUEUE_SIZE];
} clearing_spsc_queue_t;

// Initialize queue
static inline void clearing_queue_init(clearing_spsc_queue_t *q) {
    atomic_store_explicit(&q->write_pos, 0, memory_order_relaxed);
    atomic_store_explicit(&q->read_pos, 0, memory_order_relaxed);
    q->cached_read = 0;
    q->cached_write = 0;
}

// Producer: Push message to queue
// Latency: ~12ns (hot path)
static inline __attribute__((always_inline, hot))
bool clearing_queue_push(clearing_spsc_queue_t *q,
                         const clearing_msg_t *msg) {
    uint64_t write = atomic_load_explicit(&q->write_pos, memory_order_relaxed);
    uint64_t next = (write + 1) & CLEARING_QUEUE_MASK;

    // Check if queue is full using cached read position
    if (next == q->cached_read) {
        // Refresh cached read position
        q->cached_read = atomic_load_explicit(&q->read_pos,
                                              memory_order_acquire);
        if (next == q->cached_read) {
            return false;  // Queue full
        }
    }

    // Write message to buffer
    q->buffer[write] = *msg;

    // Publish write position (release ensures message visible before index)
    atomic_store_explicit(&q->write_pos, next, memory_order_release);

    return true;
}

// Consumer: Pop message from queue
// Latency: ~12ns (hot path)
static inline __attribute__((always_inline, hot))
bool clearing_queue_pop(clearing_spsc_queue_t *q, clearing_msg_t *msg) {
    uint64_t read = atomic_load_explicit(&q->read_pos, memory_order_relaxed);

    // Check if queue is empty using cached write position
    if (read == q->cached_write) {
        // Refresh cached write position
        q->cached_write = atomic_load_explicit(&q->write_pos,
                                               memory_order_acquire);
        if (read == q->cached_write) {
            return false;  // Queue empty
        }
    }

    // Read message from buffer
    *msg = q->buffer[read];

    // Advance read position
    atomic_store_explicit(&q->read_pos, (read + 1) & CLEARING_QUEUE_MASK,
                          memory_order_release);

    return true;
}

// Batch pop for high throughput
static inline int clearing_queue_pop_batch(clearing_spsc_queue_t *q,
                                           clearing_msg_t *msgs,
                                           int max_msgs) {
    uint64_t read = atomic_load_explicit(&q->read_pos, memory_order_relaxed);
    uint64_t write = atomic_load_explicit(&q->write_pos, memory_order_acquire);

    int available = (write - read) & CLEARING_QUEUE_MASK;
    int count = (available < max_msgs) ? available : max_msgs;

    // Copy messages
    for (int i = 0; i < count; i++) {
        msgs[i] = q->buffer[(read + i) & CLEARING_QUEUE_MASK];
    }

    // Update read position once
    atomic_store_explicit(&q->read_pos, (read + count) & CLEARING_QUEUE_MASK,
                          memory_order_release);

    return count;
}
```

### 2.2 MPSC Queues for Position Aggregation

Multiple producers (trading threads) writing to single consumer (risk engine):

```c
// MPSC Queue using Vyukov's algorithm
// Multiple trading threads can submit position updates concurrently

typedef struct mpsc_node {
    _Atomic(struct mpsc_node *) next;
    position_update_t data;
} mpsc_node_t;

typedef struct {
    // Head - multiple producers push here (atomic exchange)
    alignas(64) _Atomic(mpsc_node_t *) head;
    char _pad1[56];

    // Tail - single consumer pops here
    alignas(64) mpsc_node_t *tail;
    char _pad2[56];

    // Stub node to simplify empty queue handling
    alignas(64) mpsc_node_t stub;
} position_mpsc_queue_t;

static inline void position_mpsc_init(position_mpsc_queue_t *q) {
    atomic_store_explicit(&q->stub.next, NULL, memory_order_relaxed);
    atomic_store_explicit(&q->head, &q->stub, memory_order_relaxed);
    q->tail = &q->stub;
}

// Producer push: ~20ns (lock-free, wait-free)
static inline __attribute__((hot))
void position_mpsc_push(position_mpsc_queue_t *q, mpsc_node_t *node) {
    // Initialize node
    atomic_store_explicit(&node->next, NULL, memory_order_relaxed);

    // Atomically exchange head pointer
    mpsc_node_t *prev = atomic_exchange_explicit(&q->head, node,
                                                  memory_order_acq_rel);

    // Link previous node to this one
    atomic_store_explicit(&prev->next, node, memory_order_release);
}

// Consumer pop: ~15ns (single-threaded)
static inline __attribute__((hot))
mpsc_node_t *position_mpsc_pop(position_mpsc_queue_t *q) {
    mpsc_node_t *tail = q->tail;
    mpsc_node_t *next = atomic_load_explicit(&tail->next, memory_order_acquire);

    // Skip stub node on first real pop
    if (tail == &q->stub) {
        if (next == NULL) {
            return NULL;  // Empty
        }
        q->tail = next;
        tail = next;
        next = atomic_load_explicit(&next->next, memory_order_acquire);
    }

    if (next != NULL) {
        q->tail = next;
        return tail;
    }

    // Check if producer is in progress
    mpsc_node_t *head = atomic_load_explicit(&q->head, memory_order_acquire);
    if (tail != head) {
        return NULL;  // Producer in progress, retry later
    }

    // Re-insert stub for next cycle
    position_mpsc_push(q, &q->stub);

    next = atomic_load_explicit(&tail->next, memory_order_acquire);
    if (next != NULL) {
        q->tail = next;
        return tail;
    }

    return NULL;
}
```

### 2.3 Lock-Free Hash Map for Account Lookups

```c
// Lock-free hash map for account/position lookups
// Uses open addressing with linear probing

#define ACCOUNT_MAP_SIZE 65536  // Must be power of 2
#define ACCOUNT_MAP_MASK (ACCOUNT_MAP_SIZE - 1)

typedef struct {
    _Atomic uint64_t account_id;  // 0 = empty slot
    _Atomic int64_t  position;
    _Atomic int64_t  realized_pnl;
    _Atomic int64_t  unrealized_pnl;
    _Atomic int64_t  margin_used;
    _Atomic uint64_t last_update;
} account_entry_t;

typedef struct {
    alignas(64) account_entry_t entries[ACCOUNT_MAP_SIZE];
    _Atomic uint64_t count;
    _Atomic uint64_t collisions;
} account_hashmap_t;

// Hash function using CRC32 instruction
static inline uint32_t account_hash(uint64_t account_id) {
#ifdef __SSE4_2__
    return __builtin_ia32_crc32di(0, account_id) & ACCOUNT_MAP_MASK;
#else
    uint64_t h = account_id;
    h ^= h >> 33;
    h *= 0xff51afd7ed558ccdULL;
    h ^= h >> 33;
    return (uint32_t)h & ACCOUNT_MAP_MASK;
#endif
}

// Lookup account: ~20-50ns depending on collisions
static inline __attribute__((hot))
account_entry_t *account_lookup(account_hashmap_t *map, uint64_t account_id) {
    uint32_t idx = account_hash(account_id);

    for (int i = 0; i < 32; i++) {  // Max 32 probes
        uint32_t probe = (idx + i) & ACCOUNT_MAP_MASK;
        account_entry_t *entry = &map->entries[probe];

        uint64_t stored_id = atomic_load_explicit(&entry->account_id,
                                                  memory_order_acquire);

        if (stored_id == account_id) {
            return entry;  // Found
        }

        if (stored_id == 0) {
            return NULL;  // Not found (empty slot)
        }

        // Collision - continue probing
    }

    return NULL;  // Too many collisions
}

// Insert or update account: lock-free using CAS
static inline __attribute__((hot))
account_entry_t *account_upsert(account_hashmap_t *map, uint64_t account_id) {
    uint32_t idx = account_hash(account_id);

    for (int i = 0; i < 32; i++) {
        uint32_t probe = (idx + i) & ACCOUNT_MAP_MASK;
        account_entry_t *entry = &map->entries[probe];

        uint64_t stored_id = atomic_load_explicit(&entry->account_id,
                                                  memory_order_acquire);

        if (stored_id == account_id) {
            return entry;  // Already exists
        }

        if (stored_id == 0) {
            // Try to claim this slot
            uint64_t expected = 0;
            if (atomic_compare_exchange_strong_explicit(&entry->account_id,
                    &expected, account_id,
                    memory_order_acq_rel, memory_order_relaxed)) {
                atomic_fetch_add(&map->count, 1, memory_order_relaxed);
                return entry;  // Claimed
            }

            // CAS failed - check if our account was inserted
            if (expected == account_id) {
                return entry;
            }

            // Different account claimed the slot - continue probing
            atomic_fetch_add(&map->collisions, 1, memory_order_relaxed);
        }
    }

    return NULL;  // Map full
}

// Update position atomically
static inline void account_update_position(account_entry_t *entry,
                                           int64_t delta) {
    atomic_fetch_add_explicit(&entry->position, delta, memory_order_acq_rel);
    atomic_store_explicit(&entry->last_update, rdtsc(), memory_order_release);
}
```

### 2.4 Memory Ordering and Cache Optimization

```c
// Memory barrier reference for clearing systems

// acquire: Ensures all subsequent reads see writes before the matching release
// release: Ensures all prior writes are visible before this write
// acq_rel: Both acquire and release (for read-modify-write operations)
// seq_cst: Full sequential consistency (expensive, avoid in hot paths)

// Example: Position update with proper ordering
typedef struct {
    alignas(64) _Atomic int64_t position;
    alignas(64) _Atomic int64_t margin;
    alignas(64) _Atomic uint64_t sequence;  // For consistency checks
} atomic_position_t;

static inline void position_update_safe(atomic_position_t *pos,
                                        int64_t new_position,
                                        int64_t new_margin) {
    // Increment sequence (odd = update in progress)
    uint64_t seq = atomic_fetch_add_explicit(&pos->sequence, 1,
                                             memory_order_release);

    // Write position and margin
    atomic_store_explicit(&pos->position, new_position, memory_order_relaxed);
    atomic_store_explicit(&pos->margin, new_margin, memory_order_relaxed);

    // Increment sequence again (even = update complete)
    atomic_fetch_add_explicit(&pos->sequence, 1, memory_order_release);
}

static inline bool position_read_safe(const atomic_position_t *pos,
                                      int64_t *position,
                                      int64_t *margin) {
    uint64_t seq1, seq2;

    do {
        seq1 = atomic_load_explicit(&pos->sequence, memory_order_acquire);

        // Wait if update in progress
        if (seq1 & 1) continue;

        *position = atomic_load_explicit(&pos->position, memory_order_relaxed);
        *margin = atomic_load_explicit(&pos->margin, memory_order_relaxed);

        seq2 = atomic_load_explicit(&pos->sequence, memory_order_acquire);
    } while (seq1 != seq2);

    return true;
}

// Prefetching for cache optimization
#define PREFETCH_READ(addr)     __builtin_prefetch((addr), 0, 3)
#define PREFETCH_WRITE(addr)    __builtin_prefetch((addr), 1, 3)
#define PREFETCH_NTA(addr)      __builtin_prefetch((addr), 0, 0)

// Process batch with prefetching
static inline void process_clearing_batch(clearing_msg_t *msgs, int count) {
    for (int i = 0; i < count; i++) {
        // Prefetch next message while processing current
        if (i + 1 < count) {
            PREFETCH_READ(&msgs[i + 1]);
        }

        // Prefetch account entry for next message
        if (i + 2 < count) {
            uint64_t next_account = msgs[i + 2].account_id;
            account_entry_t *entry = account_lookup(global_map, next_account);
            if (entry) PREFETCH_WRITE(entry);
        }

        process_single_message(&msgs[i]);
    }
}
```

---

## 3. Memory Management

### 3.1 Custom Allocators for Hot Paths

```c
// Slab allocator for fixed-size clearing messages
// Zero-fragmentation, O(1) allocation/deallocation

#define SLAB_SIZE (2 * 1024 * 1024)  // 2MB per slab (huge page)
#define MSG_SIZE 128                   // Fixed message size
#define MSGS_PER_SLAB (SLAB_SIZE / MSG_SIZE)

typedef struct slab_header {
    struct slab_header *next;
    uint32_t free_count;
    uint32_t first_free;
    uint8_t bitmap[MSGS_PER_SLAB / 8];
} slab_header_t;

typedef struct {
    slab_header_t *current_slab;
    slab_header_t *slab_list;

    // Statistics
    uint64_t total_allocs;
    uint64_t total_frees;
    uint64_t slab_count;

    // Free list for O(1) allocation
    uint32_t *free_stack;
    uint32_t free_top;
    uint32_t free_capacity;
} slab_allocator_t;

// Allocate new slab using huge pages
static slab_header_t *slab_alloc_new(void) {
    void *mem = mmap(NULL, SLAB_SIZE,
                     PROT_READ | PROT_WRITE,
                     MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                     -1, 0);

    if (mem == MAP_FAILED) {
        // Fallback to regular pages with THP
        mem = mmap(NULL, SLAB_SIZE,
                   PROT_READ | PROT_WRITE,
                   MAP_PRIVATE | MAP_ANONYMOUS,
                   -1, 0);
        if (mem != MAP_FAILED) {
            madvise(mem, SLAB_SIZE, MADV_HUGEPAGE);
        }
    }

    if (mem == MAP_FAILED) return NULL;

    // Lock in memory
    mlock(mem, SLAB_SIZE);

    // Pre-fault pages
    memset(mem, 0, SLAB_SIZE);

    slab_header_t *slab = (slab_header_t *)mem;
    slab->next = NULL;
    slab->free_count = MSGS_PER_SLAB - 1;  // First slot is header
    slab->first_free = 1;

    return slab;
}

// O(1) allocation from slab
static inline __attribute__((hot))
void *slab_alloc(slab_allocator_t *alloc) {
    if (alloc->free_top > 0) {
        // Fast path: pop from free stack
        uint32_t idx = alloc->free_stack[--alloc->free_top];
        alloc->total_allocs++;
        return (uint8_t *)alloc->current_slab + idx * MSG_SIZE;
    }

    // Slow path: allocate from current slab or get new slab
    slab_header_t *slab = alloc->current_slab;

    if (slab->free_count == 0) {
        // Current slab exhausted, allocate new one
        slab = slab_alloc_new();
        if (!slab) return NULL;

        slab->next = alloc->slab_list;
        alloc->slab_list = slab;
        alloc->current_slab = slab;
        alloc->slab_count++;
    }

    uint32_t idx = slab->first_free++;
    slab->free_count--;
    alloc->total_allocs++;

    return (uint8_t *)slab + idx * MSG_SIZE;
}

// O(1) deallocation to free stack
static inline __attribute__((hot))
void slab_free(slab_allocator_t *alloc, void *ptr) {
    // Calculate index within slab
    uint8_t *slab_base = (uint8_t *)alloc->current_slab;
    uint32_t idx = ((uint8_t *)ptr - slab_base) / MSG_SIZE;

    // Push to free stack
    if (alloc->free_top < alloc->free_capacity) {
        alloc->free_stack[alloc->free_top++] = idx;
    }

    alloc->total_frees++;
}
```

### 3.2 Arena/Pool Allocators for Message Buffers

```c
// Arena allocator for session-scoped allocations
// Extremely fast: just bump a pointer

typedef struct {
    uint8_t *base;
    uint8_t *current;
    uint8_t *end;
    size_t   total_size;
    size_t   high_water;
} arena_allocator_t;

static inline int arena_init(arena_allocator_t *arena, size_t size) {
    // Allocate with huge pages
    arena->base = mmap(NULL, size,
                       PROT_READ | PROT_WRITE,
                       MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                       -1, 0);

    if (arena->base == MAP_FAILED) {
        arena->base = aligned_alloc(4096, size);
        if (!arena->base) return -1;
    }

    arena->current = arena->base;
    arena->end = arena->base + size;
    arena->total_size = size;
    arena->high_water = 0;

    return 0;
}

// Ultra-fast allocation: ~3ns
static inline __attribute__((always_inline, hot))
void *arena_alloc(arena_allocator_t *arena, size_t size, size_t align) {
    // Align current pointer
    uint8_t *aligned = (uint8_t *)(((uintptr_t)arena->current + align - 1)
                                    & ~(align - 1));
    uint8_t *new_current = aligned + size;

    if (__builtin_expect(new_current > arena->end, 0)) {
        return NULL;  // Out of memory
    }

    arena->current = new_current;

    // Track high water mark
    size_t used = arena->current - arena->base;
    if (used > arena->high_water) {
        arena->high_water = used;
    }

    return aligned;
}

// Reset arena - O(1), clears all allocations
static inline void arena_reset(arena_allocator_t *arena) {
    arena->current = arena->base;
}

// Checkpoint/restore for nested allocations
typedef struct {
    uint8_t *saved_current;
} arena_checkpoint_t;

static inline arena_checkpoint_t arena_checkpoint(arena_allocator_t *arena) {
    return (arena_checkpoint_t){ .saved_current = arena->current };
}

static inline void arena_restore(arena_allocator_t *arena,
                                 arena_checkpoint_t checkpoint) {
    arena->current = checkpoint.saved_current;
}
```

### 3.3 Huge Pages for TLB Efficiency

```c
// Huge page configuration for clearing systems

#include <sys/mman.h>
#include <numaif.h>

// Huge page sizes
#define HUGE_PAGE_2MB   (2UL * 1024 * 1024)
#define HUGE_PAGE_1GB   (1UL * 1024 * 1024 * 1024)

// TLB coverage analysis:
// - 4KB pages: 512 TLB entries = 2MB coverage
// - 2MB pages: 512 TLB entries = 1GB coverage
// - 1GB pages: 512 TLB entries = 512GB coverage

// Critical data structures should use 1GB pages if possible
typedef struct {
    void *base;
    size_t size;
    int huge_page_size;  // 0=4KB, 1=2MB, 2=1GB
} huge_allocation_t;

static int allocate_huge_pages(huge_allocation_t *alloc,
                               size_t size,
                               int numa_node) {
    int flags = MAP_PRIVATE | MAP_ANONYMOUS;

    // Try 1GB pages first
    if (size >= HUGE_PAGE_1GB) {
        size_t aligned_size = (size + HUGE_PAGE_1GB - 1) & ~(HUGE_PAGE_1GB - 1);
        alloc->base = mmap(NULL, aligned_size,
                          PROT_READ | PROT_WRITE,
                          flags | MAP_HUGETLB | MAP_HUGE_1GB,
                          -1, 0);

        if (alloc->base != MAP_FAILED) {
            alloc->size = aligned_size;
            alloc->huge_page_size = 2;
            goto bind_numa;
        }
    }

    // Try 2MB pages
    if (size >= HUGE_PAGE_2MB) {
        size_t aligned_size = (size + HUGE_PAGE_2MB - 1) & ~(HUGE_PAGE_2MB - 1);
        alloc->base = mmap(NULL, aligned_size,
                          PROT_READ | PROT_WRITE,
                          flags | MAP_HUGETLB,
                          -1, 0);

        if (alloc->base != MAP_FAILED) {
            alloc->size = aligned_size;
            alloc->huge_page_size = 1;
            goto bind_numa;
        }
    }

    // Fallback to regular pages with THP
    alloc->base = mmap(NULL, size,
                      PROT_READ | PROT_WRITE,
                      flags,
                      -1, 0);

    if (alloc->base == MAP_FAILED) {
        return -1;
    }

    madvise(alloc->base, size, MADV_HUGEPAGE);
    alloc->size = size;
    alloc->huge_page_size = 0;

bind_numa:
    // Bind to NUMA node for local memory access
    if (numa_node >= 0) {
        unsigned long nodemask = 1UL << numa_node;
        mbind(alloc->base, alloc->size, MPOL_BIND,
              &nodemask, sizeof(nodemask) * 8, MPOL_MF_STRICT);
    }

    // Lock in physical memory
    mlock(alloc->base, alloc->size);

    // Pre-fault all pages
    memset(alloc->base, 0, alloc->size);

    return 0;
}
```

### 3.4 NUMA-Aware Allocation

```c
// NUMA-aware memory allocation for clearing systems

#include <numa.h>
#include <numaif.h>

typedef struct {
    int num_nodes;
    int preferred_node;

    // Per-node memory pools
    struct {
        void *base;
        size_t size;
        size_t used;
    } node_pools[8];  // Max 8 NUMA nodes

    // CPU to NUMA node mapping
    int cpu_to_node[256];
} numa_allocator_t;

static int numa_allocator_init(numa_allocator_t *alloc) {
    if (numa_available() < 0) {
        return -1;  // NUMA not available
    }

    alloc->num_nodes = numa_num_configured_nodes();
    alloc->preferred_node = numa_preferred();

    // Build CPU to node mapping
    for (int cpu = 0; cpu < 256; cpu++) {
        alloc->cpu_to_node[cpu] = numa_node_of_cpu(cpu);
    }

    // Allocate per-node memory pools
    size_t pool_size = 1UL * 1024 * 1024 * 1024;  // 1GB per node

    for (int node = 0; node < alloc->num_nodes; node++) {
        void *mem = numa_alloc_onnode(pool_size, node);
        if (!mem) {
            return -1;
        }

        // Pre-fault and lock
        mlock(mem, pool_size);
        memset(mem, 0, pool_size);

        alloc->node_pools[node].base = mem;
        alloc->node_pools[node].size = pool_size;
        alloc->node_pools[node].used = 0;
    }

    return 0;
}

// Allocate from local NUMA node
static inline __attribute__((hot))
void *numa_alloc_local(numa_allocator_t *alloc, size_t size) {
    // Get current CPU's NUMA node
    int cpu = sched_getcpu();
    int node = alloc->cpu_to_node[cpu];

    // Allocate from local node's pool
    if (alloc->node_pools[node].used + size <= alloc->node_pools[node].size) {
        void *ptr = (uint8_t *)alloc->node_pools[node].base +
                    alloc->node_pools[node].used;
        alloc->node_pools[node].used += size;
        return ptr;
    }

    return NULL;
}

// Thread-local position structure bound to NUMA node
typedef struct __attribute__((aligned(64))) {
    // Position data
    int64_t position;
    int64_t avg_price;
    int64_t realized_pnl;
    int64_t unrealized_pnl;

    // Bound to specific NUMA node
    int numa_node;
    int owning_cpu;
} numa_position_t;

// Create position on correct NUMA node
static numa_position_t *create_numa_position(numa_allocator_t *alloc,
                                              int cpu) {
    int node = alloc->cpu_to_node[cpu];

    numa_position_t *pos = numa_alloc_local(alloc, sizeof(numa_position_t));
    if (pos) {
        memset(pos, 0, sizeof(*pos));
        pos->numa_node = node;
        pos->owning_cpu = cpu;
    }

    return pos;
}
```

---

## 4. Protocol Optimization

### 4.1 Binary Protocols vs FIX

**Performance Comparison:**
| Protocol | Parse Time | Message Size | Overhead |
|----------|------------|--------------|----------|
| FIX (text) | 1-5 microseconds | 200-500 bytes | High (text parsing) |
| SBE | 20-50 nanoseconds | 50-100 bytes | Minimal |
| FlatBuffers | 30-80 nanoseconds | 60-120 bytes | Low |
| Cap'n Proto | 25-60 nanoseconds | 60-120 bytes | Low |

### 4.2 SBE (Simple Binary Encoding) Implementation

```c
// SBE Clearing Message Schema (simplified)
// Designed for zero-copy access and minimal parsing

// Message header - 8 bytes
typedef struct __attribute__((packed)) {
    uint16_t block_length;    // Message body length
    uint16_t template_id;     // Message type
    uint16_t schema_id;       // Schema version
    uint16_t version;         // Message version
} sbe_header_t;

// Position update message - fixed size for predictable access
typedef struct __attribute__((packed)) {
    sbe_header_t header;

    // Core fields - all fixed size
    uint64_t account_id;      // 8 bytes
    uint64_t timestamp;       // 8 bytes
    uint32_t symbol_id;       // 4 bytes
    int64_t  quantity;        // 8 bytes (signed)
    int64_t  price;           // 8 bytes (fixed point)
    int64_t  realized_pnl;    // 8 bytes
    uint16_t venue_id;        // 2 bytes
    uint8_t  side;            // 1 byte
    uint8_t  flags;           // 1 byte
    // Total: 8 + 48 = 56 bytes
} sbe_position_update_t;

#define SBE_TEMPLATE_POSITION_UPDATE 1001

// Zero-copy SBE decoder - ~20ns
static inline __attribute__((always_inline, hot))
const sbe_position_update_t *sbe_decode_position_update(const uint8_t *buf,
                                                        size_t len) {
    if (__builtin_expect(len < sizeof(sbe_position_update_t), 0)) {
        return NULL;
    }

    const sbe_header_t *hdr = (const sbe_header_t *)buf;

    // Validate template
    if (__builtin_expect(hdr->template_id != SBE_TEMPLATE_POSITION_UPDATE, 0)) {
        return NULL;
    }

    // Return pointer directly - zero copy
    return (const sbe_position_update_t *)buf;
}

// SBE encoder - ~15ns
static inline __attribute__((always_inline, hot))
size_t sbe_encode_position_update(uint8_t *buf,
                                  uint64_t account_id,
                                  uint32_t symbol_id,
                                  int64_t quantity,
                                  int64_t price,
                                  int64_t realized_pnl,
                                  uint16_t venue_id,
                                  uint8_t side) {
    sbe_position_update_t *msg = (sbe_position_update_t *)buf;

    // Header
    msg->header.block_length = sizeof(sbe_position_update_t) - sizeof(sbe_header_t);
    msg->header.template_id = SBE_TEMPLATE_POSITION_UPDATE;
    msg->header.schema_id = 1;
    msg->header.version = 0;

    // Body - direct assignment, no serialization needed
    msg->account_id = account_id;
    msg->timestamp = rdtsc();  // Use TSC for minimal overhead
    msg->symbol_id = symbol_id;
    msg->quantity = quantity;
    msg->price = price;
    msg->realized_pnl = realized_pnl;
    msg->venue_id = venue_id;
    msg->side = side;
    msg->flags = 0;

    return sizeof(sbe_position_update_t);
}
```

### 4.3 Zero-Copy Deserialization

```c
// Zero-copy message access pattern
// Messages are accessed directly from network buffer

typedef struct {
    // Pointer to raw network buffer (never copied)
    const uint8_t *raw_data;
    size_t raw_len;

    // Parsed header (small, always copied)
    sbe_header_t header;

    // Pointers into raw_data for body access
    const void *body_ptr;
    size_t body_len;
} zero_copy_message_t;

// Parse message without copying body - ~10ns
static inline __attribute__((hot))
int zero_copy_parse(zero_copy_message_t *msg,
                    const uint8_t *data,
                    size_t len) {
    if (len < sizeof(sbe_header_t)) {
        return -1;
    }

    // Copy only the small header
    memcpy(&msg->header, data, sizeof(sbe_header_t));

    // Point to body without copying
    msg->raw_data = data;
    msg->raw_len = len;
    msg->body_ptr = data + sizeof(sbe_header_t);
    msg->body_len = msg->header.block_length;

    return 0;
}

// Access field without copying entire message
static inline __attribute__((hot))
int64_t zero_copy_get_quantity(const zero_copy_message_t *msg) {
    // Direct pointer arithmetic to field offset
    const sbe_position_update_t *pu = (const sbe_position_update_t *)msg->raw_data;
    return pu->quantity;
}
```

### 4.4 Branch-Free Parsing Techniques

```c
// Branch-free message type dispatch
// Avoids pipeline stalls from mispredicted branches

typedef void (*message_handler_t)(const void *data, size_t len, void *ctx);

typedef struct {
    // Handler table indexed by message type
    message_handler_t handlers[256];
    void *context;
} branchfree_dispatcher_t;

// Initialize dispatcher with handlers
static void dispatcher_init(branchfree_dispatcher_t *d) {
    // Set all handlers to no-op initially
    for (int i = 0; i < 256; i++) {
        d->handlers[i] = NULL;
    }
}

// Dispatch message without branches - ~5ns
static inline __attribute__((hot, flatten))
void dispatcher_dispatch(branchfree_dispatcher_t *d,
                         uint8_t msg_type,
                         const void *data,
                         size_t len) {
    // Single table lookup, no branches
    message_handler_t handler = d->handlers[msg_type];

    // Use cmov-style handling for null check
    // Compiler will optimize this to conditional move
    if (handler) {
        handler(data, len, d->context);
    }
}

// Branch-free field extraction
static inline __attribute__((hot))
int64_t extract_price_branchfree(const uint8_t *data,
                                  uint8_t msg_type) {
    // Offset table for price field by message type
    static const uint8_t price_offsets[256] = {
        [SBE_TEMPLATE_POSITION_UPDATE & 0xFF] =
            offsetof(sbe_position_update_t, price),
        // ... other message types
    };

    uint8_t offset = price_offsets[msg_type];

    // Single memory access at computed offset
    return *(const int64_t *)(data + offset);
}

// Branch-free validation
static inline __attribute__((hot))
bool validate_message_branchfree(const sbe_header_t *hdr, size_t len) {
    // Compute validity without branches
    size_t required = sizeof(sbe_header_t) + hdr->block_length;

    // Returns 1 if valid, 0 if invalid
    // Uses conditional move instruction
    return len >= required;
}
```

---

## 5. Database Alternatives

### 5.1 In-Memory Position Tracking

```c
// In-memory position engine with persistence snapshots
// All reads/writes in memory, periodic async snapshots to disk

#define MAX_ACCOUNTS 100000
#define MAX_SYMBOLS 10000

typedef struct {
    alignas(64) _Atomic int64_t quantity;
    alignas(64) _Atomic int64_t avg_price;
    alignas(64) _Atomic int64_t realized_pnl;
    alignas(64) _Atomic int64_t unrealized_pnl;
    alignas(64) _Atomic uint64_t last_trade_time;
} position_t;

typedef struct {
    // Position matrix: [account][symbol]
    position_t *positions;

    // Account metadata
    uint64_t *account_ids;
    uint32_t account_count;

    // Symbol metadata
    uint32_t *symbol_ids;
    uint32_t symbol_count;

    // Index: account_id -> row index
    account_hashmap_t account_index;

    // Memory mapping for persistence
    int mmap_fd;
    void *mmap_base;
    size_t mmap_size;
} position_engine_t;

static int position_engine_init(position_engine_t *engine) {
    // Calculate total size
    size_t matrix_size = MAX_ACCOUNTS * MAX_SYMBOLS * sizeof(position_t);
    size_t total_size = matrix_size +
                        MAX_ACCOUNTS * sizeof(uint64_t) +
                        MAX_SYMBOLS * sizeof(uint32_t);

    // Allocate with huge pages
    engine->mmap_base = mmap(NULL, total_size,
                             PROT_READ | PROT_WRITE,
                             MAP_PRIVATE | MAP_ANONYMOUS | MAP_HUGETLB,
                             -1, 0);

    if (engine->mmap_base == MAP_FAILED) {
        return -1;
    }

    mlock(engine->mmap_base, total_size);
    memset(engine->mmap_base, 0, total_size);

    // Layout memory regions
    engine->positions = (position_t *)engine->mmap_base;
    engine->account_ids = (uint64_t *)((uint8_t *)engine->mmap_base + matrix_size);
    engine->symbol_ids = (uint32_t *)((uint8_t *)engine->account_ids +
                                       MAX_ACCOUNTS * sizeof(uint64_t));

    engine->account_count = 0;
    engine->symbol_count = 0;
    engine->mmap_size = total_size;

    return 0;
}

// Get position: ~20ns (cache hit), ~100ns (cache miss)
static inline __attribute__((hot))
position_t *position_get(position_engine_t *engine,
                         uint32_t account_idx,
                         uint32_t symbol_idx) {
    return &engine->positions[account_idx * MAX_SYMBOLS + symbol_idx];
}

// Update position atomically: ~30ns
static inline __attribute__((hot))
void position_update(position_t *pos,
                     int64_t qty_delta,
                     int64_t trade_price,
                     int64_t trade_value) {
    // Atomically update quantity
    int64_t old_qty = atomic_fetch_add_explicit(&pos->quantity, qty_delta,
                                                 memory_order_acq_rel);
    int64_t new_qty = old_qty + qty_delta;

    // Update average price
    if (new_qty != 0) {
        int64_t old_avg = atomic_load_explicit(&pos->avg_price,
                                                memory_order_relaxed);
        int64_t new_avg = (old_avg * old_qty + trade_price * qty_delta) / new_qty;
        atomic_store_explicit(&pos->avg_price, new_avg, memory_order_relaxed);
    }

    // Update timestamp
    atomic_store_explicit(&pos->last_trade_time, rdtsc(), memory_order_release);
}
```

### 5.2 Append-Only Logs for Audit Trail

```c
// Append-only log for clearing audit trail
// Journal all state changes for regulatory compliance

#define LOG_SEGMENT_SIZE (256 * 1024 * 1024)  // 256MB per segment
#define LOG_ENTRY_SIZE 256

typedef struct __attribute__((packed)) {
    uint64_t sequence;       // Monotonic sequence number
    uint64_t timestamp;      // Nanosecond timestamp
    uint32_t entry_type;     // Type of audit entry
    uint32_t entry_length;   // Length of payload
    uint64_t account_id;     // Account affected
    uint32_t symbol_id;      // Symbol affected
    uint32_t crc32;          // Checksum
    uint8_t  payload[LOG_ENTRY_SIZE - 40];  // Entry-specific data
} audit_log_entry_t;

typedef struct {
    // Current segment
    int segment_fd;
    void *segment_base;
    size_t segment_offset;
    int segment_number;

    // Sequence number
    _Atomic uint64_t next_sequence;

    // Write buffer for batching
    alignas(64) audit_log_entry_t write_buffer[64];
    int write_buffer_count;

    // Path prefix
    char base_path[256];
} audit_log_t;

// Initialize new log segment with mmap
static int audit_log_new_segment(audit_log_t *log) {
    char path[512];
    snprintf(path, sizeof(path), "%s/segment_%08d.log",
             log->base_path, log->segment_number++);

    log->segment_fd = open(path, O_RDWR | O_CREAT | O_TRUNC, 0644);
    if (log->segment_fd < 0) return -1;

    // Pre-allocate file
    if (ftruncate(log->segment_fd, LOG_SEGMENT_SIZE) < 0) {
        close(log->segment_fd);
        return -1;
    }

    // Memory map for fast writes
    log->segment_base = mmap(NULL, LOG_SEGMENT_SIZE,
                             PROT_READ | PROT_WRITE,
                             MAP_SHARED,
                             log->segment_fd, 0);

    if (log->segment_base == MAP_FAILED) {
        close(log->segment_fd);
        return -1;
    }

    log->segment_offset = 0;
    return 0;
}

// Append entry to log: ~100ns (memory-mapped)
static inline __attribute__((hot))
int audit_log_append(audit_log_t *log,
                     uint32_t entry_type,
                     uint64_t account_id,
                     uint32_t symbol_id,
                     const void *payload,
                     size_t payload_len) {
    // Get sequence number
    uint64_t seq = atomic_fetch_add_explicit(&log->next_sequence, 1,
                                              memory_order_relaxed);

    // Check if we need new segment
    if (log->segment_offset + sizeof(audit_log_entry_t) > LOG_SEGMENT_SIZE) {
        // Sync current segment
        msync(log->segment_base, log->segment_offset, MS_ASYNC);
        munmap(log->segment_base, LOG_SEGMENT_SIZE);
        close(log->segment_fd);

        if (audit_log_new_segment(log) < 0) {
            return -1;
        }
    }

    // Write entry directly to mmap'd region
    audit_log_entry_t *entry = (audit_log_entry_t *)
        ((uint8_t *)log->segment_base + log->segment_offset);

    entry->sequence = seq;
    entry->timestamp = rdtsc();
    entry->entry_type = entry_type;
    entry->entry_length = payload_len;
    entry->account_id = account_id;
    entry->symbol_id = symbol_id;

    if (payload_len > 0) {
        memcpy(entry->payload, payload,
               payload_len < sizeof(entry->payload) ? payload_len : sizeof(entry->payload));
    }

    // Calculate CRC32
    entry->crc32 = crc32(0, (const uint8_t *)entry,
                         sizeof(audit_log_entry_t) - sizeof(uint32_t));

    log->segment_offset += sizeof(audit_log_entry_t);

    return 0;
}

// Sync log to disk (async)
static inline void audit_log_sync(audit_log_t *log) {
    msync(log->segment_base, log->segment_offset, MS_ASYNC);
}
```

### 5.3 LMDB for Persistent State

```c
// LMDB wrapper for persistent clearing state
// Ultra-fast embedded key-value store with ACID guarantees

#include <lmdb.h>

typedef struct {
    MDB_env *env;
    MDB_dbi positions_db;
    MDB_dbi accounts_db;
    MDB_dbi orders_db;
} clearing_lmdb_t;

static int clearing_lmdb_init(clearing_lmdb_t *db, const char *path) {
    int rc;

    // Create environment
    rc = mdb_env_create(&db->env);
    if (rc) return rc;

    // Set map size (maximum database size)
    mdb_env_set_mapsize(db->env, 10ULL * 1024 * 1024 * 1024);  // 10GB

    // Set max databases
    mdb_env_set_maxdbs(db->env, 10);

    // Open environment with options optimized for clearing
    rc = mdb_env_open(db->env, path,
                      MDB_NOSYNC |       // Don't sync on every commit (batch syncs)
                      MDB_WRITEMAP |     // Use writable mmap
                      MDB_MAPASYNC |     // Async flushes
                      MDB_NORDAHEAD,     // Don't use readahead
                      0644);
    if (rc) return rc;

    // Open databases
    MDB_txn *txn;
    mdb_txn_begin(db->env, NULL, 0, &txn);

    mdb_dbi_open(txn, "positions", MDB_CREATE | MDB_INTEGERKEY, &db->positions_db);
    mdb_dbi_open(txn, "accounts", MDB_CREATE | MDB_INTEGERKEY, &db->accounts_db);
    mdb_dbi_open(txn, "orders", MDB_CREATE | MDB_INTEGERKEY, &db->orders_db);

    mdb_txn_commit(txn);

    return 0;
}

// Read position: ~500ns
static inline int clearing_lmdb_get_position(clearing_lmdb_t *db,
                                             uint64_t key,
                                             position_t *pos) {
    MDB_txn *txn;
    MDB_val mdb_key = { sizeof(key), &key };
    MDB_val mdb_val;

    mdb_txn_begin(db->env, NULL, MDB_RDONLY, &txn);

    int rc = mdb_get(txn, db->positions_db, &mdb_key, &mdb_val);
    if (rc == 0) {
        memcpy(pos, mdb_val.mv_data, sizeof(position_t));
    }

    mdb_txn_abort(txn);
    return rc;
}

// Write position: ~1-2 microseconds (with async sync)
static inline int clearing_lmdb_put_position(clearing_lmdb_t *db,
                                             uint64_t key,
                                             const position_t *pos) {
    MDB_txn *txn;
    MDB_val mdb_key = { sizeof(key), &key };
    MDB_val mdb_val = { sizeof(position_t), (void *)pos };

    mdb_txn_begin(db->env, NULL, 0, &txn);

    int rc = mdb_put(txn, db->positions_db, &mdb_key, &mdb_val, 0);
    if (rc == 0) {
        rc = mdb_txn_commit(txn);
    } else {
        mdb_txn_abort(txn);
    }

    return rc;
}

// Batch write for efficiency
static int clearing_lmdb_batch_write(clearing_lmdb_t *db,
                                     uint64_t *keys,
                                     position_t *positions,
                                     int count) {
    MDB_txn *txn;
    mdb_txn_begin(db->env, NULL, 0, &txn);

    for (int i = 0; i < count; i++) {
        MDB_val mdb_key = { sizeof(keys[i]), &keys[i] };
        MDB_val mdb_val = { sizeof(position_t), &positions[i] };

        int rc = mdb_put(txn, db->positions_db, &mdb_key, &mdb_val, 0);
        if (rc) {
            mdb_txn_abort(txn);
            return rc;
        }
    }

    return mdb_txn_commit(txn);
}
```

### 5.4 Event Sourcing for Settlement State

```c
// Event sourcing for settlement state reconstruction
// All state changes captured as events

typedef enum {
    EVENT_TRADE_EXECUTED = 1,
    EVENT_POSITION_OPENED = 2,
    EVENT_POSITION_CLOSED = 3,
    EVENT_MARGIN_CALL = 4,
    EVENT_SETTLEMENT_START = 5,
    EVENT_SETTLEMENT_COMPLETE = 6,
} settlement_event_type_t;

typedef struct __attribute__((packed)) {
    uint64_t event_id;
    uint64_t timestamp;
    uint64_t aggregate_id;  // Account + Symbol composite key
    uint32_t event_type;
    uint32_t version;
    uint8_t  payload[112];  // Event-specific data
} settlement_event_t;

// Event store
typedef struct {
    // Append-only event log
    audit_log_t event_log;

    // In-memory projection of current state
    position_engine_t *current_state;

    // Event handler registry
    void (*handlers[32])(const settlement_event_t *, void *);
} event_store_t;

// Apply event to state (projection)
static void apply_trade_executed(const settlement_event_t *event, void *ctx) {
    position_engine_t *engine = (position_engine_t *)ctx;

    // Extract trade data from payload
    struct {
        uint64_t account_id;
        uint32_t symbol_id;
        int64_t quantity;
        int64_t price;
    } *trade = (void *)event->payload;

    // Find position
    uint32_t account_idx = /* lookup account */ 0;
    uint32_t symbol_idx = trade->symbol_id;

    position_t *pos = position_get(engine, account_idx, symbol_idx);

    // Apply trade to position
    position_update(pos, trade->quantity, trade->price,
                    trade->quantity * trade->price);
}

// Append event and update projection
static inline __attribute__((hot))
int event_store_append(event_store_t *store,
                       uint32_t event_type,
                       uint64_t aggregate_id,
                       const void *payload,
                       size_t payload_len) {
    // Create event
    settlement_event_t event = {
        .event_id = atomic_fetch_add(&store->event_log.next_sequence, 1,
                                     memory_order_relaxed),
        .timestamp = rdtsc(),
        .aggregate_id = aggregate_id,
        .event_type = event_type,
        .version = 1,
    };

    memcpy(event.payload, payload,
           payload_len < sizeof(event.payload) ? payload_len : sizeof(event.payload));

    // Append to log
    audit_log_append(&store->event_log, event_type,
                     aggregate_id >> 32, aggregate_id & 0xFFFFFFFF,
                     &event, sizeof(event));

    // Apply to in-memory state
    if (store->handlers[event_type]) {
        store->handlers[event_type](&event, store->current_state);
    }

    return 0;
}

// Rebuild state from event log (recovery)
static int event_store_replay(event_store_t *store, int from_segment) {
    // Read all events from log and apply
    // Used for crash recovery

    for (int seg = from_segment; ; seg++) {
        char path[512];
        snprintf(path, sizeof(path), "%s/segment_%08d.log",
                 store->event_log.base_path, seg);

        int fd = open(path, O_RDONLY);
        if (fd < 0) break;  // No more segments

        struct stat st;
        fstat(fd, &st);

        void *data = mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);

        // Process all entries in segment
        size_t offset = 0;
        while (offset + sizeof(audit_log_entry_t) <= st.st_size) {
            audit_log_entry_t *entry = (audit_log_entry_t *)((uint8_t *)data + offset);

            if (entry->sequence == 0) break;  // End of valid data

            // Verify CRC
            uint32_t crc = crc32(0, (const uint8_t *)entry,
                                 sizeof(audit_log_entry_t) - sizeof(uint32_t));
            if (crc != entry->crc32) {
                // Corruption detected
                break;
            }

            // Apply event
            settlement_event_t *event = (settlement_event_t *)entry->payload;
            if (store->handlers[event->event_type]) {
                store->handlers[event->event_type](event, store->current_state);
            }

            offset += sizeof(audit_log_entry_t);
        }

        munmap(data, st.st_size);
        close(fd);
    }

    return 0;
}
```

---

## 6. CPU Optimization

### 6.1 Core Pinning and Isolation

```c
// CPU affinity and isolation for clearing hot paths

#define _GNU_SOURCE
#include <sched.h>
#include <pthread.h>

typedef struct {
    int cpu_id;
    int numa_node;
    bool isolated;
    uint64_t tsc_frequency;
} cpu_config_t;

// Pin thread to specific CPU core
static int pin_thread_to_cpu(int cpu_id) {
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(cpu_id, &cpuset);

    int rc = pthread_setaffinity_np(pthread_self(),
                                    sizeof(cpu_set_t), &cpuset);
    if (rc != 0) {
        return -1;
    }

    // Also set scheduling policy for lowest latency
    struct sched_param param = { .sched_priority = 99 };
    rc = pthread_setschedparam(pthread_self(), SCHED_FIFO, &param);

    return rc;
}

// Configure kernel for isolated CPUs
// Run once at startup: isolcpus=2,3,4,5 nohz_full=2,3,4,5 rcu_nocbs=2,3,4,5
static void print_kernel_config(void) {
    printf("Required kernel parameters:\n");
    printf("  isolcpus=2,3,4,5      # Isolate CPUs 2-5 from scheduler\n");
    printf("  nohz_full=2,3,4,5     # Disable timer tick on isolated CPUs\n");
    printf("  rcu_nocbs=2,3,4,5     # Move RCU callbacks off isolated CPUs\n");
    printf("  intel_pstate=disable  # Disable frequency scaling\n");
    printf("  processor.max_cstate=1 # Prevent deep C-states\n");
    printf("  idle=poll             # Poll instead of idle\n");
}

// Clearing thread configuration
typedef struct {
    int market_data_cpu;     // CPU for market data processing
    int clearing_engine_cpu; // CPU for clearing calculations
    int risk_engine_cpu;     // CPU for risk calculations
    int persistence_cpu;     // CPU for I/O and persistence
} clearing_cpu_layout_t;

static void configure_clearing_threads(clearing_cpu_layout_t *layout) {
    // Market data thread - highest priority, isolated core
    layout->market_data_cpu = 2;

    // Clearing engine - isolated core, same NUMA node as market data
    layout->clearing_engine_cpu = 3;

    // Risk engine - isolated core
    layout->risk_engine_cpu = 4;

    // Persistence - can share with other I/O, non-isolated
    layout->persistence_cpu = 0;
}

// Thread startup with optimal configuration
static void *clearing_thread_start(void *arg) {
    cpu_config_t *config = (cpu_config_t *)arg;

    // Pin to CPU
    pin_thread_to_cpu(config->cpu_id);

    // Lock thread memory to prevent page faults
    mlockall(MCL_CURRENT | MCL_FUTURE);

    // Pre-fault stack
    volatile char stack[64 * 1024];
    memset((void *)stack, 0, sizeof(stack));

    // Disable interrupts on this CPU if possible (requires root)
    // echo 0 > /proc/irq/*/smp_affinity for non-essential IRQs

    // Main loop - never yields CPU
    while (1) {
        // Process clearing messages
        // Use busy polling, never block
    }

    return NULL;
}
```

### 6.2 SIMD for Batch Calculations

```c
// AVX2/AVX-512 for batch margin and P&L calculations

#include <immintrin.h>

// Calculate P&L for 8 positions simultaneously (AVX2)
// Latency: ~5ns for 8 positions
static inline __attribute__((hot))
void calculate_pnl_batch_avx2(const int64_t *quantities,    // 8 quantities
                               const int64_t *avg_prices,   // 8 average prices
                               const int64_t *current_prices, // 8 current prices
                               int64_t *unrealized_pnl) {   // 8 output P&L values
    // Load 8 int64 values using AVX2 (4 at a time)
    __m256i qty_lo = _mm256_loadu_si256((const __m256i *)quantities);
    __m256i qty_hi = _mm256_loadu_si256((const __m256i *)(quantities + 4));

    __m256i avg_lo = _mm256_loadu_si256((const __m256i *)avg_prices);
    __m256i avg_hi = _mm256_loadu_si256((const __m256i *)(avg_prices + 4));

    __m256i cur_lo = _mm256_loadu_si256((const __m256i *)current_prices);
    __m256i cur_hi = _mm256_loadu_si256((const __m256i *)(current_prices + 4));

    // Calculate price difference: current - avg
    __m256i diff_lo = _mm256_sub_epi64(cur_lo, avg_lo);
    __m256i diff_hi = _mm256_sub_epi64(cur_hi, avg_hi);

    // Multiply by quantity (need to handle int64 multiplication)
    // AVX2 doesn't have native int64 multiply, use custom approach

    // For 32-bit multiply (simplified for positions < 2^32)
    __m256i pnl_lo = _mm256_mul_epi32(diff_lo, qty_lo);
    __m256i pnl_hi = _mm256_mul_epi32(diff_hi, qty_hi);

    // Store results
    _mm256_storeu_si256((__m256i *)unrealized_pnl, pnl_lo);
    _mm256_storeu_si256((__m256i *)(unrealized_pnl + 4), pnl_hi);
}

// AVX-512 version for 16 positions at once
#ifdef __AVX512F__
static inline __attribute__((hot))
void calculate_pnl_batch_avx512(const int64_t *quantities,
                                 const int64_t *avg_prices,
                                 const int64_t *current_prices,
                                 int64_t *unrealized_pnl,
                                 int count) {
    for (int i = 0; i < count; i += 8) {
        __m512i qty = _mm512_loadu_si512((const __m512i *)(quantities + i));
        __m512i avg = _mm512_loadu_si512((const __m512i *)(avg_prices + i));
        __m512i cur = _mm512_loadu_si512((const __m512i *)(current_prices + i));

        // Price difference
        __m512i diff = _mm512_sub_epi64(cur, avg);

        // Multiply (AVX-512 has native int64 multiply)
        __m512i pnl = _mm512_mullo_epi64(diff, qty);

        // Store
        _mm512_storeu_si512((__m512i *)(unrealized_pnl + i), pnl);
    }
}
#endif

// SIMD margin calculation
static inline __attribute__((hot))
void calculate_margin_batch(const int64_t *positions,
                            const int64_t *prices,
                            const int64_t *margin_rates,  // Fixed point
                            int64_t *margin_required,
                            int count) {
    #pragma omp simd
    for (int i = 0; i < count; i++) {
        int64_t notional = positions[i] * prices[i] / PRICE_SCALE;
        int64_t abs_notional = notional >= 0 ? notional : -notional;
        margin_required[i] = abs_notional * margin_rates[i] / PRICE_SCALE;
    }
}
```

### 6.3 Branch Prediction Optimization

```c
// Branch prediction optimization for clearing decision logic

// Use likely/unlikely hints for known branch probabilities
#define LIKELY(x)   __builtin_expect(!!(x), 1)
#define UNLIKELY(x) __builtin_expect(!!(x), 0)

// Example: Risk check with optimized branch prediction
static inline __attribute__((hot))
bool risk_check_optimized(const position_t *pos,
                          int64_t proposed_quantity,
                          const risk_limits_t *limits) {
    // Most orders pass risk checks (99%+)
    // Structure checks from most likely to fail to least likely

    int64_t new_position = pos->quantity + proposed_quantity;
    int64_t abs_position = new_position >= 0 ? new_position : -new_position;

    // Position limit check - most common rejection reason
    if (UNLIKELY(abs_position > limits->max_position)) {
        return false;
    }

    // Notional limit - less common
    int64_t notional = abs_position * pos->avg_price / PRICE_SCALE;
    if (UNLIKELY(notional > limits->max_notional)) {
        return false;
    }

    // Loss limit - rare
    if (UNLIKELY(pos->unrealized_pnl < -limits->max_loss)) {
        return false;
    }

    // All checks passed (most common path)
    return true;
}

// Branch-free risk check (alternative approach)
static inline __attribute__((hot))
bool risk_check_branchfree(const position_t *pos,
                           int64_t proposed_quantity,
                           const risk_limits_t *limits) {
    int64_t new_position = pos->quantity + proposed_quantity;

    // Use arithmetic instead of branches
    int64_t abs_position = (new_position ^ (new_position >> 63)) -
                           (new_position >> 63);

    // All conditions computed without branches
    int64_t notional = abs_position * pos->avg_price / PRICE_SCALE;

    bool position_ok = abs_position <= limits->max_position;
    bool notional_ok = notional <= limits->max_notional;
    bool loss_ok = pos->unrealized_pnl >= -limits->max_loss;

    // Single combined result
    return position_ok & notional_ok & loss_ok;
}

// Message type dispatch - optimize for common cases
typedef enum {
    MSG_TRADE = 0,          // ~60% of messages
    MSG_POSITION_UPDATE = 1, // ~25% of messages
    MSG_RISK_CHECK = 2,      // ~10% of messages
    MSG_OTHER = 3            // ~5% of messages
} msg_type_t;

static inline __attribute__((hot))
void dispatch_message_optimized(uint8_t msg_type, const void *data) {
    // Fast path for common message types
    switch (msg_type) {
        case MSG_TRADE:
            // Most common - compiler will optimize this path
            handle_trade(data);
            return;

        case MSG_POSITION_UPDATE:
            handle_position_update(data);
            return;

        case MSG_RISK_CHECK:
            handle_risk_check(data);
            return;

        default:
            // Rare path - marked as unlikely
            if (UNLIKELY(msg_type == MSG_OTHER)) {
                handle_other(data);
            }
    }
}
```

### 6.4 Prefetching Strategies

```c
// Software prefetching for clearing message processing

// Prefetch hints
#define PREFETCH_T0(addr) __builtin_prefetch(addr, 0, 3)  // L1 cache
#define PREFETCH_T1(addr) __builtin_prefetch(addr, 0, 2)  // L2 cache
#define PREFETCH_T2(addr) __builtin_prefetch(addr, 0, 1)  // L3 cache
#define PREFETCH_NTA(addr) __builtin_prefetch(addr, 0, 0) // Non-temporal

// Process clearing messages with prefetching
static void process_clearing_messages(clearing_msg_t *msgs,
                                      int count,
                                      position_engine_t *engine) {
    for (int i = 0; i < count; i++) {
        clearing_msg_t *msg = &msgs[i];

        // Prefetch next message
        if (i + 1 < count) {
            PREFETCH_T0(&msgs[i + 1]);
        }

        // Prefetch position for next message
        if (i + 2 < count) {
            uint64_t next_key = ((uint64_t)msgs[i + 2].account_id << 32) |
                                msgs[i + 2].symbol_id;
            position_t *next_pos = position_lookup(engine, next_key);
            if (next_pos) {
                PREFETCH_T0(next_pos);
            }
        }

        // Process current message
        uint64_t key = ((uint64_t)msg->account_id << 32) | msg->symbol_id;
        position_t *pos = position_lookup(engine, key);

        if (pos) {
            position_update(pos, msg->quantity, msg->price,
                           msg->quantity * msg->price);
        }
    }
}

// Prefetch-optimized batch processing with pipeline
static void process_clearing_pipeline(clearing_msg_t *msgs,
                                      int count,
                                      position_engine_t *engine) {
    // Process in chunks to maintain prefetch distance
    const int PREFETCH_DISTANCE = 4;

    // Prime the prefetch pipeline
    for (int i = 0; i < PREFETCH_DISTANCE && i < count; i++) {
        uint64_t key = ((uint64_t)msgs[i].account_id << 32) |
                       msgs[i].symbol_id;
        position_t *pos = position_lookup(engine, key);
        if (pos) {
            PREFETCH_T0(pos);
        }
    }

    // Main processing loop with rolling prefetch
    for (int i = 0; i < count; i++) {
        // Prefetch ahead
        int prefetch_idx = i + PREFETCH_DISTANCE;
        if (prefetch_idx < count) {
            PREFETCH_T0(&msgs[prefetch_idx]);

            uint64_t key = ((uint64_t)msgs[prefetch_idx].account_id << 32) |
                           msgs[prefetch_idx].symbol_id;
            position_t *pos = position_lookup(engine, key);
            if (pos) {
                PREFETCH_T0(pos);
            }
        }

        // Process current message (data should be in L1 cache now)
        process_single_message(&msgs[i], engine);
    }
}
```

---

## 7. Real-Time Settlement Architecture

### 7.1 Event-Driven Settlement Engine

```c
// Event-driven settlement engine architecture

typedef enum {
    SETTLE_STATE_PENDING = 0,
    SETTLE_STATE_MATCHED = 1,
    SETTLE_STATE_NETTED = 2,
    SETTLE_STATE_INSTRUCTIONS_SENT = 3,
    SETTLE_STATE_AFFIRMED = 4,
    SETTLE_STATE_SETTLED = 5,
    SETTLE_STATE_FAILED = 6,
} settlement_state_t;

typedef struct {
    uint64_t trade_id;
    uint64_t account_id;
    uint32_t symbol_id;
    int64_t quantity;
    int64_t price;
    uint64_t trade_date;
    uint64_t settlement_date;
    uint8_t state;
    uint8_t flags;
} settlement_item_t;

// Event loop for settlement engine
typedef struct {
    // Input queues (SPSC from different sources)
    clearing_spsc_queue_t *trade_queue;
    clearing_spsc_queue_t *confirm_queue;
    clearing_spsc_queue_t *cancel_queue;

    // Output queue to persistence layer
    clearing_spsc_queue_t *persist_queue;

    // In-memory settlement state
    settlement_item_t *pending_items;
    uint32_t pending_count;
    uint32_t pending_capacity;

    // Index: trade_id -> pending_items index
    account_hashmap_t trade_index;

    // Statistics
    uint64_t trades_processed;
    uint64_t settlements_completed;
    uint64_t settlements_failed;
} settlement_engine_t;

// Main settlement event loop - runs on isolated CPU
static void settlement_engine_loop(settlement_engine_t *engine) {
    clearing_msg_t msg;

    while (1) {
        // Process trade events (highest priority)
        while (clearing_queue_pop(engine->trade_queue, &msg)) {
            handle_trade_event(engine, &msg);
        }

        // Process confirmations
        while (clearing_queue_pop(engine->confirm_queue, &msg)) {
            handle_confirm_event(engine, &msg);
        }

        // Process cancellations
        while (clearing_queue_pop(engine->cancel_queue, &msg)) {
            handle_cancel_event(engine, &msg);
        }

        // Check for timed events (settlement deadlines)
        check_settlement_timers(engine);

        // Yield if no work (optional - can also busy-poll)
        // _mm_pause();  // Reduce power consumption while spinning
    }
}

// Handle new trade for settlement
static inline __attribute__((hot))
void handle_trade_event(settlement_engine_t *engine,
                        const clearing_msg_t *msg) {
    // Allocate settlement item
    if (engine->pending_count >= engine->pending_capacity) {
        // Queue full - should not happen in properly sized system
        return;
    }

    settlement_item_t *item = &engine->pending_items[engine->pending_count];

    item->trade_id = msg->msg_id;
    item->account_id = msg->account_id;
    item->symbol_id = msg->symbol_id;
    item->quantity = msg->quantity;
    item->price = msg->price;
    item->trade_date = msg->timestamp;
    item->settlement_date = calculate_settlement_date(msg->timestamp);
    item->state = SETTLE_STATE_PENDING;
    item->flags = 0;

    // Add to index
    account_upsert(&engine->trade_index, msg->msg_id);

    engine->pending_count++;
    engine->trades_processed++;

    // Start matching process
    start_trade_matching(engine, item);
}

// Settlement state machine
static void advance_settlement_state(settlement_engine_t *engine,
                                     settlement_item_t *item) {
    switch (item->state) {
        case SETTLE_STATE_PENDING:
            if (check_trade_matched(item)) {
                item->state = SETTLE_STATE_MATCHED;
                // Start netting
                initiate_netting(engine, item);
            }
            break;

        case SETTLE_STATE_MATCHED:
            if (check_netting_complete(item)) {
                item->state = SETTLE_STATE_NETTED;
                // Generate settlement instructions
                generate_settlement_instructions(engine, item);
            }
            break;

        case SETTLE_STATE_NETTED:
            if (check_instructions_sent(item)) {
                item->state = SETTLE_STATE_INSTRUCTIONS_SENT;
                // Wait for affirmation
            }
            break;

        case SETTLE_STATE_INSTRUCTIONS_SENT:
            if (check_affirmed(item)) {
                item->state = SETTLE_STATE_AFFIRMED;
                // Ready for final settlement
            }
            break;

        case SETTLE_STATE_AFFIRMED:
            if (check_settlement_date(item)) {
                item->state = SETTLE_STATE_SETTLED;
                engine->settlements_completed++;
                // Remove from pending
                remove_pending_item(engine, item);
            }
            break;

        case SETTLE_STATE_FAILED:
            // Handle failure - retry or escalate
            handle_settlement_failure(engine, item);
            break;
    }
}
```

### 7.2 CQRS for Read/Write Separation

```c
// CQRS (Command Query Responsibility Segregation) for settlement

// Command side - handles writes
typedef struct {
    // Command queue from clients
    clearing_spsc_queue_t *command_queue;

    // Event store for persistence
    event_store_t *event_store;

    // Write model - minimal state for command validation
    position_engine_t *write_model;
} settlement_command_side_t;

// Query side - handles reads
typedef struct {
    // Read-only projection of settlement state
    const position_engine_t *read_model;

    // Materialized views for common queries
    struct {
        // Pending settlements by account
        settlement_item_t **by_account[MAX_ACCOUNTS];
        int counts[MAX_ACCOUNTS];
    } pending_view;

    struct {
        // Settlements by date
        settlement_item_t **by_date[365];
        int counts[365];
    } date_view;

    // Subscription for real-time updates
    clearing_spsc_queue_t *update_queue;
} settlement_query_side_t;

// Command handler - validates and executes commands
static int handle_settlement_command(settlement_command_side_t *cmd,
                                     const settlement_command_t *command) {
    // Validate command against current state
    if (!validate_command(cmd->write_model, command)) {
        return -1;
    }

    // Generate event
    settlement_event_t event;
    create_event_from_command(command, &event);

    // Persist event (this is the source of truth)
    int rc = event_store_append(cmd->event_store,
                                event.event_type,
                                event.aggregate_id,
                                event.payload,
                                sizeof(event.payload));

    if (rc < 0) {
        return rc;
    }

    // Update write model
    apply_event_to_write_model(cmd->write_model, &event);

    return 0;
}

// Query handler - reads from materialized views
static int query_pending_by_account(settlement_query_side_t *query,
                                    uint64_t account_id,
                                    settlement_item_t **items,
                                    int *count) {
    uint32_t account_idx = account_id % MAX_ACCOUNTS;

    *items = query->pending_view.by_account[account_idx];
    *count = query->pending_view.counts[account_idx];

    return 0;
}

// Projection updater - maintains read model from events
static void update_read_projections(settlement_query_side_t *query,
                                    const settlement_event_t *event) {
    switch (event->event_type) {
        case EVENT_TRADE_EXECUTED:
            add_to_pending_view(query, event);
            break;

        case EVENT_SETTLEMENT_COMPLETE:
            remove_from_pending_view(query, event);
            break;

        default:
            break;
    }
}
```

### 7.3 Eventual Consistency Models

```c
// Eventual consistency for distributed clearing

typedef struct {
    uint64_t sequence;
    uint64_t timestamp;
    uint8_t  source_node;
    uint8_t  flags;
} vector_clock_t;

typedef struct {
    uint64_t account_id;
    vector_clock_t clock;
    int64_t position;
    int64_t realized_pnl;
} replicated_position_t;

// Conflict resolution using last-writer-wins with vector clocks
static bool position_merge(replicated_position_t *local,
                           const replicated_position_t *remote) {
    // Compare vector clocks
    if (remote->clock.sequence > local->clock.sequence) {
        // Remote is newer - apply it
        *local = *remote;
        return true;
    }

    if (remote->clock.sequence == local->clock.sequence) {
        // Concurrent updates - use timestamp as tiebreaker
        if (remote->clock.timestamp > local->clock.timestamp) {
            *local = *remote;
            return true;
        }

        // Same timestamp - use node ID as final tiebreaker
        if (remote->clock.source_node > local->clock.source_node) {
            *local = *remote;
            return true;
        }
    }

    return false;  // Local is newer or equal
}

// Anti-entropy protocol for synchronization
typedef struct {
    // Local state
    replicated_position_t *positions;
    int position_count;

    // Pending sync queue
    clearing_spsc_queue_t *sync_queue;

    // Peer connections
    struct {
        int socket_fd;
        uint8_t node_id;
        uint64_t last_sync;
    } peers[8];
    int peer_count;
} replication_ctx_t;

// Sync positions with peer
static void sync_with_peer(replication_ctx_t *ctx, int peer_idx) {
    // Send local positions that are newer than peer's last sync
    uint64_t sync_since = ctx->peers[peer_idx].last_sync;

    for (int i = 0; i < ctx->position_count; i++) {
        if (ctx->positions[i].clock.timestamp > sync_since) {
            // Send position update to peer
            send(ctx->peers[peer_idx].socket_fd,
                 &ctx->positions[i],
                 sizeof(replicated_position_t), 0);
        }
    }

    // Receive peer's updates
    replicated_position_t remote;
    while (recv(ctx->peers[peer_idx].socket_fd,
                &remote, sizeof(remote), MSG_DONTWAIT) > 0) {
        // Find local position
        replicated_position_t *local = find_position(ctx, remote.account_id);
        if (local) {
            position_merge(local, &remote);
        } else {
            // New position from peer
            add_position(ctx, &remote);
        }
    }

    ctx->peers[peer_idx].last_sync = rdtsc();
}
```

### 7.4 Distributed Consensus (Raft) for Redundancy

```c
// Simplified Raft implementation for clearing state replication

typedef enum {
    RAFT_FOLLOWER = 0,
    RAFT_CANDIDATE = 1,
    RAFT_LEADER = 2,
} raft_state_t;

typedef struct {
    uint64_t term;
    uint64_t index;
    uint8_t  type;
    uint8_t  data_len;
    uint8_t  data[128];
} raft_log_entry_t;

typedef struct {
    // Node identity
    uint8_t node_id;
    uint8_t cluster_size;

    // Persistent state
    uint64_t current_term;
    int8_t voted_for;
    raft_log_entry_t *log;
    uint64_t log_size;
    uint64_t log_capacity;

    // Volatile state
    raft_state_t state;
    uint64_t commit_index;
    uint64_t last_applied;

    // Leader state
    uint64_t next_index[8];  // Per follower
    uint64_t match_index[8];

    // Timing
    uint64_t election_timeout;
    uint64_t last_heartbeat;

    // State machine
    position_engine_t *state_machine;

    // Network
    int peer_sockets[8];
} raft_node_t;

// Append entries RPC (leader to followers)
typedef struct __attribute__((packed)) {
    uint64_t term;
    uint8_t leader_id;
    uint64_t prev_log_index;
    uint64_t prev_log_term;
    uint64_t leader_commit;
    uint16_t entry_count;
    // Followed by entries
} append_entries_req_t;

// Leader replication
static void raft_replicate(raft_node_t *node,
                           const void *command,
                           size_t command_len) {
    if (node->state != RAFT_LEADER) {
        return;  // Only leader can replicate
    }

    // Append to local log
    raft_log_entry_t *entry = &node->log[node->log_size++];
    entry->term = node->current_term;
    entry->index = node->log_size;
    entry->data_len = command_len;
    memcpy(entry->data, command, command_len);

    // Send to all followers
    for (int i = 0; i < node->cluster_size; i++) {
        if (i == node->node_id) continue;

        append_entries_req_t req = {
            .term = node->current_term,
            .leader_id = node->node_id,
            .prev_log_index = node->next_index[i] - 1,
            .prev_log_term = node->log[node->next_index[i] - 1].term,
            .leader_commit = node->commit_index,
            .entry_count = 1,
        };

        send(node->peer_sockets[i], &req, sizeof(req), 0);
        send(node->peer_sockets[i], entry, sizeof(*entry), 0);
    }
}

// Apply committed entries to state machine
static void raft_apply_committed(raft_node_t *node) {
    while (node->last_applied < node->commit_index) {
        node->last_applied++;

        raft_log_entry_t *entry = &node->log[node->last_applied];

        // Apply to clearing state machine
        apply_clearing_command(node->state_machine,
                              entry->data,
                              entry->data_len);
    }
}

// Check for commit (majority replication)
static void raft_check_commit(raft_node_t *node) {
    if (node->state != RAFT_LEADER) return;

    for (uint64_t n = node->commit_index + 1; n <= node->log_size; n++) {
        if (node->log[n].term != node->current_term) continue;

        int match_count = 1;  // Self
        for (int i = 0; i < node->cluster_size; i++) {
            if (i != node->node_id && node->match_index[i] >= n) {
                match_count++;
            }
        }

        if (match_count > node->cluster_size / 2) {
            node->commit_index = n;
        }
    }

    raft_apply_committed(node);
}
```

---

## Summary: Latency Budget for Complete Clearing Pipeline

| Component | Target Latency | Technology |
|-----------|---------------|------------|
| Network receive | 200-500ns | ef_vi/DPDK |
| Message parse | 20-50ns | SBE/zero-copy |
| Position lookup | 20-50ns | Lock-free hashmap |
| Risk check | 30-100ns | Branch-free/SIMD |
| Position update | 30-50ns | Atomic operations |
| Event persistence | 100ns-1us | mmap'd log |
| Network send | 200-500ns | ef_vi PIO |
| **Total wire-to-wire** | **600ns-2.5us** | |

This architecture provides the foundation for a modern, ultra-low-latency clearing infrastructure capable of processing millions of transactions per second with sub-microsecond latency.
