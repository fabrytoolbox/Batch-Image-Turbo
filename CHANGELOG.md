# Changelog

## [2.0.0] - 2025-02-01

### Added
- GUI Matrix (tema scuro, testo verde)
- Auto-download FFmpeg
- Log su file (thread-safe)
- Parallelizzazione con `ForEach-Object -Parallel` (solo CPU)
- Pulsante Terminate per fermare i processi
- Salvataggio automatico in JPG
- Salto automatico delle immagini <= 1080p

### Changed
- Rimosso il supporto CUDA (downscaling troppo instabile e non necessario, la CPU e' sufficiente)
- ThrottleLimit fissato a 14 (ottimizzato per i7 Alder Lake). Vedi README per CPU piu' vecchie.

## [1.0.0] - 2025-01-31

### Added
- Script base per il downscale di immagini in batch a 1080p.
