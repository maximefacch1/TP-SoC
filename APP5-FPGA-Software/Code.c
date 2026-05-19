#define LED_BASE_ADDR 0x04003010u
#define PWM_BASE_ADDR 0x00000000u
#define ADC_BASE_ADDR 0x00000040u

#define LED ((volatile unsigned int *)LED_BASE_ADDR)
#define PWM ((volatile unsigned int *)PWM_BASE_ADDR)
#define ADC ((volatile unsigned int *)ADC_BASE_ADDR)

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
 * Vitesse validée expérimentalement.
 * PERIOD PWM = 3125
 * 2500 / 3125 ≈ 80 %
 */
#define DUTY_RUN            2150

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

    ADC[ADC_REG_CHANNEL] = channel & 0x7;
    ADC[ADC_REG_CONTROL] = ADC_CTRL_START | ADC_CTRL_IR_ON;

    timeout = 1000000;

    while (((ADC[ADC_REG_STATUS] & ADC_STATUS_DONE) == 0) && timeout > 0) {
        timeout--;
    }

    value = ADC[ADC_REG_DATA] & 0x0FFF;

    return value;
}

static void motor_stop(void)
{
    PWM[PWM_REG_CONTROL] = 0x00;
    PWM[PWM_REG_DUTY_LEFT] = 0;
    PWM[PWM_REG_DUTY_RIGHT] = 0;
}

static void motor_forward(unsigned int duty_left, unsigned int duty_right)
{
    PWM[PWM_REG_DUTY_LEFT] = duty_left;
    PWM[PWM_REG_DUTY_RIGHT] = duty_right;

    /*
     * Avant réel :
     * moteur gauche inversé mécaniquement,
     * moteur droit normal.
     */
    PWM[PWM_REG_CONTROL] = CTRL_ENABLE | CTRL_SLEEP_N | CTRL_LEFT_REV;
}

static void turn_right(void)
{
    /*
     * Pour tourner à gauche :
     * roue gauche arrêtée,
     * roue droite avance.
     */
    PWM[PWM_REG_DUTY_LEFT] = 0;
    PWM[PWM_REG_DUTY_RIGHT] = DUTY_RUN;
    PWM[PWM_REG_CONTROL] = CTRL_ENABLE | CTRL_SLEEP_N;
}

static void turn_left(void)
{
    /*
     * Pour tourner à droite :
     * roue gauche avance,
     * roue droite arrêtée.
     */
    PWM[PWM_REG_DUTY_LEFT] = DUTY_RUN;
    PWM[PWM_REG_DUTY_RIGHT] = 0;
    PWM[PWM_REG_CONTROL] = CTRL_ENABLE | CTRL_SLEEP_N | CTRL_LEFT_REV;
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
     * Avec ton top de debug, LED7 affiche aussi IR_LED_ON.
     */
    ADC[ADC_REG_CONTROL] = ADC_CTRL_IR_ON;

    while (1) {
        led_pattern = 0;

        for (i = 0; i < 7; i++) {
            sensors[i] = adc_read_channel(i);

            if (sensors[i] > LINE_THRESHOLD) {
                led_pattern |= (1u << i);
            }
        }

        /*
         * Affichage capteurs :
         * LED0 = CH0
         * LED1 = CH1
         * ...
         * LED6 = CH6
         */
        LED[0] = led_pattern & 0x7F;

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
         * Logique simple de suivi de ligne :
         *
         * CH3 noir              -> avancer
         * CH0/CH1/CH2 noir      -> tourner gauche
         * CH4/CH5/CH6 noir      -> tourner droite
         * aucun capteur noir    -> stop
         */
        if (center_detected) {
            motor_forward(DUTY_RUN, DUTY_RUN);
        }
        else if (left_detected) {
            turn_left();
        }
        else if (right_detected) {
            turn_right();
        }
        else {
            motor_stop();
        }

        delay(50000);
    }

    return 0;
}