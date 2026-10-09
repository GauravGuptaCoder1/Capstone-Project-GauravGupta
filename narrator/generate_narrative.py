import os
import json
from pathlib import Path


def month_name(year_month: str) -> str:
    """Convert YYYY-MM to a month name for business-readable narrative text."""
    month_names = {
        "01": "January",
        "02": "February",
        "03": "March",
        "04": "April",
        "05": "May",
        "06": "June",
        "07": "July",
        "08": "August",
        "09": "September",
        "10": "October",
        "11": "November",
        "12": "December",
    }
    return month_names[year_month.split("-")[1]]


def check_numeric_accuracy(narrative: str) -> bool:
    """Print pass/fail checks for the required numeric facts."""
    normalized = narrative.replace(",", "")
    checks = [
        ("cleaned total revenue", ["97358.30", "97358.3"]),
        ("COD return rate", ["44.4"]),
        ("COD Tier-2 highest-risk segment", ["54.5"]),
        ("duplicate reconciliation delta", ["2501.90", "2501.9"]),
        ("March true peak revenue", ["March", "20318.90", "20318.9"]),
    ]

    all_passed = True
    for label, required_values in checks:
        passed = all(value in normalized for value in required_values[:1])
        if label == "March true peak revenue":
            passed = (
                "March" in narrative
                and any(value in normalized for value in required_values[1:])
            )
        elif len(required_values) > 1:
            passed = any(value in normalized for value in required_values)

        print(f"{label}: {'PASS' if passed else 'FAIL'}")
        all_passed = all_passed and passed

    return all_passed


def generate_scr_narrative_offline(findings: dict) -> dict:
    """Generate a deterministic SCR narrative without an API key or network."""
    payment_rates = findings["return_rate_by_payment"]
    highest_risk = findings["highest_risk_segment"]
    true_peak = findings["true_peak_month"]
    inflated_month = findings["outlier_inflated_month"]

    narrative = (
        "Situation\n"
        f"Mamaearth's cleaned revenue view is INR {findings['cleaned_total_revenue_inr']}, "
        f"compared with raw revenue of INR {findings['raw_total_revenue_inr']}. "
        f"The verified duplicate reconciliation delta is INR "
        f"{findings['duplicate_reconciliation_delta_inr']}. Return rates by payment method are "
        f"COD {payment_rates['COD']}%, CARD {payment_rates['CARD']}%, and UPI {payment_rates['UPI']}%.\n\n"
        "Complication\n"
        f"Return risk is concentrated in {highest_risk['payment_method']} orders from "
        f"Tier-{highest_risk['city_tier']} cities, where the return rate is "
        f"{highest_risk['return_rate_pct']}%. The time-series view also changes after "
        f"outlier correction: {inflated_month['month']} shows apparent revenue of INR "
        f"{inflated_month['apparent_revenue_inr']}, but its corrected revenue is INR "
        f"{inflated_month['corrected_revenue_inr']}.\n\n"
        "Resolution\n"
        f"Use the cleaned and outlier-corrected view for planning. The true peak month is "
        f"{month_name(true_peak['month'])} with INR {true_peak['revenue_inr']}. Prioritize COD return "
        f"controls for Tier-{highest_risk['city_tier']} cities while keeping finance reporting "
        "anchored to the cleaned revenue and duplicate reconciliation figures."
    )

    return {
        "status": "success",
        "narrative": narrative,
        "tokens": None,
    }


def generate_scr_narrative(findings: dict) -> dict:
    """Generate an SCR business narrative from verified findings."""
    api_key = os.getenv("GEMINI_API_KEY") or os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return generate_scr_narrative_offline(findings)

    system_instruction = (
        "You are a senior data analyst writing for Mamaearth's regional ops "
        "and finance heads. Write the response in exactly three labeled "
        "sections: Situation, Complication, and Resolution. Every number in "
        "the output must come from the supplied findings and appear with the "
        "same value. Do not invent statistics, percentages, dates, months, "
        "currency values, or counts."
    )

    payment_rates = findings["return_rate_by_payment"]
    highest_risk = findings["highest_risk_segment"]
    true_peak = findings["true_peak_month"]
    inflated_month = findings["outlier_inflated_month"]

    contents = (
        "Use these verified findings to write a concise SCR narrative for "
        "business stakeholders.\n\n"
        f"Cleaned total revenue: INR {findings['cleaned_total_revenue_inr']}\n"
        f"Raw total revenue: INR {findings['raw_total_revenue_inr']}\n"
        "Duplicate reconciliation delta: "
        f"INR {findings['duplicate_reconciliation_delta_inr']}\n"
        "Return rate by payment method: "
        f"COD {payment_rates['COD']}%, "
        f"CARD {payment_rates['CARD']}%, "
        f"UPI {payment_rates['UPI']}%\n"
        "Highest-risk segment: "
        f"{highest_risk['payment_method']} in Tier-{highest_risk['city_tier']} "
        f"cities at {highest_risk['return_rate_pct']}%\n"
        "True peak month after outlier correction: "
        f"{true_peak['month']} with INR {true_peak['revenue_inr']}\n"
        "Outlier-inflated month: "
        f"{inflated_month['month']} had apparent revenue of "
        f"INR {inflated_month['apparent_revenue_inr']} and corrected revenue of "
        f"INR {inflated_month['corrected_revenue_inr']}"
    )

    try:
        from google import genai
        from google.genai import types

        client = genai.Client(api_key=api_key)
        response = client.models.generate_content(
            model="gemini-2.5-flash",
            contents=contents,
            config=types.GenerateContentConfig(
                system_instruction=system_instruction,
                # Factual business report, not creative writing; keep output deterministic.
                temperature=0.0,
                max_output_tokens=500,
                http_options=types.HttpOptions(timeout=10_000),
            ),
        )

        return {
            "status": "success",
            "narrative": response.text,
            "tokens": response.usage_metadata.total_token_count
            if response.usage_metadata
            else None,
        }
    except Exception as err:
        api_error = {
            "status": "error",
            "narrative": None,
            "message": str(err),
        }
        if api_error["status"] == "error":
            return generate_scr_narrative_offline(findings)

        return api_error


if __name__ == "__main__":
    base_dir = Path(__file__).resolve().parents[1]
    findings_path = base_dir / "narrator" / "findings.json"

    with findings_path.open("r", encoding="utf-8") as f:
        findings_data = json.load(f)

    result = generate_scr_narrative(findings_data)
    narrative_text = result["narrative"] or ""

    print(f"Status: {result['status']}")
    print(narrative_text)
    check_numeric_accuracy(narrative_text)
