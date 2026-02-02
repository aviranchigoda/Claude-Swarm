# LinkedIn Job Scraper - Salary Extraction & Sorting Plan

## User Request
Scrape 416 jobs from LinkedIn URL and filter by highest to lowest salary.

**URL:** https://www.linkedin.com/jobs/search/?currentJobId=4362502592&f_JT=F&f_WT=2&geoId=101452733&keywords=software&origin=JOB_SEARCH_PAGE_JOB_FILTER&refresh=true&sortBy=R&spellCorrectionEnabled=true

## Current Issues
1. Script does not extract salary information from job listings
2. No sorting functionality exists
3. TARGET_JOBS is set to 500 (should be 416)

## Implementation Plan

### Step 1: Modify Script Configuration
- Change `TARGET_JOBS = 500` to `TARGET_JOBS = 416`

### Step 2: Add Salary Extraction
- Add salary parsing in `parse_job_cards()` function
- LinkedIn salary info typically appears in elements with class `job-search-card__salary-info`
- Add 'salary' field to job dictionary

### Step 3: Add Salary Parsing Function
- Create `parse_salary_to_number()` function to convert salary strings (e.g., "$150,000 - $180,000") to a comparable numeric value (use midpoint or max)
- Handle various formats: ranges, hourly, yearly, "K" notation

### Step 4: Add Sorting by Salary
- After collecting all jobs, sort by parsed salary value (highest first)
- Jobs without salary info (N/A) appear at the bottom after all salaried jobs
- Include all jobs regardless of salary availability

### Step 5: Update CSV Output
- Add 'salary' column to CSV fieldnames

### Step 6: Run the Script
- Execute: `python3 linkedin_scraper.py`
- Output: `linkedin_jobs.csv` sorted by salary (highest to lowest)

## Files to Modify
- `/home/ai_dev/linkedin_scraper.py`

## Verification
- Run the script and verify CSV output contains salary column
- Confirm jobs are sorted from highest to lowest salary
- Verify ~416 jobs are captured
