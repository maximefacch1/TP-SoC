## Validation de l'IP PWM moteur

L'IP `ip_pwm_motor` a été intégrée dans Qsys comme esclave Avalon-MM.  
Elle expose des registres permettant de configurer l'activation du driver, le rapport cyclique PWM gauche/droite et le sens de rotation des moteurs.

La validation a été réalisée avec un programme C exécuté sur le Nios II via Altera Monitor Program.  
Les registres de l'IP ont été écrits directement par accès mémoire Avalon-MM.

Tests réalisés :

- écriture dans les registres de l'IP PWM ;
- activation du driver moteur avec `MTR_Sleep_n` ;
- test du moteur gauche seul ;
- test du moteur droit seul ;
- test des deux moteurs en marche avant ;
- test des deux moteurs en marche arrière ;
- correction logicielle du sens moteur gauche.

La valeur PWM minimale observée pour obtenir une rotation stable est d'environ `2500` pour une période de `3125`, soit environ 80 % de rapport cyclique.

Le moteur gauche étant monté dans le sens inverse du moteur droit, la marche avant réelle est obtenue avec le bit `CTRL_LEFT_REV` activé.