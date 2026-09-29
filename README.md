# edNewsTraderPro - Panduan Struktur & Konfigurasi

**edNewsTraderPro** adalah Expert Advisor (EA) MT5 berbasis event berita ekonomi (*economic calendar*) yang dibangun dengan arsitektur modular berorientasi objek (OOP).

---

## 1. Struktur Modul & Direktori

```
edNewsTraderPro/
├── setup.bat                 # Script instalasi & pemeriksa dependensi otomatis (1-klik)
├── setup.ps1                 # Engine PowerShell untuk setup, download MT5/Python, deploy & compile
├── edNewsTraderPro.mq5       # File orchestrator utama EA (OnInit, OnTick, OnTimer, OnDeinit)
├── edNewsTraderPro.ex5       # Binary hasil kompilasi siap pakai di MT5
│
├── Config/
│   └── Config.mqh                # Seluruh parameter input EA (mudah diubah & dikonfigurasi)
│
├── Core/
│   ├── Defines.mqh               # Definisi enum, struct data berita, dan konstanta
│   ├── Utils.mqh                 # Fungsi helper formatting, digit, pips, filter mata uang
│   └── Dashboard.mqh             # Tampilan HUD panel informasi di layar chart
│
├── News/
│   ├── INewsProvider.mqh         # Interface abstraksi sumber data berita
│   ├── MT5CalendarProvider.mqh   # Pembaca kalender ekonomi bawaan MT5 (native)
│   ├── ManualNewsProvider.mqh    # Pembaca jadwal berita manual (CSV/string timetable)
│   └── NewsManager.mqh           # Pengelola antrean event berita & sinkronisasi countdown
│
├── Strategy/
│   ├── IStrategy.mqh             # Interface standar strategi news
│   ├── StraddleStrategy.mqh      # Strategi 1: Pre-News Straddle Breakout (Pending Buy/Sell Stop + OCO)
│   ├── PostBreakoutStrategy.mqh  # Strategi 2: Post-News Candle Breakout (M1/M5 High/Low)
│   └── StrategyManager.mqh       # Pengelola aktivasi dan delegasi eksekusi strategi
│
└── Execution/
    ├── OrderManager.mqh          # Eksekusi Buy Stop, Sell Stop, OCO auto-cancel, auto-expiration
    ├── RiskManager.mqh           # Proteksi Max Spread, kalkulasi lot risiko dinamis
    └── TrailingManager.mqh       # Breakeven (BEP) dan Trailing Stop otomatis
```

---

## 2. Cara Mengembangkan Modul Baru

### Menambah Strategi Baru (Misal: *News Fade / Retracement*)
1. Buat file baru di dalam folder `Strategy/`, misal `Strategy/NewsFadeStrategy.mqh`.
2. Implementasikan class turunan dari `IStrategy`:
   ```cpp
   #include "IStrategy.mqh"

   class CNewsFadeStrategy : public IStrategy
   {
   public:
      virtual bool Init(...) override { ... }
      virtual void OnTimerUpdate(...) override { ... }
      virtual void OnTickUpdate() override { ... }
      virtual void OnDeinit() override { ... }
   };
   ```
3. Daftarkan di `StrategyManager.mqh` dan tambahkan opsi di `Defines.mqh` (`ENUM_STRATEGY_TYPE`).

### Menambah Sumber Berita Baru (Misal: External WebRequest JSON)
1. Buat class turunan dari `INewsProvider` di dalam folder `News/`.
2. Implementasikan fungsi `FetchUpcomingNews(...)`.

---

## 3. Rekomendasi Pengaturan Preset per Pasangan Mata Uang

### A. EURUSD (Likuiditas Tinggi & Spread Ketat)
* **Strategy Type**: `STRAT_BOTH_COMBINED` atau `STRAT_STRADDLE_ONLY`
* **Straddle Lead Sec**: `60` – `90` detik
* **Straddle Distance**: `150` – `200` points (15 - 20 pips)
* **Max Spread**: `30` – `35` points (3 - 3.5 pips)
* **SL / TP**: `200` / `400` points
* **Breakeven**: Trigger `150` pts, Lock `30` pts

### B. GBPUSD (Volatilitas Tinggi & Rawan Whipsaw Dua Arah)
* **Strategy Type**: `STRAT_POST_BREAKOUT_ONLY` (Sangat disarankan)
* **Post-News Wait Sec**: `60` – `120` detik (menunggu candle rilis selesai)
* **Post-News Candle TF**: `PERIOD_M1`
* **Buffer Pts**: `50` – `100` points
* **Max Spread**: `40` – `50` points
* **SL / TP**: `300` / `600` points

### C. USDJPY (Tren Satu Arah & Responsif terhadap US Yields)
* **Strategy Type**: `STRAT_STRADDLE_ONLY`
* **Straddle Lead Sec**: `60` – `90` detik
* **Straddle Distance**: `150` – `250` points
* **OCO**: `true`
* **Trailing Stop**: Aktif (`InpTrailPts`: 150 pts, `InpTrailStepPts`: 50 pts)
* **Max Spread**: `35` points

### D. XAUUSD / Gold (Wild Volatility & Spread Spike Ekstrem)
* **Strategy Type**: **STRICTLY `STRAT_POST_BREAKOUT_ONLY`** *(Jangan gunakan Straddle sebelum rilis di Gold karena spread bisa melebar hingga 150-300 points dan memicu double stop out)*.
* **Post-News Wait Sec**: `120` – `180` detik (tunggu 2-3 menit hingga spread kembali ke $0.20 - $0.50).
* **Buffer Pts**: `100` – `200` points ($1.00 - $2.00 di atas High / di bawah Low candle rilis).
* **Max Spread**: `60` – `80` points
* **SL / TP**: SL `400` – `600` pts ($4 - $6) / TP `800` – `1500` pts ($8 - $15)
* **Breakeven**: Trigger `250` pts, Lock `50` pts

---

## 4. Otomasi Setup & Pemeriksaan Dependensi (`setup.bat`)

File `setup.bat` disediakan untuk memudahkan instalasi, validasi dependensi, dan deployment 1-klik ke MetaTrader 5:

### Fitur Otomatis `setup.bat`:
1. **Pemeriksaan MetaTrader 5**:
   - Mendeteksi `terminal64.exe` dan `metaeditor64.exe` di direktori program dan AppData.
   - Jika MT5 belum terpasang, script menawarkan opsi **auto-download installer resmi MT5 (`mt5setup.exe`)** langsung dari server MetaQuotes CDN dan menjalankan proses instalasi.
2. **Pemeriksaan Python 3**:
   - Mengecek ketersediaan Python di PATH sistem.
   - Jika Python belum terpasang, script menawarkan download installer Python 3 (dengan opsi otomatis menambahkan ke PATH).
3. **Penyusunan Data Kalender Berita**:
   - Memastikan file `news_calendar_3years.csv` tersedia (menjalankan generator otomatis jika belum ada).
4. **Sinkronisasi File ke Direktori Data MT5**:
   - Menyalin modul EA ke `%APPDATA%\MetaQuotes\Terminal\<Hash>\MQL5\Experts\edNewsTraderPro`.
   - Menyalin file kalender berita CSV ke `%APPDATA%\MetaQuotes\Terminal\Common\Files` dan `MQL5\Files`.
5. **Kompilasi Otomatis (MetaEditor)**:
   - Mengompilasi `edNewsTraderPro.mq5` menjadi `edNewsTraderPro.ex5` dan memastikan 0 error / warning.
6. **Menu Peluncur Interaktif**:
   - Opsi menjalankan Strategy Tester langsung (backtest EURUSD), membuka terminal MT5, atau membuka MetaEditor.

### Cara Penggunaan:
* **Mode Interaktif (Double Click)**: Cukup klik ganda file `setup.bat` di File Explorer.
* **Cek Dependensi Saja**: `setup.bat -CheckOnly`
* **Auto-Install Tanpa Konfirmasi**: `setup.bat -AutoInstall`

