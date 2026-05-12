# TP SoC - V0 - Making Qsys Component sur DE1

## Objectif

Ce projet correspond à l'adaptation du tutoriel Making Qsys Components sur la carte Altera DE1.

L'objectif est de créer un composant matériel personnalisé dans Qsys :

- un IP Core reg16_component ;
- connecté au bus Avalon Memory-Mapped ;
- accessible par le processeur Nios II ;
- capable de stocker une valeur 16 bits ;
- capable d'exporter cette valeur vers les afficheurs 7 segments de la carte DE1.

Le projet utilise une architecture basée sur :

- un processeur Nios II ;
- un bus Avalon MM ;
- un contrôleur SDRAM ;
- la SDRAM externe de la DE1 ;
- un IP Core personnalisé reg16_component ;
- une sortie Q_export ;
- des afficheurs HEX0 à HEX3.

---

## Architecture du système

L'architecture générale est la suivante :

Programme C / HAL
-> Nios II Processor
-> Avalon Interconnect
-> SDRAM Controller
-> SDRAM externe DE1

En parallèle, le même bus Avalon MM permet d'accéder au composant personnalisé :

Programme C / HAL
-> Nios II Processor
-> Avalon Interconnect
-> reg16_component
-> Q_export
-> hex7seg
-> HEX0 à HEX3

Le bus Avalon Interconnect relie le processeur Nios II aux différents périphériques du système.

Le Nios II agit comme maître Avalon MM.
Les composants connectés au bus sont des esclaves Avalon MM.

---

## Blocs principaux

| Bloc | Rôle |
|---|---|
| Nios II Processor | Processeur softcore exécutant le programme C |
| Avalon Interconnect | Bus reliant les maîtres et les esclaves Avalon MM |
| SDRAM Controller | Interface entre le bus Avalon MM et la SDRAM externe |
| SDRAM | Mémoire principale du système |
| reg16_component | IP Core personnalisé contenant un registre 16 bits |
| Q_export | Sortie exportée du registre vers le top-level |
| hex7seg | Conversion d'un mot 4 bits vers un afficheur 7 segments |
| HEX0..HEX3 | Afficheurs 7 segments de la carte DE1 |

---

## Utilisation de la SDRAM

Dans cette version, la mémoire principale du système est la SDRAM externe de la carte DE1.

Le programme exécuté par le Nios II est stocké en SDRAM.

Chemin mémoire :

Nios II -> Avalon Interconnect -> SDRAM Controller -> SDRAM externe

La SDRAM contient notamment :

- le programme ;
- les données ;
- la pile ;
- le tas ;
- les vecteurs reset et exception selon la configuration du Nios II.

---

## Composant personnalisé reg16_component

Le composant reg16_component est un IP Core personnalisé intégré dans Qsys.

Il est composé de deux parties :

- reg16_avalon_interface : adaptation des signaux Avalon MM ;
- reg16 : registre matériel 16 bits.

Le bloc reg16_avalon_interface sert d'interface entre le bus Avalon MM et le registre matériel reg16.

Le bloc reg16 contient la donnée 16 bits réellement stockée.

---

## Interfaces Qsys du composant

Le composant utilise quatre interfaces Qsys.

### 1. Interface horloge

Nom de l'interface : clock_sink

Signal utilisé :

- clock

Cette interface fournit l'horloge au composant.

### 2. Interface reset

Nom de l'interface : reset_sink

Signal utilisé :

- resetn

Le reset est actif à l'état bas.

### 3. Interface Avalon Memory-Mapped Slave

Nom de l'interface : avalon_slave_0

Signaux utilisés :

| Signal | Direction | Rôle |
|---|---|---|
| chipselect | entrée | Indique que le composant est sélectionné |
| read | entrée | Demande de lecture |
| write | entrée | Demande d'écriture |
| writedata[15:0] | entrée | Donnée envoyée par le Nios II |
| readdata[15:0] | sortie | Donnée renvoyée au Nios II |
| byteenable[1:0] | entrée | Sélection des octets à écrire |

Cette interface permet au Nios II d'accéder au registre comme à une adresse mémoire.

### 4. Interface Conduit

Nom de l'interface : conduit_end

Signal utilisé :

- Q_export[15:0]

Cette interface exporte la valeur du registre hors du système Qsys vers le top-level Quartus.

---

## Fonctionnement du composant

### Reset

Lorsque resetn = 0, le registre est remis à zéro :

Q = 0x0000

### Écriture

Une écriture est prise en compte uniquement si :

chipselect = 1
write = 1

Dans ce cas, le composant autorise l'écriture avec :

local_byteenable = byteenable

Sinon :

local_byteenable = 00

Le signal byteenable permet d'écrire séparément les deux octets du registre.

| byteenable | Action |
|---|---|
| 00 | aucune écriture |
| 01 | écriture de l'octet bas Q[7:0] |
| 10 | écriture de l'octet haut Q[15:8] |
| 11 | écriture complète Q[15:0] |

### Lecture

Lors d'une lecture, la valeur actuelle du registre est renvoyée au Nios II :

readdata = Q

La même valeur est aussi exportée vers le top-level :

Q_export = Q

---

## Connexions internes du composant

Dans reg16_component, les connexions internes sont les suivantes :

- writedata[15:0] est transmis à reg16_avalon_interface puis à l'entrée D[15:0] du registre reg16 ;
- byteenable[1:0] est transmis à reg16_avalon_interface puis transformé en local_byteenable[1:0] ;
- clock est connecté au registre reg16 ;
- resetn est connecté au registre reg16 ;
- Q[15:0] est renvoyé vers readdata[15:0] ;
- Q[15:0] est aussi envoyé vers Q_export[15:0].

Le registre reg16 est donc accessible de deux façons :

- par le Nios II via readdata ;
- par le top-level via Q_export.

---

## Connexion aux afficheurs 7 segments

La sortie Q_export[15:0] est découpée en quatre groupes de 4 bits :

- Q_export[3:0] vers HEX0 ;
- Q_export[7:4] vers HEX1 ;
- Q_export[11:8] vers HEX2 ;
- Q_export[15:12] vers HEX3.

Chaque groupe de 4 bits est envoyé dans un module hex7seg.

Le module hex7seg convertit une valeur hexadécimale sur 4 bits en commande d'afficheur 7 segments.

---

## Accès logiciel avec HAL

Le développement logiciel doit utiliser l'approche HAL.

L'accès au composant se fait avec les macros d'entrée / sortie mémoire.

Écriture dans le registre :

IOWR(REG16_COMPONENT_BASE, 0, 0x1234);

Lecture du registre :

int value = IORD(REG16_COMPONENT_BASE, 0);

REG16_COMPONENT_BASE correspond à l'adresse de base générée automatiquement par Qsys dans system.h.

---

## Validation

La validation consiste à vérifier que le Nios II peut écrire dans le composant custom et que la valeur écrite est visible sur les afficheurs 7 segments.

Étapes de validation :

1. générer le système Qsys ;
2. compiler le projet Quartus ;
3. programmer la carte DE1 ;
4. lancer le programme C HAL sur le Nios II ;
5. écrire une valeur dans reg16_component ;
6. vérifier l'affichage sur HEX0..HEX3.

Exemple :

Valeur écrite : 0x1234
Affichage attendu : HEX3 HEX2 HEX1 HEX0 = 1 2 3 4

Si l'affichage correspond à la valeur écrite, alors :

- le composant est bien connecté au bus Avalon MM ;
- le décodage d'adresse fonctionne ;
- l'écriture Avalon MM fonctionne ;
- la sortie Q_export fonctionne ;
- la connexion vers les afficheurs est correcte.

---

## Organisation du projet

Chaque IP Core doit être placé dans un dossier dédié dans IP_Modules.

Organisation retenue :

TP-SoC/
- README.md
- IP_Modules/
  - reg16_component/
    - reg16.vhd
    - reg16_avalon_interface.vhd
    - reg16_avalon_interface_hw.tcl
- hardware/
  - quartus_project/
  - qsys_system/
  - top_level.vhd
  - hex7seg.vhd
- software/
  - app_hal/

---

## Résumé

Ce projet montre comment créer un IP Core personnalisé dans Qsys.

Le composant reg16_component est un esclave Avalon Memory-Mapped.
Il contient un registre 16 bits accessible par le Nios II avec des accès mémoire HAL.
La valeur du registre est aussi exportée par une interface Conduit vers les afficheurs 7 segments de la carte DE1.

Architecture finale :

HAL -> Nios II -> Avalon MM -> reg16_component -> Q_export -> HEX0..HEX3

Mémoire programme :

Nios II -> Avalon MM -> SDRAM Controller -> SDRAM externe
