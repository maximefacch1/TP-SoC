#define LED_BASE_ADDR 0x04003010u
#define PWM_BASE_ADDR 0x00000000u

#define LED ((volatile unsigned int *)LED_BASE_ADDR)
#define PWM ((volatile unsigned int *)PWM_BASE_ADDR)

#define PWM_REG_CONTROL     0
#define PWM_REG_DUTY_LEFT   1
#define PWM_REG_DUTY_RIGHT  2
#define PWM_REG_STATUS      3
#define PWM_REG_PERIOD      4

#define CTRL_ENABLE     0x01
#define CTRL_SLEEP_N    0x02
#define CTRL_LEFT_REV   0x04
#define CTRL_RIGHT_REV  0x08
#define CTRL_BRAKE      0x10

#define DUTY_TEST 2500

static void delay(volatile unsigned int count)
{
    while (count > 0) {
        count--;
    }
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

    PWM[PWM_REG_CONTROL] = CTRL_ENABLE | CTRL_SLEEP_N | CTRL_LEFT_REV;
}

static void motor_reverse(unsigned int duty_left, unsigned int duty_right)
{
    PWM[PWM_REG_DUTY_LEFT] = duty_left;
    PWM[PWM_REG_DUTY_RIGHT] = duty_right;

    PWM[PWM_REG_CONTROL] = CTRL_ENABLE | CTRL_SLEEP_N | CTRL_RIGHT_REV;
}

int main(void)
{
    motor_stop();
    delay(1000000);

    LED[0] = 0x0F;
    motor_forward(DUTY_TEST, 0);
    delay(1000000);

    motor_stop();
    delay(1000000);

    LED[0] = 0xF0;
    motor_forward(0, DUTY_TEST);
    delay(1000000);

    motor_stop();
    LED[0] = 0xAA;

    while (1) {
    }

    return 0;
}