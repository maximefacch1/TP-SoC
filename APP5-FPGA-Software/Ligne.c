#define LED_BASE_ADDR 0x04003010u
#define ADC_BASE_ADDR 0x00000040u

#define LED ((volatile unsigned int *)LED_BASE_ADDR)
#define ADC ((volatile unsigned int *)ADC_BASE_ADDR)

/*
 * Registres IP ADC
 */
#define ADC_REG_CONTROL   0
#define ADC_REG_CHANNEL   1
#define ADC_REG_DATA      2
#define ADC_REG_STATUS    3
#define ADC_REG_CH0       4

/*
 * CONTROL
 */
#define ADC_CTRL_START    0x01
#define ADC_CTRL_IR_ON    0x02

/*
 * STATUS
 */
#define ADC_STATUS_BUSY   0x01
#define ADC_STATUS_DONE   0x02

/*
 * Seuil global calculé avec tes mesures :
 * blanc ≈ 360 à 500
 * noir  ≈ 3020 à 3065
 */
#define LINE_THRESHOLD    1700

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

int main(void)
{
    unsigned int sensor_value;
    unsigned int led_pattern;
    unsigned int channel;

    /*
     * Active les LEDs IR.
     * Avec ton top de debug, LED7 doit s'allumer.
     */
    ADC[ADC_REG_CONTROL] = ADC_CTRL_IR_ON;

    while (1) {
        led_pattern = 0;

        for (channel = 0; channel < 7; channel++) {
            sensor_value = adc_read_channel(channel);

            /*
             * Noir = valeur ADC élevée
             * Blanc = valeur ADC faible
             */
            if (sensor_value > LINE_THRESHOLD) {
                led_pattern |= (1u << channel);
            }
        }

        /*
         * LED0 = CH0
         * LED1 = CH1
         * LED2 = CH2
         * LED3 = CH3
         * LED4 = CH4
         * LED5 = CH5
         * LED6 = CH6
         *
         * LED7 est pilotée par le top VHDL pour afficher IR_LED_ON.
         */
        LED[0] = led_pattern & 0x7F;

        delay(50000);
    }

    return 0;
}