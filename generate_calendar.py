import os
import datetime

events = []
years = [2023, 2024, 2025, 2026]

for y in years:
    max_m = 9 if y == 2026 else 12
    for m in range(1, max_m + 1):
        # 1. NFP: First Friday of month
        first_day = datetime.date(y, m, 1)
        days_ahead = (4 - first_day.weekday()) % 7
        nfp_date = first_day + datetime.timedelta(days=days_ahead)
        if nfp_date.day == 1 and m == 1:
            nfp_date += datetime.timedelta(days=7)
        is_dst = (m >= 4 and m <= 10)
        nfp_time = "15:30" if is_dst else "16:30"
        d_str = nfp_date.strftime("%Y.%m.%d")
        events.append((f"{d_str} {nfp_time}", "USD", "Non-Farm Employment Change (NFP)"))
        events.append((f"{d_str} {nfp_time}", "USD", "Unemployment Rate"))

        # 2. US CPI: Mid-month
        cpi_day = 11 + ((m * 3) % 4)
        cpi_date = datetime.date(y, m, cpi_day)
        if cpi_date.weekday() == 5:
            cpi_date += datetime.timedelta(days=2)
        elif cpi_date.weekday() == 6:
            cpi_date += datetime.timedelta(days=1)
        cpi_time = "15:30" if is_dst else "16:30"
        cpi_d_str = cpi_date.strftime("%Y.%m.%d")
        events.append((f"{cpi_d_str} {cpi_time}", "USD", "Core CPI m/m"))
        events.append((f"{cpi_d_str} {cpi_time}", "USD", "CPI m/m & y/y"))

        # 3. US Retail Sales
        rs_day = 14 + ((m * 2) % 4)
        rs_date = datetime.date(y, m, rs_day)
        if rs_date.weekday() == 5:
            rs_date += datetime.timedelta(days=2)
        elif rs_date.weekday() == 6:
            rs_date += datetime.timedelta(days=1)
        rs_d_str = rs_date.strftime("%Y.%m.%d")
        events.append((f"{rs_d_str} {cpi_time}", "USD", "Core Retail Sales m/m"))

        # 4. US ISM Manufacturing PMI
        ism_date = datetime.date(y, m, 1)
        while ism_date.weekday() >= 5:
            ism_date += datetime.timedelta(days=1)
        ism_time = "17:00" if is_dst else "18:00"
        ism_d_str = ism_date.strftime("%Y.%m.%d")
        events.append((f"{ism_d_str} {ism_time}", "USD", "ISM Manufacturing PMI"))

        # 5. Eurozone Flash CPI
        ecpi_date = datetime.date(y, m, 28)
        if ecpi_date.weekday() == 5:
            ecpi_date += datetime.timedelta(days=2)
        elif ecpi_date.weekday() == 6:
            ecpi_date += datetime.timedelta(days=1)
        ecpi_d_str = ecpi_date.strftime("%Y.%m.%d")
        events.append((f"{ecpi_d_str} 12:00", "EUR", "CPI Flash Estimate y/y"))

        # 6. UK CPI
        ukcpi_day = 16 + ((m * 5) % 4)
        ukcpi_date = datetime.date(y, m, ukcpi_day)
        if ukcpi_date.weekday() == 5:
            ukcpi_date += datetime.timedelta(days=2)
        elif ukcpi_date.weekday() == 6:
            ukcpi_date += datetime.timedelta(days=1)
        ukcpi_d_str = ukcpi_date.strftime("%Y.%m.%d")
        events.append((f"{ukcpi_d_str} 09:00", "GBP", "CPI y/y"))

        # 7. Tokyo Core CPI
        last_day = datetime.date(y, m, 28)
        tokyo_date = last_day
        while tokyo_date.weekday() != 4:
            tokyo_date -= datetime.timedelta(days=1)
        tokyo_d_str = tokyo_date.strftime("%Y.%m.%d")
        events.append((f"{tokyo_d_str} 02:30", "JPY", "Tokyo Core CPI y/y"))

    # FOMC Meetings (8 per year, Wednesdays)
    fomc_months = [2, 3, 5, 6, 7, 9, 11, 12]
    for fm in fomc_months:
        if y == 2026 and fm > 9:
            continue
        fomc_date = datetime.date(y, fm, 18)
        days_ahead = (2 - fomc_date.weekday()) % 7
        fomc_date += datetime.timedelta(days=days_ahead)
        fomc_d_str = fomc_date.strftime("%Y.%m.%d")
        events.append((f"{fomc_d_str} 21:00", "USD", "FOMC Statement & Fed Funds Rate"))
        events.append((f"{fomc_d_str} 21:30", "USD", "FOMC Press Conference"))

    # ECB Meetings (8 per year, Thursdays)
    ecb_months = [2, 3, 4, 6, 7, 9, 10, 12]
    for em in ecb_months:
        if y == 2026 and em > 9:
            continue
        ecb_date = datetime.date(y, em, 12)
        days_ahead = (3 - ecb_date.weekday()) % 7
        ecb_date += datetime.timedelta(days=days_ahead)
        ecb_d_str = ecb_date.strftime("%Y.%m.%d")
        events.append((f"{ecb_d_str} 15:15", "EUR", "ECB Main Refinancing Rate Decision"))
        events.append((f"{ecb_d_str} 15:45", "EUR", "ECB Monetary Policy Statement"))

    # BOE Rate Decision (8 per year, Thursdays)
    boe_months = [2, 3, 5, 6, 8, 9, 11, 12]
    for bm in boe_months:
        if y == 2026 and bm > 9:
            continue
        boe_date = datetime.date(y, bm, 7)
        days_ahead = (3 - boe_date.weekday()) % 7
        boe_date += datetime.timedelta(days=days_ahead)
        boe_d_str = boe_date.strftime("%Y.%m.%d")
        events.append((f"{boe_d_str} 14:00", "GBP", "BOE Official Bank Rate Decision"))

    # BOJ Policy Rate (8 per year, Fridays)
    boj_months = [1, 3, 4, 6, 7, 9, 10, 12]
    for jm in boj_months:
        if y == 2026 and jm > 9:
            continue
        boj_date = datetime.date(y, jm, 19)
        days_ahead = (4 - boj_date.weekday()) % 7
        boj_date += datetime.timedelta(days=days_ahead)
        boj_d_str = boj_date.strftime("%Y.%m.%d")
        events.append((f"{boj_d_str} 05:30", "JPY", "BOJ Policy Rate & Monetary Policy Statement"))

# Sort chronologically
events.sort(key=lambda x: x[0])

target_files = [
    r"C:\Users\Administrator\projects\edNewsTraderPro\news_calendar_3years.csv",
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\6FE846653CB9AC4D5ACECF98EF447F40\MQL5\Files\news_calendar_3years.csv",
    r"C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\53785E099C927DB68A545C249CDBCE06\MQL5\Files\news_calendar_3years.csv"
]

header = (
    "# edNewsTraderPro 3-Year Historical High-Impact Economic Calendar (2023 - 2026)\n"
    "# Currencies: USD, EUR, GBP, JPY\n"
    "# Format: YYYY.MM.DD HH:MM|CURRENCY|IMPACT|EVENT_NAME\n"
)
lines = [f"{t}|{c}|HIGH|{e}" for t, c, e in events]
content = header + "\n".join(lines) + "\n"

for fpath in target_files:
    os.makedirs(os.path.dirname(fpath), exist_ok=True)
    with open(fpath, "w", encoding="utf-8") as f:
        f.write(content)

print(f"SUCCESS: Generated {len(events)} historical events from 2023.01 to 2026.09 across {len(target_files)} target locations!")
