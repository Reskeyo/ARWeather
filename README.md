# 🌤️ AR Weather — Augmented Reality Wetter-App

Eine visuell beeindruckende Android-App, die das aktuelle Wetter über ein **Echtzeit-AR-Kamera-Overlay** anzeigt. 3D-Wolken, Regen und Schnee fliegen basierend auf der **echten Windrichtung** auf den Nutzer zu — alles in einem modernen **Glassmorphism-Design**.

---

## ✨ Features

| Feature | Beschreibung |
|---------|-------------|
| 📷 **AR Kamera-Overlay** | Echtzeit-Kamerabild als Hintergrund mit darüber schwebenden Wetter-Effekten |
| ☁️ **Prozedurale Wolken** | Partikel-basierte Wolken, die mit dem Wind über den Bildschirm treiben |
| 🌧️ **Regen & Schnee** | Dynamische Niederschlags-Effekte, windrichtungsabhängig |
| 🧭 **Kompass-Integration** | Wettereffekte reagieren auf die echte Ausrichtung des Geräts |
| 🌡️ **Live-Wetterdaten** | Open-Meteo API (kein API-Key erforderlich) |
| 💎 **Glassmorphism UI** | BackdropFilter-Blur, halbtransparente Karten, feine Ränder |
| 🔄 **Auto-Refresh** | Wetterdaten werden alle 5 Minuten automatisch aktualisiert |

---

## 🏗️ Architektur

```
lib/
├── main.dart                          # App Entry Point
├── models/
│   └── weather_data.dart              # Wetter-Datenmodell
├── services/
│   ├── weather_service.dart           # Open-Meteo API Client
│   ├── location_service.dart          # GPS Location Service
│   └── compass_service.dart           # Kompass-Heading Stream
├── providers/
│   └── weather_providers.dart         # Riverpod State Management
└── ui/
    ├── ar_view/
    │   ├── ar_weather_screen.dart     # Haupt-AR-Screen (Layer-Komposition)
    │   ├── camera_layer.dart          # Kamera-Feed Widget
    │   └── weather_overlay.dart       # Partikel-System (Wolken/Regen/Schnee)
    └── widgets/
        ├── glass_card.dart            # Glassmorphism-Karte
        ├── weather_header.dart        # Temperatur & Condition Display
        ├── metric_badge.dart          # Kapsel-Badges für Messwerte
        └── wind_direction_indicator.dart  # Kompass-Windrichtungsanzeige
```

---

## 🚀 Schnellstart

### Voraussetzungen

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (≥ 3.0.0)
- [Android Studio](https://developer.android.com/studio) mit Android SDK
- Ein Android-Gerät (Emulator unterstützt keine Kamera/Kompass)

### 1. Repository klonen & Dependencies installieren

```bash
git clone https://github.com/DEIN-USERNAME/ARWeather.git
cd ARWeather
flutter pub get
```

### 2. Auf Android-Gerät ausführen

```bash
# Gerät verbinden und Debug-Build starten
flutter run
```

### 3. Release-APK lokal bauen

```bash
flutter build apk --release
# APK liegt unter: build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔄 GitHub Repository einrichten & APK automatisch bauen

### 1. Git-Repository initialisieren

```bash
cd ARWeather
git init
git add .
git commit -m "Initial commit: AR Weather App"
```

### 2. GitHub-Repository erstellen & pushen

```bash
# Erstelle ein neues Repository auf github.com, dann:
git remote add origin https://github.com/DEIN-USERNAME/ARWeather.git
git branch -M main
git push -u origin main
```

### 3. Automatischer APK-Build

Sobald du auf `main` pushst, startet die **GitHub Actions Pipeline** automatisch:

1. ✅ Flutter SDK wird aufgesetzt
2. ✅ Dependencies werden installiert
3. ✅ Release-APK wird gebaut
4. ✅ APK wird als **GitHub Release** veröffentlicht

### 4. APK herunterladen

1. Gehe zu deinem Repository auf GitHub
2. Klicke auf **Releases** (rechte Sidebar)
3. Lade die `app-release.apk` aus dem neuesten Release herunter
4. Übertrage die APK auf dein Android-Gerät und installiere sie

> ⚠️ **Hinweis:** Du musst auf deinem Android-Gerät die Installation aus unbekannten Quellen erlauben.

---

## 🌐 API

Die App nutzt die [Open-Meteo API](https://open-meteo.com/) — **kein API-Key erforderlich**.

Abgefragte Daten:
- `temperature_2m` — Temperatur in °C
- `cloud_cover` — Bewölkung in %
- `wind_direction_10m` — Windrichtung in Grad
- `wind_speed_10m` — Windgeschwindigkeit in km/h
- `rain` — Niederschlag in mm
- `weather_code` — WMO Wetter-Code

---

## 🎨 Design-System

Die App verwendet ein konsequentes **Glassmorphism-Design**:

- **BackdropFilter** mit `sigmaX: 10, sigmaY: 10` für Blur-Effekte
- **Halbtransparente Fills** (`Colors.white.withOpacity(0.15)`)
- **Abgerundete Ecken** (`BorderRadius.circular(24)`)
- **Feine Ränder** (`Colors.white.withOpacity(0.3)`)
- **Google Fonts "Inter"** für moderne Typografie
- **Kapsel-Badges** für Messwerte (Wind, Regen, Bewölkung)

---

## 📱 Berechtigungen

| Berechtigung | Verwendung |
|-------------|-----------|
| `CAMERA` | AR-Kamera-Hintergrund |
| `ACCESS_FINE_LOCATION` | GPS für Wetterdaten-Abfrage |
| `ACCESS_COARSE_LOCATION` | Fallback-Standort |
| `INTERNET` | Open-Meteo API Zugriff |

---

## 🛠️ Tech-Stack

| Technologie | Zweck |
|-------------|-------|
| Flutter | Cross-Platform Framework |
| Riverpod | State Management |
| camera | Kamera-Live-Feed |
| geolocator | GPS-Standort |
| flutter_compass | Kompass-Heading |
| sensors_plus | Gyroscope-Daten |
| http | API-Requests |
| google_fonts | Typografie (Inter) |
| CustomPainter | Partikel-Rendering |

---

## 📄 Lizenz

MIT License — frei verwendbar.
