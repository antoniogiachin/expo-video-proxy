# Differenze del fork rispetto al primo commit del fork (baseline locale)

## Baseline
- Commit iniziale fork: `db01a6f3` ("Initial commit from expo-video with dynamic headers support")
- Range confronto: `db01a6f3..HEAD`
- Data confronto: 2026-02-06 11:53:52 CET
- Nota: questo riepilogo descrive **solo** le modifiche introdotte dopo il commit iniziale del fork.

## Sommario (high-level)
- Android: passaggio a implementazione “standard” per header dinamici via `DataSource` dedicata (senza proxy nel path principale del player).
- Android: aggiornamenti nel proxy locale HLS (content-type corretto, parsing URL piu` robusto, forwarding header semplificato).
- iOS: proxy locale semplificato con URL proxati del tipo `http://localhost:PORT/ORIGINAL_URL`, gestione redirect e copia header originali; rimoso rewriting HLS.
- Web: aggiunta proprieta` `dynamicRequestHeaders` come placeholder e miglioramento dei tipi/handle di `VideoView`.
- Aggiunti file di supporto (tipi ambientali, `.gitignore`, `package-lock.json`, update `package.json`), oltre a artefatti di build.

## API JS/TS

### Web: placeholder per `dynamicRequestHeaders`
- Aggiunta proprieta` `dynamicRequestHeaders` nel player web (dummy) per allineare l’interfaccia.
- File: `/Users/agiachin/Developer/expo-video-proxy/src/VideoPlayer.web.tsx`.

### Web: typing `VideoView`
- `VideoView` web ora tipizzato con un handle esplicito (metodi fullscreen/PiP e `nativeRef`).
- File: `/Users/agiachin/Developer/expo-video-proxy/src/VideoView.web.tsx`.

### Tipi ambientali aggiuntivi
- Aggiunto `/Users/agiachin/Developer/expo-video-proxy/src/types.d.ts` per dichiarazioni di moduli RN (`resolveAssetSource`, asset registry) e `__DEV__`.

## iOS

### Proxy locale: URL proxati e redirect
- URL proxati ora nel formato: `http://localhost:PORT/ORIGINAL_URL` (nessuna query `proxy?url=...`).
- Copia degli header originali (eccetto `Host`) dalla richiesta entrante prima dell’iniezione dei dinamici/statici.
- Redirect gestiti manualmente: riscrittura `Location` verso URL proxato.
- Eliminato rewriting dei manifest HLS: AVPlayer risolve i relativi grazie al path completo nel proxy.
- File: `/Users/agiachin/Developer/expo-video-proxy/ios/Proxy/CMCDProxy.swift`.

## Android (ExoPlayer)

### Implementazione “standard” (data source dinamica)
- Nuovo `DynamicHeadersDataSource` per iniettare header ad ogni request (`open()`), con accesso a `player.dynamicRequestHeaders`.
- Nuova funzione `buildExpoVideoMediaSourceWithDynamicHeaders` che costruisce la `MediaSource` usando la `DataSource` dinamica.
- `VideoPlayer.prepare()` ora usa la `MediaSource` dinamica quando `enableDynamicHeaders = true`, rimuovendo il passaggio al proxy come path principale.
- File:
  - `/Users/agiachin/Developer/expo-video-proxy/android/src/main/java/expo/modules/video/player/DynamicHeadersDataSource.kt`
  - `/Users/agiachin/Developer/expo-video-proxy/android/src/main/java/expo/modules/video/utils/DataSourceUtils.kt`
  - `/Users/agiachin/Developer/expo-video-proxy/android/src/main/java/expo/modules/video/player/VideoPlayer.kt`

### Proxy locale HLS (aggiustamenti)
- Parsing `.m3u8` ora basato sul path URL (senza query), piu` robusto.
- Forzato `Content-Type` corretto per manifest HLS (`application/vnd.apple.mpegurl`).
- Header forwarding semplificato (map `String -> String`).
- File: `/Users/agiachin/Developer/expo-video-proxy/android/src/main/java/expo/modules/video/proxy/CMCDProxy.kt`.

## Altre differenze
- Aggiunti `.gitignore` e `package-lock.json`.
- `package.json` aggiornato con devDependencies aggiuntive (`expo`, `react`, `react-native`, vari `@types/*`).
- Artefatti di build aggiornati/aggiunti in `/Users/agiachin/Developer/expo-video-proxy/build/*` (derivati dalla compilazione).
- File non funzionali presenti (es. `/Users/agiachin/Developer/expo-video-proxy/ios/.DS_Store`, `/Users/agiachin/Developer/expo-video-proxy/plugin/tsconfig.tsbuildinfo`).

## Scenari d’uso / test (documentativi)
- Android:
  - `VideoSource.enableDynamicHeaders = true`.
  - Verifica che `DynamicHeadersDataSource` inietti gli header aggiornati ad ogni request.
- iOS:
  - `enableDynamicHeaders = true` con verifica URL proxato `http://localhost:PORT/ORIGINAL_URL`.
  - Verifica che i redirect passino dal proxy e che gli header originali + dinamici siano presenti.
- Web:
  - `dynamicRequestHeaders` non produce effetti (placeholder).
