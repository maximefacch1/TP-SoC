# TP SoC - V1 CuteCar

## Objectif

Cette version du projet permet de piloter le robot CuteCar avec une architecture SoC basée sur un processeur Nios II et deux IP personnalisées :

* une IP PWM pour commander les moteurs ;
* une IP ADC pour lire les capteurs de ligne via le LTC2308.

Les deux IP sont intégrées dans Qsys / Platform Designer comme esclaves Avalon-MM.

---

## Architecture générale

```text
Nios II
  |
  | Avalon-MM
  |
  +--> IP PWM Motor  --> GPIO0 --> Driver moteurs CuteCar
  |
  +--> IP LTC2308 ADC --> GPIO0 --> Capteurs de ligne
  |
  +--> PIO LEDs
```

Le projet utilise :

* `system.qsys` pour l’architecture SoC ;
* `Top_VHDL.vhd` comme top-level ;
* `ip_pwm_motor.vhd` pour la commande moteur ;
* `ip_ltc2308_adc.vhd` comme interface Avalon-MM de l’ADC ;
* `ltc2308_adc_core.vhd` comme coeur SPI / FSM du LTC2308 ;
* Altera Monitor Program pour les tests mémoire et les programmes C.

---

# 1. IP PWM Motor

## Rôle

L’IP PWM permet au Nios II de commander les deux moteurs du CuteCar.

Elle génère quatre signaux de commande moteur :

```text
MTRR_P / MTRR_N : moteur droit
MTRL_P / MTRL_N : moteur gauche
```

Elle génère aussi :

```text
MTR_Sleep_n : activation du driver moteur
MTR_Fault_n : retour défaut moteur
```

---

## Mapping mémoire PWM

Base PWM :

```text
0x00000000
```

|      Adresse | Registre     | Rôle                    |
| -----------: | ------------ | ----------------------- |
| `0x00000000` | `CONTROL`    | activation, sens, frein |
| `0x00000004` | `DUTY_LEFT`  | vitesse moteur gauche   |
| `0x00000008` | `DUTY_RIGHT` | vitesse moteur droit    |
| `0x0000000C` | `STATUS`     | défaut moteur           |
| `0x00000010` | `PERIOD`     | période PWM             |

---

## Registre CONTROL

| Bit | Nom         | Rôle                     |
| --: | ----------- | ------------------------ |
|   0 | `ENABLE`    | active le PWM            |
|   1 | `SLEEP_N`   | active le driver moteur  |
|   2 | `LEFT_REV`  | inverse le moteur gauche |
|   3 | `RIGHT_REV` | inverse le moteur droit  |
|   4 | `BRAKE`     | freinage                 |

Commandes validées :

```text
STOP    = 0x00000000
AVANT   = 0x00000007
ARRIERE = 0x0000000B
```

La marche avant utilise `0x07` car le moteur gauche est monté dans le sens inverse du moteur droit.

---

## PWM utilisé

La période PWM est :

```text
PERIOD = 3125 = 0x00000C35
```

Avec une horloge de 50 MHz :

```text
fPWM = 50 MHz / 3125 = 16 kHz
```

La vitesse validée pour les tests est :

```text
DUTY = 2250 = 0x000008CA
```

Soit environ :

```text
2250 / 3125 ≈ 72 %
```

---

## Mapping GPIO moteurs

| Signal        |        GPIO | Pin      |
| ------------- | ----------: | -------- |
| `MTRR_N`      | `GPIO_0[2]` | `PIN_A2` |
| `MTRR_P`      | `GPIO_0[3]` | `PIN_A3` |
| `MTRL_P`      | `GPIO_0[4]` | `PIN_B3` |
| `MTRL_N`      | `GPIO_0[5]` | `PIN_B4` |
| `MTR_Sleep_n` | `GPIO_0[6]` | `PIN_A4` |
| `MTR_Fault_n` | `GPIO_0[7]` | `PIN_B5` |

---

## Validation PWM

Tests réalisés :

* écriture directe dans les registres PWM avec Altera Monitor Program ;
* test moteur gauche seul ;
* test moteur droit seul ;
* test marche avant ;
* test marche arrière ;
* correction du sens moteur gauche.

Exemple pour avancer :

```text
0x00000004 = 0x000008CA
0x00000008 = 0x000008CA
0x00000000 = 0x00000007
```

---

# 2. IP LTC2308 ADC

## Rôle

L’IP ADC permet de lire les capteurs de ligne du CuteCar via l’ADC LTC2308.

L’IP est maintenant séparée en deux blocs :

```text
ip_ltc2308_adc.vhd
    -> interface Avalon-MM

ltc2308_adc_core.vhd
    -> coeur SPI + machine d’état ADC
```

Cette séparation permet de dissocier :

* la communication Avalon avec le Nios II ;
* la logique matérielle SPI du LTC2308.

L’IP permet :

* de sélectionner un canal ADC ;
* de lancer une conversion ;
* d’activer les LEDs infrarouges ;
* de lire une valeur 12 bits ;
* de stocker les valeurs des canaux `CH0` à `CH7`.

---

## Fonctionnement du coeur ADC

Le fichier `ltc2308_adc_core.vhd` contient :

* la génération SPI ;
* les compteurs de timing ;
* la FSM de conversion ;
* l’acquisition des 12 bits ADC.

Machine d’état utilisée :

```text
IDLE
CONV_HIGH
CONV_LOW
SCK_LOW
SCK_HIGH
FRAME_DONE
```

La FSM :

1. lance la conversion avec `ADC_CONVST` ;
2. attend le temps de conversion ;
3. génère l’horloge SPI `ADC_SCK` ;
4. envoie la commande canal via `ADC_SDI` ;
5. récupère les données via `ADC_SDO` ;
6. stocke la conversion sur 12 bits.

---

## Mapping mémoire ADC

Base ADC :

```text
0x00000040
```

|      Adresse | Registre  | Rôle                        |
| -----------: | --------- | --------------------------- |
| `0x00000040` | `CONTROL` | start + LEDs IR             |
| `0x00000044` | `CHANNEL` | canal ADC sélectionné       |
| `0x00000048` | `DATA`    | dernière valeur lue         |
| `0x0000004C` | `STATUS`  | busy / done                 |
| `0x00000050` | `CH0`     | capteur 0                   |
| `0x00000054` | `CH1`     | capteur 1                   |
| `0x00000058` | `CH2`     | capteur 2                   |
| `0x0000005C` | `CH3`     | capteur 3                   |
| `0x00000060` | `CH4`     | capteur 4                   |
| `0x00000064` | `CH5`     | capteur 5                   |
| `0x00000068` | `CH6`     | capteur 6                   |
| `0x0000006C` | `CH7`     | batterie / canal auxiliaire |

---

## Registre CONTROL ADC

| Bit | Nom         | Rôle                 |
| --: | ----------- | -------------------- |
|   0 | `START`     | lance une conversion |
|   1 | `IR_LED_ON` | active les LEDs IR   |

Pour lancer une conversion avec les LEDs IR actives :

```text
CONTROL = 0x00000003
```

Le bit `START` est utilisé comme impulsion de lancement.

---

## Registre STATUS ADC

| Bit | Nom       | Rôle                    |
| --: | --------- | ----------------------- |
|   0 | `BUSY`    | conversion en cours     |
|   1 | `DONE`    | conversion terminée     |
|   2 | `ADC_SDO` | état brut du signal ADC |

Le software attend principalement :

```text
BUSY = 0
```

avant de lire la donnée convertie.

---

## Mapping GPIO ADC

| Signal           |         GPIO | Pin       |
| ---------------- | -----------: | --------- |
| `ADC_CONVST`     |  `GPIO_0[8]` | `PIN_A5`  |
| `ADC_SCK`        |  `GPIO_0[9]` | `PIN_D5`  |
| `ADC_SDO`        | `GPIO_0[10]` | `PIN_B6`  |
| `ADC_SDI`        | `GPIO_0[11]` | `PIN_A6`  |
| `IR_LED_ON`      | `GPIO_0[32]` | `PIN_D12` |
| `VCC3P3_PWRON_n` | `GPIO_0[33]` | `PIN_B12` |

Dans le top-level :

```vhdl
GPIO_0(33) <= '0';
```

Cela active l’alimentation 3.3 V de la carte SCD.

---

# 3. Séquentiel et combinatoire

## Partie séquentielle

Une logique séquentielle dépend de l’horloge et mémorise des valeurs.

Elle est utilisée pour :

* les registres Avalon ;
* le compteur PWM ;
* la machine d’état SPI de l’ADC ;
* les valeurs ADC stockées ;
* les états `BUSY` et `DONE`.

Elle est écrite dans des process synchrones :

```vhdl
process(clk, reset_n)
begin
    if reset_n = '0' then
        ...
    elsif rising_edge(clk) then
        ...
    end if;
end process;
```

C’est nécessaire quand le circuit doit mémoriser une information ou évoluer étape par étape.

---

## Partie combinatoire

Une logique combinatoire ne mémorise rien.
Elle calcule directement une sortie à partir des signaux actuels.

Elle est utilisée pour :

* décoder les bits de contrôle ;
* générer `readdata` selon l’adresse ;
* choisir les sorties moteur selon le sens ;
* comparer `counter < duty`.

Exemple :

```text
si counter < duty alors PWM = 1
sinon PWM = 0
```

---

## Pourquoi plusieurs process ?

Les IP utilisent plusieurs process pour séparer les rôles :

* un process synchrone pour la mémoire et les états ;
* un process combinatoire pour les lectures Avalon ;
* des affectations simples pour les sorties directes.

Cette séparation rend le code plus clair et évite de mélanger logique mémoire et logique instantanée.

---

# 4. Validation ADC

## Test CH7

Après correction de l’IP ADC, le canal 7 donne une valeur non nulle :

```text
CH7 = 0x529 = 1321
```

Cela valide la communication avec le LTC2308.

---

## Valeurs mesurées sur blanc

| Canal |     Hex | Décimal |
| ----: | ------: | ------: |
|   CH0 | `0x191` |     401 |
|   CH1 | `0x170` |     368 |
|   CH2 | `0x16A` |     362 |
|   CH3 | `0x17D` |     381 |
|   CH4 | `0x1F5` |     501 |
|   CH5 | `0x19F` |     415 |
|   CH6 | `0x1A4` |     420 |

---

## Valeurs mesurées sur noir

| Canal |     Hex | Décimal |
| ----: | ------: | ------: |
|   CH0 | `0xBE2` |    3042 |
|   CH1 | `0xBD3` |    3027 |
|   CH2 | `0xBCE` |    3022 |
|   CH3 | `0xBD5` |    3029 |
|   CH4 | `0xBE1` |    3041 |
|   CH5 | `0xBD7` |    3031 |
|   CH6 | `0xBF9` |    3065 |

La séparation est nette :

```text
Blanc ≈ 360 à 500
Noir  ≈ 3020 à 3065
```

Le seuil choisi est donc :

```c
#define LINE_THRESHOLD 1700
```

Règle :

```text
valeur > 1700  => ligne noire détectée
valeur <= 1700 => blanc
```

---

# 5. Test détection de ligne sur LEDs

Un programme C lit les canaux `CH0` à `CH6` et affiche le résultat sur les LEDs.

| Capteur   | LED  |
| --------- | ---- |
| CH0       | LED0 |
| CH1       | LED1 |
| CH2       | LED2 |
| CH3       | LED3 |
| CH4       | LED4 |
| CH5       | LED5 |
| CH6       | LED6 |
| IR_LED_ON | LED7 |

Résultat validé :

```text
blanc : LEDs 0 à 6 éteintes
noir  : LEDs des capteurs concernés allumées
```

---

# 6. Suiveur de ligne

Le programme final réalise un suivi de ligne simple.

Principe utilisé :

```text
CH0 CH1 CH2 CH3 CH4 CH5 CH6
gauche       centre       droite
```

Logique utilisée :

```text
CH3 noir              -> avancer
CH0/CH1/CH2 noir      -> correction à droite
CH4/CH5/CH6 noir      -> correction à gauche
aucun capteur noir    -> arrêt
```

Le moteur gauche étant monté mécaniquement à l’envers, le software applique une inversion logique des corrections.

Les actions moteur sont :

```text
motor_forward()
physical_turn_left()
physical_turn_right()
motor_stop()
```

Le système validé permet :

* l’avance automatique ;
* la correction de trajectoire ;
* la détection noir/blanc ;
* l’arrêt si la ligne est perdue.

---

# 7. Bilan V1

La V1 valide :

* l’intégration de deux IP Avalon-MM ;
* la commande PWM des moteurs ;
* la correction du sens moteur ;
* la lecture du LTC2308 ;
* l’activation des LEDs IR ;
* la lecture des capteurs de ligne ;
* la détection noir/blanc avec seuil ;
* l’affichage de la ligne sur les LEDs ;
* le suivi de ligne automatique ;
* la séparation propre entre interface Avalon et coeur ADC SPI.
