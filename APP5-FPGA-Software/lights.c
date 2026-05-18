#define switches (volatile char *) 0x04003000
#define leds (char *) 0x04003010
void main()
{ while (1)
*leds = *switches;
}