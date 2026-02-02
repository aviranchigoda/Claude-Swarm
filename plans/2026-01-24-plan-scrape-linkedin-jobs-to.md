# Plan: Scrape LinkedIn Jobs to CSV

## Overview
Scrape ~500 software job listings from LinkedIn's public job search page and export to CSV format.

## Configuration
- **Target**: First 500 job listings
- **Browser**: Chrome (headless mode)

## Important Considerations
- LinkedIn has anti-scraping measures (rate limiting, IP blocking, CAPTCHAs)
- Their Terms of Service prohibit automated scraping
- Public job listings page shows limited data without authentication
- The page uses JavaScript rendering, requiring browser automation

## Recommended Approach: Selenium + BeautifulSoup with Chrome

### Files to Create
- `linkedin_scraper.py` - Main scraping script
- `requirements.txt` - Dependencies

### Implementation Steps

1. **Set up dependencies**
   - selenium (browser automation)
   - beautifulsoup4 (HTML parsing)
   - pandas (CSV export)
   - webdriver-manager (Chrome driver management)

2. **Create scraper script**
   - Initialize headless Chrome browser
   - Navigate to the LinkedIn jobs URL
   - Scroll to load more jobs (infinite scroll pagination)
   - Extract job cards: title, company, location, date posted, job URL
   - Handle rate limiting with delays between requests
   - Save results to CSV

3. **Data fields to extract**
   - Job Title
   - Company Name
   - Location
   - Date Posted
   - Job URL
   - Job Description (if accessible)

### Verification
- Run the script and check CSV output
- Verify data integrity and completeness

## Alternative Options
1. **LinkedIn Jobs API** - Requires LinkedIn developer account approval (restrictive)
2. **Manual export** - Copy/paste visible listings (tedious but guaranteed to work)
3. **Third-party services** - Apify, Phantombuster (paid, handle anti-bot measures)
