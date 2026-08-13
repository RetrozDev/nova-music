# Nova Music 🎧

Application Android qui permet de **rechercher de la musique**, de l'**écouter en streaming sans pub** et de la **télécharger pour l'écouter hors-ligne**, le tout dans une interface moderne et sombre.

## Fonctionnalités

- 🔍 **Recherche** : cherche des musiques par titre, artiste ou genre (YouTube).
- ▶️ **Lecture en streaming sans publicité** : écoute directe dès que tu as internet.
- ⬇️ **Téléchargement** avec vraie barre de progression, pourcentage et vitesse.
- 🎼 **Bibliothèque** : tes téléchargements, avec pochettes et lecture hors-ligne.
- 🎛️ **Lecteur plein écran** : contrôle de la file d'attente, boucle, lecture aléatoire.
- 🔔 **Lecture en arrière-plan** : notification de contrôle + écoute même écran éteint.
- 🎨 **7 thèmes personnalisables** : onglet Réglages → choisis ton ambiance (Nova, Océan, Émeraude, Feu, Néon, Nuit, Ambre) — ton choix est conservé.
- 🔄 **Mise à jour automatique** : l'app détecte les nouvelles versions publiées ici et s'installe **par-dessus**, sans désinstaller ni perdre tes téléchargements.
- ⚙️ **Onglet Réglages** : thèmes, mises à jour et infos de l'app.

## Télécharger

L'APK prêt à installer est disponible dans les **[Releases](https://github.com/RetrozDev/nova-music/releases)** de ce dépôt.

**Mises à jour** : installe la dernière version, puis l'app te proposera automatiquement les suivantes (bouton « Mise à jour » dans Bibliothèque, ou notification au lancement).

## Construire depuis les sources

Prérequis : Flutter 3.x + Android SDK.

```bash
flutter pub get
flutter build apk --release
```

L'APK est généré dans `build/app/outputs/flutter-apk/app-release.apk`.

## Avertissement

Nova Music récupère des flux audio publics sur YouTube à des fins d'écoute personnelle. Respecte les conditions d'utilisation de la plateforme et les droits d'auteur : télécharge uniquement du contenu dont tu as le droit.

## Licence

Projet personnel — non affilié à YouTube ou Google.
