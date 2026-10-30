# 🖼️ Batch Image Downscaler (Turbo)

Ridimensiona in batch immagini ad alta risoluzione (es. 4K) a 1080p, usando la potenza multi-thread della CPU.

## ✨ Feature

- ✅ **Downscale a 1080p**: Riporta tutte le immagini a 1920x1080.
- ✅ **Modalità Turbo**: Usa `ForEach-Object -Parallel` per elaborare più immagini contemporaneamente.
- ✅ **Salta le immagini già piccole**: Se un'immagine è <= 1080p, viene ignorata.
- ✅ **Auto-download FFmpeg**: Nessuna installazione manuale.
- ✅ **Log su file thread-safe**: Traccia tutte le operazioni anche con 14 processi in parallelo.
- ✅ **Pulsante Terminate**: Ferma i processi in corso.

## 🖥️ Ottimizzazione Hardware (IMPORTANTE)

Questo script è stato **ottimizzato per CPU Intel Core i7 di 12ª generazione (Alder Lake)**, con un limite di default di **14 processi paralleli** (14 thread logici).

**Se usi una CPU più vecchia o con meno core**, è altamente consigliato abbassare questo limite per evitare crash, surriscaldamenti o un generale rallentamento del sistema.

### Come modificare il limite

Apri lo script con un editor di testo (es. Notepad++) e cerca questa riga (intorno alla metà del file):

```powershell
# Fissiamo il limite a 14 (ottimo per Alder Lake e simili)
$limit = 14

Modificala in base alla tua CPU:

i7 / Ryzen 7 (8+ core): lascia 14.

i5 / Ryzen 5 (6 core): imposta 6 o 8.

i3 / CPU datate (2-4 core): imposta 2 o 4.

📋 Requisiti
Windows 10 / 11

PowerShell 7+ (scarica da https://aka.ms/powershell)

FFmpeg (scaricato automaticamente al primo avvio)

🚀 Quick start
powershell
git clone https://github.com/fabrytoolbox/Batch-Image-Downscaler.git
cd Batch-Image-Downscaler
Unblock-File .\Batch-Image-Downscaler.ps1
.\Batch-Image-Downscaler.ps1
Oppure doppio click su avvia.bat.

🎯 Casi d'uso
Post-Elaborazione AI: Riporta a 1080p i frame generati da Topaz Photo AI o altri tool di upscaling.

Preparare video: Uniforma le dimensioni dei frame prima di creare un video con FFmpeg.

Risparmiare spazio: Riduci il peso di una cartella di foto 4K.

⚙️ Come funziona
Seleziona la cartella sorgente (e, se vuoi, quella di destinazione).

Clicca "AVVIA TURBO".

Il tool elaborerà in parallelo tutte le immagini con altezza maggiore di 1080p, usando la CPU.

🐛 Problemi comuni
"FFmpeg non trovato"

Il tool chiede se scaricarlo. Se fallisce, scaricalo manualmente da https://www.gyan.dev/ffmpeg/builds/ e mettilo nella cartella dello script.

"Il PC si blocca durante l'elaborazione"
Hai troppi processi in parallelo per la tua CPU. Apri lo script, cerca $limit = 14 e abbassalo (es. a 4 o 6).

"L'immagine non è cambiata"
Se l'immagine era già <= 1080p, viene saltata. Controlla il log.

📜 Licenza
MIT (vedi LICENSE).

🙏 Crediti
FFmpeg per l'elaborazione immagini

Fabry Toolbox