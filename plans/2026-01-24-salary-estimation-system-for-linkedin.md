# Salary Estimation System for LinkedIn Jobs

## Problem Statement
The linkedin_jobs.csv contains 400 job listings from Australia, with **0% salary disclosure** (all entries show "N/A"). We need a smart engineering solution to estimate/predict salaries.

## User Requirements
- **Approach:** Multi-Source Hybrid (Levels.fyi + Glassdoor + Seek + Claude LLM)
- **Priority:** Accuracy over speed/cost
- **Available APIs:** Anthropic Claude API

## Recommended Solution: Multi-Source Salary Intelligence Pipeline

A hybrid system that combines multiple data sources and AI to produce accurate salary estimates with confidence scores.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    SALARY ESTIMATION PIPELINE                    │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  linkedin_jobs.csv ──► Title/Company Parser ──► Feature Extractor│
│                              │                                   │
│              ┌───────────────┼───────────────┐                  │
│              ▼               ▼               ▼                  │
│      ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│      │ API Lookups  │ │  Web Scraper │ │ LLM Estimator│        │
│      │ (Levels.fyi, │ │  (Glassdoor, │ │  (Claude/GPT │        │
│      │  Glassdoor)  │ │   Seek)      │ │   Analysis)  │        │
│      └──────┬───────┘ └──────┬───────┘ └──────┬───────┘        │
│             │                │                │                 │
│             └────────────────┼────────────────┘                 │
│                              ▼                                  │
│                    ┌──────────────────┐                         │
│                    │  Salary Ensemble │                         │
│                    │  (Weighted Avg + │                         │
│                    │   Confidence)    │                         │
│                    └────────┬─────────┘                         │
│                             ▼                                   │
│                   Enriched CSV Output                           │
│                   (salary_min, salary_max,                      │
│                    salary_estimate, confidence,                 │
│                    data_sources)                                │
└─────────────────────────────────────────────────────────────────┘
```

---

## Implementation Plan

### Phase 1: Core Infrastructure

#### 1.1 Create Project Structure
```
linkedin/
├── salary_estimator/
│   ├── __init__.py
│   ├── main.py                 # Entry point
│   ├── config.py               # API keys, settings
│   ├── parsers/
│   │   ├── title_parser.py     # Extract seniority, role type
│   │   └── location_parser.py  # Normalize AU locations
│   ├── sources/
│   │   ├── base.py             # Abstract source interface
│   │   ├── levelsfyi.py        # Levels.fyi API/scraper
│   │   ├── glassdoor.py        # Glassdoor API
│   │   ├── seek.py             # Seek salary data
│   │   └── llm_estimator.py    # Claude/GPT-based estimation
│   ├── models/
│   │   └── ensemble.py         # Combine estimates
│   └── utils/
│       ├── cache.py            # Cache API responses
│       └── currency.py         # AUD normalization
├── data/
│   ├── linkedin_jobs.csv       # Input
│   ├── enriched_jobs.csv       # Output
│   └── salary_cache.json       # Cached lookups
└── requirements.txt
```

#### 1.2 Title Parser (Critical for accuracy)
Extract structured data from job titles:
```python
# Input: "Senior Software Engineer - Azure Portal"
# Output: {
#   "seniority": "senior",        # junior/mid/senior/staff/principal
#   "role_family": "engineering", # engineering/sales/management/support
#   "specialization": "backend",  # frontend/backend/fullstack/devops
#   "keywords": ["azure", "portal"]
# }
```

### Phase 2: Data Source Integrations

#### 2.1 Levels.fyi Integration (Best for tech)
- Use unofficial API or web scraping
- Excellent data for: Microsoft, Atlassian, Canonical, Google, Meta
- Returns: TC (total comp), base salary, stock, bonus by level

#### 2.2 Glassdoor Integration
- Official API (requires partnership) OR scraping
- Broad coverage across all company types
- Returns: salary ranges by title/location

#### 2.3 Seek.com.au Scraping (Best for AU market)
- Scrape salary insights from job search
- Australian-specific data
- Strong for local companies (UpGuard, Employment Hero, etc.)

#### 2.4 LLM-Based Estimator (Fallback + Enhancement)
```python
def estimate_with_llm(job: dict) -> SalaryEstimate:
    prompt = f"""
    Estimate the annual salary range (AUD) for this Australian job:

    Title: {job['title']}
    Company: {job['company']}
    Location: {job['location']}

    Consider:
    1. Company compensation tier (FAANG-level, startup, enterprise)
    2. Role seniority extracted from title
    3. Australian tech market rates (2025-2026)
    4. Location cost of living (Sydney > Melbourne > Brisbane)

    Return JSON: {{"min": X, "max": Y, "median": Z, "confidence": 0.0-1.0}}
    """
    # Call Claude API
```

### Phase 3: Ensemble & Output

#### 3.1 Salary Ensemble Logic
```python
def combine_estimates(sources: list[SalaryEstimate]) -> FinalEstimate:
    # Weight by source reliability
    weights = {
        "levelsfyi": 0.35,   # Highest accuracy for tech
        "glassdoor": 0.25,
        "seek": 0.25,
        "llm": 0.15          # Fallback/supplement
    }

    # Calculate weighted average
    # Compute confidence based on source agreement
    # Return range + point estimate
```

#### 3.2 Output Format
Enrich original CSV with:
| Column | Description |
|--------|-------------|
| salary_min | Lower bound (AUD) |
| salary_max | Upper bound (AUD) |
| salary_estimate | Point estimate (median) |
| confidence | 0.0-1.0 based on data quality |
| data_sources | Which sources contributed |
| last_updated | Timestamp of estimate |

---

## Key Engineering Decisions

### 1. Caching Strategy
- Cache all API/scrape results for 30 days
- Key by: `{company}:{normalized_title}:{location}`
- Reduces API costs and improves speed

### 2. Rate Limiting
- Implement exponential backoff for all scrapers
- Use rotating proxies for Glassdoor/Seek (if scraping)
- Batch requests where possible

### 3. Confidence Scoring
```
High (0.8-1.0): Multiple sources agree within 10%
Medium (0.5-0.8): Fewer sources or 20% variance
Low (0.0-0.5): Only LLM estimate or high variance
```

### 4. Company Tier Classification
Pre-classify companies to improve estimates:
```python
COMPANY_TIERS = {
    "tier1_faang": ["Microsoft", "Google", "Meta", "Amazon"],
    "tier2_unicorn": ["Atlassian", "Canva", "Afterpay"],
    "tier3_established": ["Canonical", "Red Hat", "Shopify"],
    "tier4_startup": ["Leonardo.Ai", "Heidi", "Traild"],
    "tier5_local": ["Employment Hero", "Karbon"]
}
```

---

## Files to Create/Modify

| File | Action |
|------|--------|
| `salary_estimator/main.py` | Create - orchestration |
| `salary_estimator/parsers/title_parser.py` | Create - NLP title parsing |
| `salary_estimator/sources/levelsfyi.py` | Create - levels.fyi integration |
| `salary_estimator/sources/glassdoor.py` | Create - glassdoor integration |
| `salary_estimator/sources/seek.py` | Create - seek.com.au scraper |
| `salary_estimator/sources/llm_estimator.py` | Create - Claude/GPT fallback |
| `salary_estimator/models/ensemble.py` | Create - combine estimates |
| `requirements.txt` | Create - dependencies |

---

## Verification Plan

1. **Unit tests** for title parser (test seniority extraction)
2. **Integration tests** for each data source
3. **Spot check** 20 random jobs against manual research
4. **Benchmark** against known salaries (e.g., Glassdoor public data)
5. **Run on full dataset** and validate confidence distribution

---

## Dependencies

```
requests>=2.31.0
beautifulsoup4>=4.12.0
anthropic>=0.18.0  # For Claude API
pandas>=2.0.0
pydantic>=2.0.0
aiohttp>=3.9.0     # Async requests
tenacity>=8.2.0    # Retry logic
diskcache>=5.6.0   # Persistent caching
```

---

## Expected Output Sample

```csv
title,company,location,salary,salary_min,salary_max,salary_estimate,confidence,data_sources
Software Engineer,Microsoft,Australia,N/A,160000,220000,185000,0.92,levelsfyi|glassdoor
Senior Software Engineer,Atlassian,Sydney,N/A,180000,260000,215000,0.88,levelsfyi|glassdoor|seek
Junior Frontend Engineer,Karbon,Melbourne,N/A,85000,110000,95000,0.72,glassdoor|llm
```

---

## Alternative Approaches Considered

1. **Pure ML Model** - Rejected: requires large training dataset we don't have
2. **Single API Source** - Rejected: coverage gaps for smaller companies
3. **Manual Research** - Rejected: doesn't scale to 400+ jobs
4. **Crowdsourcing** - Rejected: slow, expensive, unreliable

The hybrid multi-source approach provides the best balance of accuracy, coverage, and scalability.
