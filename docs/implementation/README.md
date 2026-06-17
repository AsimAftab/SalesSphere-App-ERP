# Implementation docs

Feature implementation notes and mobile ↔ backend API integration specs for the
SalesSphere ERP mobile app. Each spec defines the contract a feature is wired
against (envelope, endpoints, permissions, request/response shapes).

| Doc | What it covers |
|-----|----------------|
| [odometer-mobile-integration.md](odometer-mobile-integration.md) | Odometer start/stop trip API — multipart photo upload, today-status, monthly report, `409` conflict shape. |
| [unplanned-visits-mobile-integration.md](unplanned-visits-mobile-integration.md) | Unplanned (ad-hoc) field visits — customer/prospect/site target, client-side geofence, start/stop with photo + follow-up date. **Backend not yet implemented.** |
| [beat-plan-stop-visit.md](beat-plan-stop-visit.md) | Beat-plan stop visit check-in/out flow (planned visits with live tracking). |
| [live-tracking-socket.md](live-tracking-socket.md) | Live-tracking socket protocol for beat-plan field tracking. |
