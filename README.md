# 📅 BoomerCalendar 2026

Un'app calendario Android completa, offline-first, pensata per essere semplice e intuitiva per utenti non tecnologici. Nessun abbonamento, nessuna pubblicità, nessun account obbligatorio.

> Progetto personale sviluppato in Flutter — realizzato per uso familiare quotidiano.

---

## ✨ Funzionalità

### Calendario
- **Vista mensile** con pallini colorati sui giorni con eventi (colore = categoria)
- **Vista settimanale** con swipe orizzontale e dissolvenza animata tra i giorni
- Contatore attività completate oggi (es. `2/5`) sempre visibile
- Tema chiaro e scuro selezionabile dalle impostazioni

### Eventi
- Nome, note opzionali, data e ora, durata (4 opzioni predefinite + personalizzata)
- Categoria con colore personalizzato
- Checkbox per segnare come completato
- Eliminazione con conferma

### Categorie
- 6 categorie preinstallate: Famiglia, Personale, Salute, Lavoro, Amici, Varie
- Ogni categoria ha colore ed emoji
- Aggiungi categorie personalizzate con nome, colore da palette e emoji (20 disponibili)
- Eliminazione con conferma dalle impostazioni

### Notifiche
- Sistema a checkbox multipli: 5 min, 30 min, 1 ora, 1 giorno, 2 giorni prima
- Tempo personalizzato in minuti
- Riepilogo mattutino opzionale ogni giorno alle 8:00

### Ricorrenza
- Ogni giorno, settimana, mese o anno
- Occorrenze generate dinamicamente — nessuna duplicazione nel database

### Ricerca
- Barra di ricerca in tempo reale per nome o descrizione
- Risultati colorati per categoria

### Backup su Google Drive
- Login Google per autenticazione
- Salvataggio di eventi e categorie in formato JSON su una cartella dedicata Drive
- Backup automatico ogni 30 giorni
- Ripristino completo in caso di cambio telefono

---

## 🛠 Tecnologie

| Tecnologia | Utilizzo |
|---|---|
| Flutter / Dart | Framework principale |
| SQLite (sqflite) | Database locale |
| Riverpod | State management |
| flutter_local_notifications | Notifiche schedulate |
| Google Sign-In + googleapis | Autenticazione e backup Drive |
| table_calendar | Componente calendario mensile |

---

## 🔒 Privacy & Sicurezza

Le credenziali Google (`google-services.json`) non sono incluse nel repository.  
Per configurare il progetto crea il tuo file seguendo la [documentazione ufficiale di Google](https://firebase.google.com/docs/android/setup).

Crea un file `.env` partendo da `.env.example` e inserisci le tue chiavi.

---

## 📁 Setup

```bash
git clone https://github.com/enricolanzarolo/progetto_completato.git
cd progetto_completato
flutter pub get
flutter run
```

> ⚠️ Ricorda di aggiungere il tuo `google-services.json` in `android/app/` prima di eseguire l'app.
