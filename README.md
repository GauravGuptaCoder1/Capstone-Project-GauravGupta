# Mamaearth Growth Analytics Capstone

This repository builds a three-part analytics pipeline for Mamaearth's Growth Analytics team:

1. SQL relational store and reports
2. Python/Pandas cleaning, EDA, and visualizations
3. GenAI-powered SCR insight narrator with an offline fallback

Run the steps below from the repository root.

## 1. SQL Layer

Load the schema first, then seed the source data:

```sql
SOURCE sql/schema.sql;
SOURCE sql/seed_data.sql;
```

Then run the report queries:

```sql
SOURCE sql/reports.sql;
```

If you are using MySQL Workbench and Task i fails with safe update mode, temporarily disable it for that update:

```sql
SET SQL_SAFE_UPDATES = 0;
SOURCE sql/reports.sql;
SET SQL_SAFE_UPDATES = 1;
```

The SQL reports reproduce the raw total revenue of `99860.20`, zero-order customer checks, city return-rate analysis, category revenue, and loyalty-tier counts.

## 2. Python Analysis And Visualizations

Run the cleaning and EDA script:

```bash
python analysis/clean_and_eda.py
```

This script reads the raw CSV files in `data/`, standardizes payment method values, removes duplicate orders, imputes missing values, calculates cleaned revenue, flags quantity outliers, analyzes return risk, and builds the outlier-corrected monthly revenue view.

It also writes `narrator/findings.json` from the verified Part 2 numbers, including:

- cleaned total revenue: `97358.30`
- raw total revenue: `99860.20`
- duplicate reconciliation delta: `2501.90`
- COD return rate: `44.4`
- COD + Tier-2 return rate: `54.5`
- true peak month: March 2026 with revenue `20318.90`

Then generate the visualizations:

```bash
python analysis/visualize.py
```

This recreates:

- `visualizations/return_rate_by_payment.png`
- `visualizations/monthly_revenue_trend.png`

## 3. GenAI SCR Narrator

Run the narrator:

```bash
python narrator/generate_narrative.py
```

The script reads `narrator/findings.json`, generates a Situation-Complication-Resolution narrative, prints it, and runs a numeric accuracy checker.

To use Gemini, set a free Google AI Studio Gemini API key as an environment variable before running the script.

PowerShell:

```powershell
$env:GEMINI_API_KEY = "your-free-google-ai-studio-key"
python narrator/generate_narrative.py
```

macOS/Linux:

```bash
export GEMINI_API_KEY="your-free-google-ai-studio-key"
python narrator/generate_narrative.py
```

You can also use `GOOGLE_API_KEY` instead of `GEMINI_API_KEY`.

If no API key is configured, the script automatically uses the fully offline deterministic fallback. The offline path requires no network access, no API key, and no paid quota. It still produces the three SCR sections and checks that the required figures are present in the narrative.
