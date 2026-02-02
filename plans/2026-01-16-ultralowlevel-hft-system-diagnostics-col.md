# Ultra-Low-Level HFT System Diagnostics Collector

## Integration with Existing Infrastructure

This collector integrates directly with your existing codebase:
- Uses `types.h` conventions (CACHE_ALIGNED, ALWAYS_INLINE, HOT_PATH)
- Extends `timing.h` with hardware counter reading
- Augments `metrics_collector.h` with system diagnostics
- Validates `scripts/*.sh` tuning has been applied
- Follows your Makefile build conventions

---

## Architecture: Fully Integrated C Module

```
src/diagnostics/
├── system_diagnostics.h     # Main header (integrates with types.h)
├── system_diagnostics.c     # Implementation
├── cpu_collector.h          # CPUID + MSR + perf_event
├── cpu_collector.c
├── network_collector.h      # ethtool + /proc/net + NIC stats
├── network_collector.c
├── memory_collector.h       # NUMA + huge pages + page faults
├── memory_collector.c
├── scheduler_collector.h    # RT priority + scheduler tunables
├── scheduler_collector.c
└── ebpf/                    # eBPF programs (optional layer)
    ├── sched_latency.bpf.c
    └── Makefile
```

---

## Data Collection by Category (Mapped to data-required.md)

### 1. CPU Reality

**Collection Method:** CPUID intrinsics + MSR via `/dev/cpu/*/msr` + perf_event_open()

```c
// src/diagnostics/cpu_collector.h
#ifndef DIAGNOSTICS_CPU_COLLECTOR_H
#define DIAGNOSTICS_CPU_COLLECTOR_H

#include "../core/types.h"
#include <stdint.h>

typedef struct CACHE_ALIGNED {
    // CPU identification
    char model_name[64];
    uint32_t family;
    uint32_t model;
    uint32_t stepping;

    // Cache topology (bytes)
    uint32_t l1d_size;
    uint32_t l1i_size;
    uint32_t l2_size;
    uint32_t l3_size;
    uint32_t cache_line_size;

    // Feature flags
    uint32_t has_avx     : 1;
    uint32_t has_avx2    : 1;
    uint32_t has_bmi2    : 1;
    uint32_t has_aesni   : 1;
    uint32_t has_rdrand  : 1;
    uint32_t has_rdseed  : 1;
    uint32_t has_tsc     : 1;
    uint32_t constant_tsc: 1;
    uint32_t nonstop_tsc : 1;

    // Steal time (VPS only)
    double steal_time_pct;
    uint64_t steal_time_ns;

    // TSC frequency
    uint64_t tsc_freq_hz;

    PAD_TO_CACHE_LINE(128);
} cpu_info_t;

// Collection functions
int cpu_info_collect(cpu_info_t *info);
int cpu_get_steal_time(double *steal_pct);

#endif
```

**Implementation using CPUID:**
```c
// src/diagnostics/cpu_collector.c
#include "cpu_collector.h"
#include <cpuid.h>

static void get_cpu_features(cpu_info_t *info) {
    unsigned int eax, ebx, ecx, edx;

    // Feature detection (leaf 1)
    __cpuid(1, eax, ebx, ecx, edx);
    info->has_aesni = (ecx >> 25) & 1;
    info->has_avx   = (ecx >> 28) & 1;

    // Extended features (leaf 7)
    __cpuid_count(7, 0, eax, ebx, ecx, edx);
    info->has_avx2   = (ebx >> 5) & 1;
    info->has_bmi2   = (ebx >> 8) & 1;
    info->has_rdrand = (ecx >> 30) & 1;

    // TSC features (leaf 0x80000007)
    __cpuid(0x80000007, eax, ebx, ecx, edx);
    info->constant_tsc = (edx >> 8) & 1;
    info->nonstop_tsc  = (edx >> 8) & 1;

    // Cache topology (leaf 4, iterate subleaves)
    for (int i = 0; ; i++) {
        __cpuid_count(4, i, eax, ebx, ecx, edx);
        int type = eax & 0x1F;
        if (type == 0) break;

        int level = (eax >> 5) & 0x7;
        uint32_t line_size   = (ebx & 0xFFF) + 1;
        uint32_t partitions  = ((ebx >> 12) & 0x3FF) + 1;
        uint32_t ways        = ((ebx >> 22) & 0x3FF) + 1;
        uint32_t sets        = ecx + 1;
        uint32_t cache_size  = line_size * partitions * ways * sets;

        info->cache_line_size = line_size;

        if (level == 1 && type == 1) info->l1d_size = cache_size;
        if (level == 1 && type == 2) info->l1i_size = cache_size;
        if (level == 2) info->l2_size = cache_size;
        if (level == 3) info->l3_size = cache_size;
    }
}
```

**Steal Time via /proc/stat:**
```c
int cpu_get_steal_time(double *steal_pct) {
    FILE *f = fopen("/proc/stat", "r");
    if (!f) return -1;

    char line[256];
    if (!fgets(line, sizeof(line), f)) {
        fclose(f);
        return -1;
    }

    unsigned long user, nice, sys, idle, iowait, irq, softirq, steal;
    sscanf(line, "cpu %lu %lu %lu %lu %lu %lu %lu %lu",
           &user, &nice, &sys, &idle, &iowait, &irq, &softirq, &steal);

    unsigned long total = user + nice + sys + idle + iowait + irq + softirq + steal;
    *steal_pct = (total > 0) ? (100.0 * steal / total) : 0.0;

    fclose(f);
    return 0;
}
```

---

### 2. Network Hardware (NIC)

**Collection Method:** ethtool ioctl + /sys/class/net + /proc/interrupts

```c
// src/diagnostics/network_collector.h
typedef struct CACHE_ALIGNED {
    // Driver info
    char driver_name[32];
    char driver_version[32];
    char bus_info[32];

    // Ring buffer config
    uint32_t rx_ring_current;
    uint32_t rx_ring_max;
    uint32_t tx_ring_current;
    uint32_t tx_ring_max;

    // Interrupt coalescing
    uint32_t rx_usecs;
    uint32_t tx_usecs;
    uint32_t adaptive_rx : 1;
    uint32_t adaptive_tx : 1;

    // IRQ affinity (bitmask per IRQ)
    int irq_count;
    struct {
        int irq_num;
        uint64_t affinity_mask;
    } irqs[16];

    // Offload status
    uint32_t gro_enabled : 1;
    uint32_t gso_enabled : 1;
    uint32_t tso_enabled : 1;
    uint32_t lro_enabled : 1;

    PAD_TO_CACHE_LINE(256);
} nic_info_t;
```

**Implementation using ethtool ioctl:**
```c
#include <linux/ethtool.h>
#include <linux/sockios.h>
#include <net/if.h>
#include <sys/ioctl.h>

int nic_info_collect(const char *ifname, nic_info_t *info) {
    int sock = socket(AF_INET, SOCK_DGRAM, 0);
    if (sock < 0) return -1;

    struct ifreq ifr;
    strncpy(ifr.ifr_name, ifname, IFNAMSIZ);

    // Get driver info
    struct ethtool_drvinfo drvinfo = { .cmd = ETHTOOL_GDRVINFO };
    ifr.ifr_data = (caddr_t)&drvinfo;
    if (ioctl(sock, SIOCETHTOOL, &ifr) == 0) {
        strncpy(info->driver_name, drvinfo.driver, sizeof(info->driver_name));
        strncpy(info->driver_version, drvinfo.version, sizeof(info->driver_version));
        strncpy(info->bus_info, drvinfo.bus_info, sizeof(info->bus_info));
    }

    // Get ring buffer sizes
    struct ethtool_ringparam ring = { .cmd = ETHTOOL_GRINGPARAM };
    ifr.ifr_data = (caddr_t)&ring;
    if (ioctl(sock, SIOCETHTOOL, &ifr) == 0) {
        info->rx_ring_current = ring.rx_pending;
        info->rx_ring_max = ring.rx_max_pending;
        info->tx_ring_current = ring.tx_pending;
        info->tx_ring_max = ring.tx_max_pending;
    }

    // Get coalescing settings
    struct ethtool_coalesce coal = { .cmd = ETHTOOL_GCOALESCE };
    ifr.ifr_data = (caddr_t)&coal;
    if (ioctl(sock, SIOCETHTOOL, &ifr) == 0) {
        info->rx_usecs = coal.rx_coalesce_usecs;
        info->tx_usecs = coal.tx_coalesce_usecs;
        info->adaptive_rx = coal.use_adaptive_rx_coalesce;
        info->adaptive_tx = coal.use_adaptive_tx_coalesce;
    }

    close(sock);
    return 0;
}
```

---

### 3. Kernel & Memory Topology

**Collection Method:** /proc/cmdline + /sys/devices/system/cpu + /proc/interrupts

```c
// src/diagnostics/scheduler_collector.h
typedef struct CACHE_ALIGNED {
    // Kernel boot params
    char isolated_cpus[64];      // From isolcpus=
    char nohz_full_cpus[64];     // From nohz_full=
    char rcu_nocbs_cpus[64];     // From rcu_nocbs=

    // Isolation verification
    uint64_t interrupts_on_isolated[16];  // Should be ~0

    // Context switches
    uint64_t context_switches_per_sec;

    // Scheduler tunables
    uint64_t sched_min_granularity_ns;
    uint64_t sched_wakeup_granularity_ns;
    uint64_t sched_migration_cost_ns;
    int64_t  sched_rt_runtime_us;  // -1 = unlimited

    // Real-time limits
    uint32_t rtprio_limit;        // From ulimit -r
    uint64_t memlock_limit;       // From ulimit -l
    uint64_t nofile_limit;        // From ulimit -n

    PAD_TO_CACHE_LINE(256);
} scheduler_info_t;
```

**Implementation:**
```c
int scheduler_info_collect(scheduler_info_t *info) {
    // Parse /proc/cmdline for isolation params
    FILE *f = fopen("/proc/cmdline", "r");
    if (f) {
        char cmdline[4096];
        if (fgets(cmdline, sizeof(cmdline), f)) {
            // Extract isolcpus=
            char *p = strstr(cmdline, "isolcpus=");
            if (p) sscanf(p, "isolcpus=%63s", info->isolated_cpus);

            // Extract nohz_full=
            p = strstr(cmdline, "nohz_full=");
            if (p) sscanf(p, "nohz_full=%63s", info->nohz_full_cpus);
        }
        fclose(f);
    }

    // Read scheduler tunables from /proc/sys/kernel/
    read_sysfs_uint64("/proc/sys/kernel/sched_min_granularity_ns",
                      &info->sched_min_granularity_ns);
    read_sysfs_uint64("/proc/sys/kernel/sched_wakeup_granularity_ns",
                      &info->sched_wakeup_granularity_ns);
    read_sysfs_uint64("/proc/sys/kernel/sched_migration_cost_ns",
                      &info->sched_migration_cost_ns);
    read_sysfs_int64("/proc/sys/kernel/sched_rt_runtime_us",
                     &info->sched_rt_runtime_us);

    // Get resource limits
    struct rlimit rl;
    if (getrlimit(RLIMIT_RTPRIO, &rl) == 0)
        info->rtprio_limit = rl.rlim_cur;
    if (getrlimit(RLIMIT_MEMLOCK, &rl) == 0)
        info->memlock_limit = rl.rlim_cur;
    if (getrlimit(RLIMIT_NOFILE, &rl) == 0)
        info->nofile_limit = rl.rlim_cur;

    return 0;
}
```

---

### 4. Latency Measurement (Ping Statistics)

**Collection Method:** Raw ICMP socket + RDTSC (integrates with timing.h)

```c
// Uses existing timing.h infrastructure
#include "../core/timing.h"

typedef struct {
    uint64_t count;
    uint64_t min_ns;
    uint64_t max_ns;
    uint64_t sum_ns;
    uint64_t sum_sq_ns;  // For variance calculation

    // Percentiles
    uint64_t p50_ns;
    uint64_t p99_ns;
    uint64_t p999_ns;

    // Jitter (stddev)
    double stddev_ns;
    double mdev_ns;      // Mean deviation (ping format)
} ping_stats_t;

// Leverages existing latency_histogram_t from timing.h
int measure_ping_latency(const char *host, int count, ping_stats_t *stats) {
    latency_histogram_t hist;
    latency_histogram_init(&hist);

    int sock = socket(AF_INET, SOCK_RAW, IPPROTO_ICMP);
    if (sock < 0) return -1;

    // Set receive timeout
    struct timeval tv = {.tv_sec = 1, .tv_usec = 0};
    setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof(tv));

    for (int i = 0; i < count; i++) {
        // Use RDTSC for precise timing (from timing.h)
        uint64_t t1 = rdtsc_start();

        // Send ICMP echo request
        send_icmp_echo(sock, host, i);

        // Wait for reply
        if (recv_icmp_reply(sock) == 0) {
            uint64_t t2 = rdtsc_end();
            uint64_t rtt_ns = cycles_to_ns(t2 - t1);
            latency_histogram_record(&hist, rtt_ns);
        }
    }

    // Compute statistics
    stats->count = hist.count;
    stats->min_ns = hist.min_ns;
    stats->max_ns = hist.max_ns;
    stats->sum_ns = hist.sum_ns;
    stats->p50_ns = latency_histogram_percentile(&hist, 0.50);
    stats->p99_ns = latency_histogram_percentile(&hist, 0.99);
    stats->p999_ns = latency_histogram_percentile(&hist, 0.999);

    // Compute standard deviation
    double mean = latency_histogram_average(&hist);
    // stddev calculation...

    close(sock);
    return 0;
}
```

---

### 5. Hardware Performance Counters

**Collection Method:** perf_event_open() syscall

```c
#include <linux/perf_event.h>
#include <sys/syscall.h>

typedef struct CACHE_ALIGNED {
    uint64_t l1d_cache_misses;
    uint64_t l1d_cache_refs;
    double   l1d_miss_rate;

    uint64_t llc_cache_misses;
    uint64_t llc_cache_refs;
    double   llc_miss_rate;

    uint64_t branch_misses;
    uint64_t branch_refs;
    double   branch_miss_rate;

    uint64_t tlb_misses;
    uint64_t context_switches;
    uint64_t cpu_migrations;

    PAD_TO_CACHE_LINE(128);
} perf_counters_t;

static int perf_event_open(struct perf_event_attr *attr, pid_t pid,
                           int cpu, int group_fd, unsigned long flags) {
    return syscall(__NR_perf_event_open, attr, pid, cpu, group_fd, flags);
}

int perf_counters_start(int cpu, int *fds) {
    struct perf_event_attr pe = {0};
    pe.size = sizeof(pe);
    pe.disabled = 1;
    pe.exclude_kernel = 0;
    pe.exclude_hv = 0;

    // L1 data cache misses
    pe.type = PERF_TYPE_HW_CACHE;
    pe.config = PERF_COUNT_HW_CACHE_L1D |
                (PERF_COUNT_HW_CACHE_OP_READ << 8) |
                (PERF_COUNT_HW_CACHE_RESULT_MISS << 16);
    fds[0] = perf_event_open(&pe, -1, cpu, -1, 0);

    // LLC misses
    pe.config = PERF_COUNT_HW_CACHE_LL |
                (PERF_COUNT_HW_CACHE_OP_READ << 8) |
                (PERF_COUNT_HW_CACHE_RESULT_MISS << 16);
    fds[1] = perf_event_open(&pe, -1, cpu, -1, 0);

    // Branch misses
    pe.type = PERF_TYPE_HARDWARE;
    pe.config = PERF_COUNT_HW_BRANCH_MISSES;
    fds[2] = perf_event_open(&pe, -1, cpu, -1, 0);

    // Enable all counters
    for (int i = 0; i < 3; i++) {
        if (fds[i] >= 0) ioctl(fds[i], PERF_EVENT_IOC_ENABLE, 0);
    }

    return 0;
}
```

---

### 6. Memory Subsystem

**Collection Method:** /proc/vmstat + /proc/[pid]/stat + libnuma

```c
// src/diagnostics/memory_collector.h
typedef struct CACHE_ALIGNED {
    // Page faults
    uint64_t minor_faults;
    uint64_t major_faults;  // CRITICAL: Should be 0 during trading

    // NUMA topology
    int numa_node_count;
    struct {
        int node_id;
        uint64_t memory_total_mb;
        uint64_t memory_free_mb;
        int distance[8];  // Distance to other nodes
    } numa_nodes[8];

    // Current process NUMA binding
    int bound_node;
    uint64_t numa_local_allocs;
    uint64_t numa_remote_allocs;

    // THP status
    char thp_enabled[16];    // "always", "madvise", "never"
    char thp_defrag[16];     // "always", "defer", "never"

    // Huge pages
    uint64_t hugepages_total_2m;
    uint64_t hugepages_free_2m;
    uint64_t hugepages_total_1g;
    uint64_t hugepages_free_1g;

    PAD_TO_CACHE_LINE(256);
} memory_info_t;
```

---

### 7. Clock Source & Timing

**Collection Method:** /sys/devices/system/clocksource + chronyd stats

```c
typedef struct {
    char current_clocksource[32];   // "tsc", "kvm-clock", etc.
    char available_clocksources[128];

    // TSC characteristics
    uint64_t tsc_freq_hz;
    double tsc_drift_ppm;           // Parts per million drift

    // NTP synchronization
    double ntp_offset_us;
    double ntp_jitter_us;
    char ntp_source[64];

    // Spectre/Meltdown mitigations
    char spectre_v1[64];
    char spectre_v2[64];
    char meltdown[64];
} timing_info_t;
```

---

### 8-11. Network & TCP Metrics

**Collection Method:** /proc/net/snmp + /proc/net/netstat + socket options

```c
typedef struct {
    // TCP retransmissions
    uint64_t tcp_retrans_segs;
    uint64_t tcp_in_segs;
    double tcp_retrans_rate;

    // UDP errors
    uint64_t udp_rcv_buf_errors;
    uint64_t udp_snd_buf_errors;
    uint64_t udp_in_errors;

    // Softnet stats (per-CPU)
    uint64_t softnet_processed;
    uint64_t softnet_dropped;
    uint64_t softnet_time_squeeze;  // NAPI budget exhausted

    // TCP congestion
    char tcp_congestion_algo[32];
    int tcp_fastopen_enabled;
    int tcp_timestamps_enabled;

    // Connection limits
    uint64_t max_open_files;
    uint64_t socket_backlog_max;
} network_stats_t;
```

---

## Main Diagnostics Structure (Extends metrics_collector.h)

```c
// src/diagnostics/system_diagnostics.h
#ifndef DIAGNOSTICS_SYSTEM_DIAGNOSTICS_H
#define DIAGNOSTICS_SYSTEM_DIAGNOSTICS_H

#include "../core/types.h"
#include "../core/timing.h"
#include "../feedback/metrics_collector.h"

// Include all sub-collectors
#include "cpu_collector.h"
#include "network_collector.h"
#include "memory_collector.h"
#include "scheduler_collector.h"

typedef struct CACHE_ALIGNED {
    // Timestamp
    uint64_t collection_time_ns;

    // Sub-system diagnostics
    cpu_info_t cpu;
    nic_info_t nic;
    memory_info_t memory;
    scheduler_info_t scheduler;
    timing_info_t timing;
    network_stats_t network;
    perf_counters_t perf;
    ping_stats_t ping;

    // Validation results (against setup scripts)
    struct {
        int hugepages_configured : 1;
        int irqs_steered : 1;
        int cpu_isolated : 1;
        int thp_disabled : 1;
        int coalescing_off : 1;
        int rt_priority_available : 1;
    } validation;

    // Collection status
    int errors;
    char error_msg[256];
} system_diagnostics_t;

// Lifecycle
int system_diagnostics_init(system_diagnostics_t *diag);
int system_diagnostics_collect(system_diagnostics_t *diag, const char *nic_name);
void system_diagnostics_destroy(system_diagnostics_t *diag);

// Validation
int system_diagnostics_validate(const system_diagnostics_t *diag);
void system_diagnostics_print_warnings(const system_diagnostics_t *diag);

// Export
int system_diagnostics_to_json(const system_diagnostics_t *diag,
                               char *buf, size_t len);

// Continuous monitoring (daemon mode)
typedef struct {
    system_diagnostics_t current;
    latency_histogram_t latency_hist;
    int running;
    int sample_interval_ms;
} diagnostics_daemon_t;

int diagnostics_daemon_start(diagnostics_daemon_t *daemon, int interval_ms);
int diagnostics_daemon_stop(diagnostics_daemon_t *daemon);

#endif
```

---

## Makefile Integration

Add to existing Makefile:

```makefile
# Diagnostics source files
DIAG_SRC = $(SRCDIR)/diagnostics/system_diagnostics.c \
           $(SRCDIR)/diagnostics/cpu_collector.c \
           $(SRCDIR)/diagnostics/network_collector.c \
           $(SRCDIR)/diagnostics/memory_collector.c \
           $(SRCDIR)/diagnostics/scheduler_collector.c

DIAG_OBJ = $(BUILDDIR)/system_diagnostics.o \
           $(BUILDDIR)/cpu_collector.o \
           $(BUILDDIR)/network_collector.o \
           $(BUILDDIR)/memory_collector.o \
           $(BUILDDIR)/scheduler_collector.o

# Platform flags for diagnostics
DIAG_CFLAGS = -march=native -maes
ifeq ($(shell uname -s),Linux)
    DIAG_LDFLAGS = -lnuma
endif

# Diagnostics compile rules
$(BUILDDIR)/system_diagnostics.o: $(SRCDIR)/diagnostics/system_diagnostics.c
	$(CC) $(CFLAGS) $(DIAG_CFLAGS) -c -o $@ $<

$(BUILDDIR)/cpu_collector.o: $(SRCDIR)/diagnostics/cpu_collector.c
	$(CC) $(CFLAGS) $(DIAG_CFLAGS) -c -o $@ $<

# ... etc for other collectors

# Standalone diagnostic tool
$(BINDIR)/system_diag: $(DIAG_OBJ) $(SRCDIR)/diagnostics/main_diag.c
	$(CC) $(CFLAGS) $(DIAG_CFLAGS) -o $@ $^ $(LDFLAGS) $(DIAG_LDFLAGS)

# Run diagnostics
diagnose: $(BINDIR)/system_diag
	@echo "Running system diagnostics..."
	@sudo ./$(BINDIR)/system_diag
```

---

## Verification Steps

1. **Build the diagnostics module:**
   ```bash
   make diagnose
   ```

2. **Run one-time diagnostics:**
   ```bash
   sudo ./bin/system_diag --output json > diagnostics.json
   ```

3. **Validate setup scripts applied:**
   ```bash
   sudo ./bin/system_diag --validate
   ```

4. **Continuous monitoring:**
   ```bash
   sudo ./bin/system_diag --daemon --interval 100
   ```

5. **Cross-reference with perf:**
   ```bash
   perf stat -e cache-misses,branch-misses ./bin/trader testnet
   ```

---

## Critical Files to Create

| File | Purpose |
|------|---------|
| `src/diagnostics/system_diagnostics.h` | Main header, integrates with existing types.h |
| `src/diagnostics/system_diagnostics.c` | Orchestration and JSON export |
| `src/diagnostics/cpu_collector.c` | CPUID + MSR + steal time |
| `src/diagnostics/network_collector.c` | ethtool + IRQ affinity |
| `src/diagnostics/memory_collector.c` | NUMA + huge pages + THP |
| `src/diagnostics/scheduler_collector.c` | RT priority + tunables |
| `src/diagnostics/main_diag.c` | Standalone CLI tool |

---

## Privileges Required

Run diagnostics as root or with capabilities:
```bash
# Minimal capabilities for diagnostics
sudo setcap cap_sys_rawio,cap_net_raw,cap_perfmon+ep ./bin/system_diag
```

---

## Output Format (JSON)

```json
{
  "timestamp": "2026-01-16T12:00:00.000000000Z",
  "cpu": {
    "model": "AMD EPYC 7763 64-Core Processor",
    "caches": {"l1d": 32768, "l1i": 32768, "l2": 524288, "l3": 268435456},
    "features": {"avx2": true, "bmi2": true, "aesni": true, "constant_tsc": true},
    "steal_time_pct": 0.02,
    "tsc_freq_hz": 2450000000
  },
  "nic": {
    "driver": "virtio_net",
    "ring_buffers": {"rx": 256, "rx_max": 1024, "tx": 256, "tx_max": 1024},
    "coalescing": {"rx_usecs": 0, "tx_usecs": 0, "adaptive": false},
    "irq_affinity": [{"irq": 42, "cpus": [0, 1]}]
  },
  "memory": {
    "numa_nodes": 1,
    "page_faults": {"minor": 1234, "major": 0},
    "thp_enabled": "madvise",
    "hugepages_2m": {"total": 1024, "free": 512},
    "hugepages_1g": {"total": 2, "free": 2}
  },
  "scheduler": {
    "isolated_cpus": "2,3",
    "nohz_full": "2,3",
    "rt_priority_limit": 99,
    "memlock_limit": "unlimited"
  },
  "perf_counters": {
    "l1d_miss_rate": 0.02,
    "llc_miss_rate": 0.001,
    "branch_miss_rate": 0.005
  },
  "ping": {
    "target": "exchange-gateway.com",
    "mean_us": 450,
    "stddev_us": 12,
    "p99_us": 520,
    "p999_us": 890
  },
  "validation": {
    "hugepages_configured": true,
    "irqs_steered": true,
    "cpu_isolated": true,
    "thp_disabled": true,
    "coalescing_off": true,
    "rt_priority_available": true
  }
}
```

---

## Language: Pure C (as requested)

- All code uses C11 standard (`-std=c11`)
- Integrates with existing `types.h` macros (CACHE_ALIGNED, ALWAYS_INLINE, etc.)
- Uses existing `timing.h` for RDTSC/latency histograms
- Extends `metrics_collector.h` framework
- No external dependencies beyond libnuma (optional)
