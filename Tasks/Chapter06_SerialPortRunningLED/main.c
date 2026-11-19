#include <stdio.h>
#include "ls1b.h"
#include "mips.h"
#include "ls1b_gpio.h"
#include "ns16550.h"

#define LED_1 9
#define LED_2 11
#define LED_3 15
#define LED_4 17
#define LED_5 20
#define LED_6 22
#define LED_7 6
#define LED_8 7
#define GPIO_OUT 0
#define SPEED_MIN_MS 100
#define SPEED_MAX_MS 1000
#define SPEED_DEFAULT_MS 500
#define BUFFER_SIZE 32

//-------------------------------------------------------------------------------------------------
// Global variables
//-------------------------------------------------------------------------------------------------
static const int led_pins[8] = { LED_1, LED_2, LED_3, LED_4, LED_5, LED_6, LED_7, LED_8 };

int speed = SPEED_DEFAULT_MS; // Initial speed of the running LED (ms)
int current_led = LED_1;      // The currently lit LED
int is_running = 0;           // Running state of the running LED
char buffer_uart[BUFFER_SIZE];

static int total_read = 0;    // Number of bytes stored in buffer_uart
static int overflow = 0;      // The current line is longer than buffer_uart

//-------------------------------------------------------------------------------------------------
// GPIO initialization
//-------------------------------------------------------------------------------------------------
void gpio_init() {
    // Initialize the LEDs as output mode
    gpio_enable(LED_1, GPIO_OUT);
    gpio_enable(LED_2, GPIO_OUT);
    gpio_enable(LED_3, GPIO_OUT);
    gpio_enable(LED_4, GPIO_OUT);
    gpio_enable(LED_5, GPIO_OUT);
    gpio_enable(LED_6, GPIO_OUT);
    gpio_enable(LED_7, GPIO_OUT);
    gpio_enable(LED_8, GPIO_OUT);
}

//-------------------------------------------------------------------------------------------------
// UART initialization
//-------------------------------------------------------------------------------------------------
void uart_init() {
    ls1x_uart_init(devUART3, NULL);
    ls1x_uart_open(devUART3, NULL);
}

//-------------------------------------------------------------------------------------------------
// Send a string to the serial port
//-------------------------------------------------------------------------------------------------
void uart_send(const char *text) {
    char ch;

    while ((ch = *text++) != '\0') {
        ls1x_uart_write(devUART3, &ch, 1, NULL);
    }
}

//-------------------------------------------------------------------------------------------------
// Turn all LEDs off
//-------------------------------------------------------------------------------------------------
void leds_off() {
    gpio_write(LED_1, 1);
    gpio_write(LED_2, 1);
    gpio_write(LED_3, 1);
    gpio_write(LED_4, 1);
    gpio_write(LED_5, 1);
    gpio_write(LED_6, 1);
    gpio_write(LED_7, 1);
    gpio_write(LED_8, 1);
}

//-------------------------------------------------------------------------------------------------
// Control the currently lit LED
//-------------------------------------------------------------------------------------------------
void led_on(int led) {
    leds_off();
    if (led != -1) {
        gpio_write(led, 0); // Turn on the specified LED
    }
}

//-------------------------------------------------------------------------------------------------
// Switch to the next LED
//-------------------------------------------------------------------------------------------------
void next_led() {
    switch (current_led) {
    case LED_1: current_led = LED_2; break;
    case LED_2: current_led = LED_3; break;
    case LED_3: current_led = LED_4; break;
    case LED_4: current_led = LED_5; break;
    case LED_5: current_led = LED_6; break;
    case LED_6: current_led = LED_7; break;
    case LED_7: current_led = LED_8; break;
    case LED_8: current_led = LED_1; break;
    default: current_led = LED_1; break;
    }
}

//-------------------------------------------------------------------------------------------------
// String helpers
//-------------------------------------------------------------------------------------------------
static int starts_with(const char *text, const char *prefix) {
    while (*prefix != '\0') {
        if (*text++ != *prefix++) {
            return 0;
        }
    }
    return 1;
}

static int equals(const char *text, const char *word) {
    while (*word != '\0') {
        if (*text++ != *word++) {
            return 0;
        }
    }
    return *text == '\0';
}

// Parses a complete decimal number, allowing surrounding blanks
static int parse_decimal(const char *text, int *value) {
    int result = 0;
    int digits = 0;

    while (*text == ' ' || *text == '\t') {
        ++text;
    }
    while (*text >= '0' && *text <= '9') {
        result = result * 10 + (*text - '0');
        ++text;
        ++digits;
    }
    while (*text == ' ' || *text == '\t') {
        ++text;
    }
    if (digits == 0 || *text != '\0') {
        return 0;
    }

    *value = result;
    return 1;
}

//-------------------------------------------------------------------------------------------------
// Parse the serial-port command
//-------------------------------------------------------------------------------------------------
void parse_command(char *command) {
    char line[BUFFER_SIZE];
    int len = 0;
    int value;

    // Trim the blanks and fold the line to upper case
    while (*command == ' ' || *command == '\t') {
        ++command;
    }
    while (*command != '\0' && len < BUFFER_SIZE - 1) {
        char c = *command++;
        if (c >= 'a' && c <= 'z') {
            c = (char)(c - 'a' + 'A');
        }
        line[len++] = c;
    }
    while (len > 0 && (line[len - 1] == ' ' || line[len - 1] == '\t')) {
        --len;
    }
    line[len] = '\0';

    if (len == 0) {
        return; // Ignore blank lines
    }

    if (starts_with(line, "ON") &&
        parse_decimal(line + 2, &value) &&
        value >= 1 && value <= 8) {
        is_running = 0; // Stop the running LED
        current_led = led_pins[value - 1];
        led_on(current_led);
        uart_send("OK\r\n");
    } else if (equals(line, "OFF")) {
        is_running = 0; // Stop the running LED
        leds_off();
        uart_send("OK\r\n");
    } else if (starts_with(line, "SPEED") &&
               parse_decimal(line + 5, &value) &&
               value >= SPEED_MIN_MS && value <= SPEED_MAX_MS) {
        speed = value;
        uart_send("OK\r\n");
    } else if (equals(line, "START")) {
        is_running = 1; // Start the running LED
        led_on(current_led);
        uart_send("OK\r\n");
    } else if (equals(line, "STOP")) {
        is_running = 0; // Stop the running LED
        uart_send("OK\r\n");
    } else {
        uart_send("ERR\r\n");
    }
}

//-------------------------------------------------------------------------------------------------
// Read every pending character and run the complete commands
//-------------------------------------------------------------------------------------------------
void poll_uart() {
    char byte;

    while (ls1x_uart_read(devUART3, &byte, 1, 0) > 0) {
        unsigned char c = (unsigned char)byte;

        if (c == '\r' || c == '\n') {
            if (overflow) {
                uart_send("ERR\r\n");
            } else if (total_read > 0) {
                buffer_uart[total_read] = '\0';
                parse_command(buffer_uart);
            }
            total_read = 0;
            overflow = 0;
        } else if (c == '\b' || c == 0x7F) {
            if (total_read > 0) {
                --total_read;
            }
        } else if (c >= 0x20 && c <= 0x7E) {
            if (total_read < BUFFER_SIZE - 1) {
                buffer_uart[total_read++] = (char)c;
            } else {
                overflow = 1; // Drop the rest of an over-long line
            }
        }
        // Any other control byte is line noise and is dropped
    }
}

//-------------------------------------------------------------------------------------------------
// Main function
//-------------------------------------------------------------------------------------------------
int main(void) {
    int elapsed;

    ls1x_drv_init();         /* Initialize the device driver */
    install_3th_libraries(); /* Install the third-party libraries */
    gpio_init();
    uart_init();

    speed = SPEED_DEFAULT_MS;
    current_led = LED_1;
    is_running = 0;
    leds_off();

    uart_send("READY\r\n");

    while (1) {
        poll_uart();

        // Running LED logic
        if (!is_running) {
            continue;
        }

        led_on(current_led);
        for (elapsed = 0; elapsed < speed; ++elapsed) {
            delay_ms(1);
            poll_uart();
            if (!is_running) {
                break;
            }
        }
        if (is_running) {
            next_led();
        }
    }

    return 0;
}

/*
* @@ End
*/