# TIMMY MT5 AUTO BOT — Android-first starter

This is a deployable **starter project**, not a finished or independently validated trading product.
It includes:
- Mobile-first PWA-style dashboard (installable from Android Chrome)
- FastAPI backend with registration/login and a SQLite user store
- Strategy preference endpoints
- An MT5 Expert Advisor starter (`mt5-ea/TimmyAutoBot.mq5`) designed to run on MT5 desktop/VPS
- Demo-first risk controls and deployment notes

## Important architecture
The Android app is the control panel. The MT5 EA must run on a Windows computer or Windows VPS with MetaTrader 5 installed and logged into the user's broker account. The Android MT5 app does not host desktop Expert Advisors.

## Current implementation status
- Frontend: working demo UI; authentication screens call the API when configured.
- Backend: working basic auth and strategy-preference API.
- MT5 EA: starter example with EMA/RSI signal logic and protective controls; requires MetaEditor compilation, broker-specific symbol testing, and extensive demo validation.
- Not included: production payment processing, verified identity/KYC, production-grade multi-tenant secrets management, broker certification, a tested AI model, or guaranteed profitability.

## Run locally
Requires Python 3.11+.

```bash
cd backend
python -m venv .venv
# Windows: .venv\Scripts\activate
# macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8000
```

Open `frontend/index.html` in a browser. Set `API_BASE` near the top of `frontend/app.js` to your deployed API URL (or `http://127.0.0.1:8000` for local testing).

For Android installation, deploy the frontend over HTTPS, open it in Chrome on Android, then use Chrome menu → Add to Home screen / Install app.

## MT5 EA installation (Windows/VPS required)
1. Install MT5 from your broker and log in to a **demo account**.
2. In MT5: File → Open Data Folder → MQL5 → Experts.
3. Copy `TimmyAutoBot.mq5` into Experts and open it in MetaEditor.
4. Compile; resolve any broker/build-specific warnings.
5. Attach to a demo chart, enable Algo Trading, and test in Strategy Tester.
6. For WebRequest integration later, add your HTTPS API host under Tools → Options → Expert Advisors → Allow WebRequest.

The included EA is deliberately demo-only by default. Do not switch it to a live account until independent code review, broker-specific testing, and risk review are complete.

## Security before public launch
- Replace the development JWT secret with a strong secret from a secret manager.
- Use HTTPS everywhere.
- Use PostgreSQL, migrations, backups, rate limits, email verification, password reset, MFA, audit logs, and secure session handling.
- Never collect broker passwords in this website. Users should enter broker credentials only in their trusted MT5 terminal/VPS.
- Add per-account device/API credentials, rotation and revocation before connecting real EAs.
- Integrate a compliant payment provider only after legal and operational review.
- Add admin RBAC and audit trails before exposing admin tools.

## Product/legal note
Automated trading can lose money, including the entire trading balance. Strategy labels are risk profiles, not guarantees. Obtain legal/compliance advice for the countries and customers you serve.
