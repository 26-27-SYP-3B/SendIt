# SendIt

Flutter-App mit Anmeldung, Registrierung und Benutzerprofil über Clerk.
Das Projekt enthält derzeit die iOS-Plattform.

## Clerk einrichten

1. Im [Clerk Dashboard](https://dashboard.clerk.com/) eine Anwendung erstellen.
2. Unter **Native applications** die **Native API** aktivieren.
3. Die gewünschten Anmeldemethoden aktivieren. Für den Einstieg eignen sich
   E-Mail und Passwort mit E-Mail-Verifizierung per Code. Social Login und
   Passkeys benötigen zusätzliche Konfiguration beim jeweiligen Anbieter und
   in der nativen App.
4. `clerk.example.json` nach `clerk.local.json` kopieren und unter
   `CLERK_PUBLISHABLE_KEY` den **Publishable Key** aus **API keys** eintragen.
   Nur `pk_test_…` bzw. `pk_live_…` verwenden. Secret Keys gehören ins Backend.

`clerk.local.json` wird von Git ausgeschlossen. Der Publishable Key ist eine
öffentliche Client-Konfiguration; ein Dart-Define verschlüsselt ihn nicht.

## Starten

```bash
flutter pub get
flutter run --dart-define-from-file=clerk.local.json
```

In VS Code den iOS-Simulator oder das angeschlossene iPhone auswählen und die
Startkonfiguration **SendIt** ausführen. Sie lädt dieselbe Konfigurationsdatei.
Nach einer Änderung des Keys die App vollständig neu starten.

Alternativ kann der Key direkt übergeben werden:

```bash
flutter run --dart-define=CLERK_PUBLISHABLE_KEY=pk_test_DEIN_KEY
```

Ohne Publishable Key zeigt die App einen Hinweis an. Mit gültiger Konfiguration
erscheint die Clerk-Anmeldung; über **Sign up** kann ein Konto erstellt werden.
Nach erfolgreicher Anmeldung oder Registrierung erscheint die Startansicht.
Über den Benutzerbutton lassen sich das Profil öffnen und die Sitzung beenden.
Die Sitzung wird vom Clerk-SDK über App-Neustarts hinweg gespeichert.
Die vorgefertigten Clerk-Formulare sind derzeit auf Englisch.

Bei OAuth übernimmt `OAuthCompletion` den Übergang zwischen Anmeldung und
Registrierung, sobald Clerk die Anbieter-Verifizierung als `transferable`
meldet. Das gleicht den fehlenden Transfer im Rotating-Token-Rücksprung des
SDKs 0.0.18-beta aus. Zusätzliche Pflichtangaben werden weiterhin im
Clerk-Formular abgefragt. Fehlgeschlagene Übergänge lassen sich erneut versuchen.

`clerk_flutter` ist als lokale Kopie unter `packages/clerk_flutter` eingebunden.
Sie übernimmt den nativen OAuth-Rücksprung auch dann, wenn iOS WebKit ihn als
URL-Änderung oder Ladefehler meldet. Nach erkanntem Rücksprung werden weitere
WebView-Ereignisse ignoriert, damit kein irreführender Authentifizierungsfehler
angezeigt wird. Andere Ladefehler der Hauptseite bleiben sichtbar. Die Änderungen
sind in `packages/clerk_flutter/SENDIT_PATCHES.md` dokumentiert.

### iOS-Build im OneDrive-Ordner

Falls Xcode mit `resource fork, Finder information, or similar detritus not
allowed` abbricht, verhindern Finder-Metadaten im Cloud-Ordner die Signierung
der generierten Frameworks. In diesem Fall das Projekt in einem lokalen
Verzeichnis außerhalb von OneDrive bauen. Ein erneutes `flutter clean` allein
hilft nicht, wenn OneDrive die Metadaten wieder hinzufügt.

Alternativ kann nur der generierte Ordner `build/` über einen symbolischen
Link auf einen lokalen Ordner außerhalb von OneDrive zeigen. Der Quellcode
bleibt dabei im Projektverzeichnis. Diese lokale Verknüpfung wird nicht
eingecheckt und muss nach `flutter clean` gegebenenfalls neu angelegt werden.

Zum Ausführen wird ein angeschlossenes iPhone oder eine installierte
iOS-Simulator-Laufzeit in Xcode benötigt.

## Prüfen

```bash
flutter analyze
flutter test
```

Für einen vollständigen Test im Simulator:

1. Über **Sign up** mit einer erreichbaren E-Mail-Adresse registrieren und den
   Verifizierungscode eingeben.
2. Prüfen, dass die Startansicht und das Benutzerprofil erscheinen.
3. App neu starten und prüfen, dass die Sitzung erhalten bleibt.
4. Über den Benutzerbutton abmelden und anschließend erneut anmelden.
5. OAuth mit einem neuen Anbieter-Konto testen: Nach dem Rücksprung müssen
   die Startansicht oder noch ausstehende Pflichtangaben erscheinen.
6. Mit demselben OAuth-Konto erneut anmelden und den Sitzungserhalt nach
   einem App-Neustart prüfen.

Das [Clerk Flutter SDK](https://pub.dev/packages/clerk_flutter) ist aktuell eine
communitygepflegte Beta. Die Einrichtung ist im
[Flutter Quickstart](https://docs.page/clerk-community/clerk-sdk-flutter/getting-started/quickstart)
beschrieben.
