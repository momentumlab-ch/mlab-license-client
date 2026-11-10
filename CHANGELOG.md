# Changelog

## 1.1.0 — 2026-11-10

- Neue REST-Route `POST mlab-license/v1/refresh`: löst eine sofortige Lizenzprüfung aus, damit Änderungen auf dem Server ohne Wartezeit ankommen.
- Die Route ist öffentlich, löst aber höchstens eine Prüfung pro Minute aus (Option `mlab_license_ping_at`) und tut ohne Schlüssel nichts.
- Die Antwort ist immer nur `{ "ok": true }`: kein Zustand, keine Produkte, kein Schlüssel. Es wird nichts freigeschaltet, ausser der Server bestätigt es bei der Prüfung.

## 1.0.0 — 2026-11-10

- Erste Version: ein Lizenzschlüssel pro Website für alle MomentumLab-Plugins, mit und ohne MomentumLab Core.
- Freischaltungen ohne Anfrage im Frontend, 7 Tage Kulanz bei Serverausfall.
- Übernimmt Schlüssel aus MomentumLab Core und MomentumLab SEO.
