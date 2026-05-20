#include "system.h"
#include "io.h"

/*
 * Correction du linker BSP :
 * Les IP custom n'ont pas de driver HAL dédié.
 * Le BSP appelle __alt_invalid() pour ces périphériques.
 * On la définit vide car on pilote les IP directement avec IORD/IOWR.
 */
void __alt_invalid(void)
{
}

/*
 * Bases HAL générées dans system.h
 */
#define PWM_BASE        IP_PWM_MOTOR_0_BASE
#define ADC_BASE        IP_LTC2308_ADC_0_BASE
#define LED_BASE        LEDS_BASE

/*
 * Registres IP PWM
 */
#define PWM_REG_CONTROL     0
#define PWM_REG_DUTY_LEFT   1
#define PWM_REG_DUTY_RIGHT  2
#define PWM_REG_STATUS      3
#define PWM_REG_PERIOD      4

/*
 * Registres IP ADC
 */
#define ADC_REG_CONTROL     0
#define ADC_REG_CHANNEL     1
#define ADC_REG_DATA        2
#define ADC_REG_STATUS      3
#define ADC_REG_CH0         4
#define ADC_REG_CH1         5
#define ADC_REG_CH2         6
#define ADC_REG_CH3         7
#define ADC_REG_CH4         8
#define ADC_REG_CH5         9
#define ADC_REG_CH6         10
#define ADC_REG_CH7         11

/*
 * Bits CONTROL PWM
 */
#define CTRL_ENABLE         0x01
#define CTRL_SLEEP_N        0x02
#define CTRL_LEFT_REV       0x04
#define CTRL_RIGHT_REV      0x08
#define CTRL_BRAKE          0x10

/*
 * Bits CONTROL ADC
 */
#define ADC_CTRL_START      0x01
#define ADC_CTRL_IR_ON      0x02

/*
 * Bits STATUS ADC
 */
#define ADC_STATUS_BUSY     0x01
#define ADC_STATUS_DONE     0x02

/*
 * Seuil validé expérimentalement :
 * blanc ≈ 360 à 500
 * noir  ≈ 3020 à 3065
 */
#define LINE_THRESHOLD      1700

/*
 * Vitesse demandée.
 * PERIOD PWM = 3125
 * 2250 / 3125 ≈ 72 %
 */
#define DUTY_RUN            2250

static void delay(volatile unsigned int count)
{
    while (count > 0) {
        count--;
    }
}

static unsigned int adc_read_channel(unsigned int channel)
{
    volatile unsigned int timeout;
    unsigned int value;

    IOWR(ADC_BASE, ADC_REG_CHANNEL, channel & 0x7);

    /*
     * Lance une conversion tout en gardant les LEDs IR activées.
     */
    IOWR(ADC_BASE, ADC_REG_CONTROL, ADC_CTRL_START | ADC_CTRL_IR_ON);

    /*
     * Avec la nouvelle IP, DONE est une impulsion courte.
     * Il est plus fiable d'attendre que BUSY retombe à 0.
     */
    timeout = 1000000;

    while ((IORD(ADC_BASE, ADC_REG_STATUS) & ADC_STATUS_BUSY) && timeout > 0) {
        timeout--;
    }

    value = IORD(ADC_BASE, ADC_REG_DATA) & 0x0FFF;

    return value;
}

static void motor_stop(void)
{
    IOWR(PWM_BASE, PWM_REG_CONTROL, 0x00);
    IOWR(PWM_BASE, PWM_REG_DUTY_LEFT, 0);
    IOWR(PWM_BASE, PWM_REG_DUTY_RIGHT, 0);
}

static void motor_forward(unsigned int duty_left, unsigned int duty_right)
{
    IOWR(PWM_BASE, PWM_REG_DUTY_LEFT, duty_left);
    IOWR(PWM_BASE, PWM_REG_DUTY_RIGHT, duty_right);

    /*
     * Avant réel :
     * moteur gauche inversé mécaniquement,
     * moteur droit normal.
     */
    IOWR(PWM_BASE, PWM_REG_CONTROL, CTRL_ENABLE | CTRL_SLEEP_N | CTRL_LEFT_REV);
}

static void physical_turn_left(void)
{
    /*
     * Tourne réellement à gauche :
     * roue gauche arrêtée,
     * roue droite avance.
     */
    IOWR(PWM_BASE, PWM_REG_DUTY_LEFT, 0);
    IOWR(PWM_BASE, PWM_REG_DUTY_RIGHT, DUTY_RUN);

    IOWR(PWM_BASE, PWM_REG_CONTROL, CTRL_ENABLE | CTRL_SLEEP_N);
}

static void physical_turn_right(void)
{
    /*
     * Tourne réellement à droite :
     * roue gauche avance,
     * roue droite arrêtée.
     */
    IOWR(PWM_BASE, PWM_REG_DUTY_LEFT, DUTY_RUN);
    IOWR(PWM_BASE, PWM_REG_DUTY_RIGHT, 0);

    IOWR(PWM_BASE, PWM_REG_CONTROL, CTRL_ENABLE | CTRL_SLEEP_N | CTRL_LEFT_REV);
}

int main(void)
{
    unsigned int sensors[7];
    unsigned int led_pattern;
    unsigned int i;

    unsigned int left_detected;
    unsigned int center_detected;
    unsigned int right_detected;

    motor_stop();

    /*
     * Active les LEDs IR.
     * Dans ton top de debug, LED7 affiche IR_LED_ON.
     */
    IOWR(ADC_BASE, ADC_REG_CONTROL, ADC_CTRL_IR_ON);

    while (1) {
        led_pattern = 0;

        /*
         * Lecture des capteurs :
         *
         * CH0 CH1 CH2 CH3 CH4 CH5 CH6
         * gauche       centre       droite
         */
        for (i = 0; i < 7; i++) {
            sensors[i] = adc_read_channel(i);

            if (sensors[i] > LINE_THRESHOLD) {
                led_pattern |= (1u << i);
            }
        }

        /*
         * LED0 à LED6 = détection des capteurs.
         * LED7 reste pilotée par le top VHDL avec IR_LED_ON.
         */
        IOWR(LED_BASE, 0, led_pattern & 0x7F);

        left_detected =
            ((led_pattern & 0x01) != 0) ||
            ((led_pattern & 0x02) != 0) ||
            ((led_pattern & 0x04) != 0);

        center_detected =
            ((led_pattern & 0x08) != 0);

        right_detected =
            ((led_pattern & 0x10) != 0) ||
            ((led_pattern & 0x20) != 0) ||
            ((led_pattern & 0x40) != 0);

        /*
         * Suivi de ligne simple.
         *
         * Inversion gauche/droite conservée :
         * - ligne détectée à gauche  -> correction physique à droite
         * - ligne détectée à droite  -> correction physique à gauche
         */
        if (center_detected) {
            motor_forward(DUTY_RUN, DUTY_RUN);
        }
        else if (left_detected) {
            physical_turn_right();
        }
        else if (right_detected) {
            physical_turn_left();
        }
        else {
            motor_stop();
        }

        delay(50000);
    }

    return 0;
}