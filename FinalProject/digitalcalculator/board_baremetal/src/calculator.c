/*
 * calculator.c - Menu-based digital calculator
 *
 * Final project: Digital Calculator for the Loongson LS1B200 (MIPS32).
 *
 * The desktop/simulator build is a plain ANSI C console application using
 * the standard C library. With CALCULATOR_RTTHREAD, the same arithmetic and
 * validation code uses the LS1B BSP's UART console and RT-Thread output.
 * With CALCULATOR_BAREMETAL, newlib input/output is retargeted to UART5.
 *
 * Build: see Makefile (native/simulator) or board_rtthread/ (RT-Thread board).
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>
#include <errno.h>
#include <float.h>
#include <math.h>

#ifdef CALCULATOR_RTTHREAD
#include "rtthread.h"
#include "console.h"
#include "finsh.h"
#define printf rt_kprintf
#endif

#ifdef CALCULATOR_BAREMETAL
#include "uart5.h"
#endif

#define MAX_LINE_LEN 128

/* ------------------------------------------------------------------ */
/* Arithmetic operations                                              */
/* ------------------------------------------------------------------ */

double add(double a, double b)
{
    return a + b;
}

double subtract(double a, double b)
{
    return a - b;
}

double multiply(double a, double b)
{
    return a * b;
}

/*
 * Division is the only operation that can fail, so it writes the result
 * through a pointer and returns 1 on success / 0 when b is zero.
 */
int divide(double a, double b, double *result)
{
    if (b == 0.0) {
        return 0;
    }

    *result = a / b;
    return 1;
}

/* ------------------------------------------------------------------ */
/* Input helpers                                                      */
/* ------------------------------------------------------------------ */

/*
 * Reads one line of text into buffer.
 *
 * Returns 1 on success, 0 when end of input is reached (Ctrl+Z / closed
 * pipe).  If the user types more characters than the buffer can hold the
 * rest of the line is discarded, so the next prompt reads a fresh line.
 */
static int readLine(char *buffer, int size)
{
    int length;

#ifdef CALCULATOR_RTTHREAD
    static int skip_line_feed = 0;
    int ch;
    int overflow = 0;

    length = 0;
    for (;;) {
        ch = (signed char)console_getch();
        if (ch < 0) {
            rt_thread_mdelay(1);
            continue;
        }

        if (skip_line_feed) {
            skip_line_feed = 0;
            if (ch == '\n') {
                continue;
            }
        }

        if (ch == '\r' || ch == '\n') {
            if (ch == '\r') {
                skip_line_feed = 1;
            }
            console_putch('\n');
            break;
        }

        if (ch == '\b' || ch == 127) {
            if (length > 0 && !overflow) {
                length--;
                console_putstr("\b \b");
            }
            continue;
        }

        if (ch < 32 || ch > 126) {
            continue;
        }

        if (length < size - 1) {
            buffer[length++] = (char)ch;
            console_putch((char)ch);
        } else {
            overflow = 1;
            console_putch((char)ch);
        }
    }

    buffer[length] = '\0';
    if (overflow) {
        buffer[0] = '\0';
    }
    return 1;
#else

    if (fgets(buffer, size, stdin) == NULL) {
        buffer[0] = '\0';
        return 0;
    }

    length = (int)strlen(buffer);

    if (length > 0 && buffer[length - 1] == '\n') {
        buffer[length - 1] = '\0';
    } else if (length == size - 1) {
        int ch;

        while ((ch = getchar()) != '\n' && ch != EOF) {
            /* discard the rest of an over-long line */
        }
        buffer[0] = '\0';
    }

    /* Drop any remaining carriage return (text files built on Windows) */
    length = (int)strlen(buffer);
    if (length > 0 && buffer[length - 1] == '\r') {
        buffer[length - 1] = '\0';
    }

    return 1;
#endif
}

/* Removes leading and trailing white space from a string, in place. */
static void trim(char *text)
{
    int start = 0;
    int end;
    int i;

    while (text[start] != '\0' && isspace((unsigned char)text[start])) {
        start++;
    }

    end = start + (int)strlen(text + start);

    while (end > start && isspace((unsigned char)text[end - 1])) {
        end--;
    }

    for (i = 0; start < end; start++, i++) {
        text[i] = text[start];
    }
    text[i] = '\0';
}

/*
 * Reads and validates a number (integer or decimal).
 *
 * Returns  1 = a valid number was stored in *value
 *          0 = end of input
 *         -1 = the text was not a valid number
 *
 * The whole line must be a number: strtod() is asked for the address of
 * the first character it could not convert, and that character has to be
 * the end of the string.  Input such as "abc", "12abc" or "1 2" is
 * therefore rejected instead of being silently accepted in part.
 */
int readNumber(const char *prompt, double *value)
{
    char line[MAX_LINE_LEN];
    char *end;
    double parsed;

    printf("%s", prompt);
#ifndef CALCULATOR_RTTHREAD
    fflush(stdout);
#endif

    if (!readLine(line, sizeof(line))) {
        return 0;
    }

    trim(line);

    if (line[0] == '\0') {
        return -1;
    }

    errno = 0;
    parsed = strtod(line, &end);

    if (end == line || *end != '\0') {
        return -1;
    }
    if (errno == ERANGE) {
        return -1;
    }

    /*
     * strtod() accepts the words "inf" and "nan"; neither is a usable
     * operand, and "nan != nan" is the standard way to detect NaN.
     */
    if (parsed != parsed || parsed > DBL_MAX || parsed < -DBL_MAX) {
        return -1;
    }

    *value = parsed;
    return 1;
}

/*
 * Reads and validates the menu selection.
 *
 * Returns  1 = a valid integer choice was stored in *choice
 *          0 = end of input
 *         -1 = the text was not a whole number
 */
int readMenuChoice(int *choice)
{
    char line[MAX_LINE_LEN];
    char *end;
    long value;

    printf("Enter your choice: ");
    fflush(stdout);

    if (!readLine(line, sizeof(line))) {
        return 0;
    }

    trim(line);

    if (line[0] == '\0') {
        return -1;
    }

    errno = 0;
    value = strtol(line, &end, 10);

    if (errno != 0 || end == line || *end != '\0') {
        return -1;
    }
    if (value < -2147483647L || value > 2147483647L) {
        return -1;
    }

    *choice = (int)value;
    return 1;
}

/* ------------------------------------------------------------------ */
/* Screen output                                                      */
/* ------------------------------------------------------------------ */

/*
 * Prints a result without useless trailing zeros: whole numbers are
 * printed as integers ("15") and other values with up to ten significant
 * digits ("3.333333333", "0.25").
 */
static void printNumber(double value)
{
#ifdef CALCULATOR_RTTHREAD
    char formatted[32];
#endif

    if (value == 0.0) {
        value = 0.0;      /* normalise -0.0 so that "-0" is never printed */
    }

    if (fabs(value) < 1e15 && value == floor(value)) {
#ifdef CALCULATOR_RTTHREAD
        sprintf(formatted, "%.0f", value);
        rt_kprintf("%s", formatted);
#else
        printf("%.0f", value);
#endif
    } else {
#ifdef CALCULATOR_RTTHREAD
        sprintf(formatted, "%.10g", value);
        rt_kprintf("%s", formatted);
#else
        printf("%.10g", value);
#endif
    }
}

void displayMenu(void)
{
    printf("==============================\n");
    printf("      DIGITAL CALCULATOR      \n");
    printf("==============================\n");
    printf("  1. Addition\n");
    printf("  2. Subtraction\n");
    printf("  3. Multiplication\n");
    printf("  4. Division\n");
    printf("  5. Exit\n");
    printf("------------------------------\n");
}

/* Reads the two operands of the selected operation. */
static int readOperands(double *a, double *b)
{
    int status;

    status = readNumber("Enter first number : ", a);
    if (status == 0) {
        return 0;
    }
    if (status < 0) {
        return -1;
    }

    status = readNumber("Enter second number: ", b);
    if (status == 0) {
        return 0;
    }
    if (status < 0) {
        return -1;
    }

    return 1;
}

/*
 * Runs one calculation and prints the result.
 *
 * Returns 1 when a result was printed, 0 on end of input and -1 when the
 * calculation could not be performed (invalid operand, divide by zero).
 */
static int performCalculation(int choice)
{
    double a = 0.0;
    double b = 0.0;
    double result = 0.0;
    int status;

    status = readOperands(&a, &b);

    if (status == 0) {
        return 0;
    }
    if (status < 0) {
        printf("Error: invalid numeric input.\n\n");
        return -1;
    }

    switch (choice) {
    case 1:
        result = add(a, b);
        break;
    case 2:
        result = subtract(a, b);
        break;
    case 3:
        result = multiply(a, b);
        break;
    case 4:
        if (!divide(a, b, &result)) {
            printf("Error: division by zero is not allowed.\n\n");
            return -1;
        }
        break;
    default:
        return -1;
    }

    printf("Result: ");
    printNumber(result);
    printf("\n\n");
    return 1;
}

/* ------------------------------------------------------------------ */
/* Program entry point                                                */
/* ------------------------------------------------------------------ */

#if defined(CALCULATOR_RTTHREAD) || defined(CALCULATOR_BAREMETAL)
int calculator_main(void)
#else
int main(void)
#endif
{
    int choice;
    int status;
    int finished = 0;

    printf("\nWelcome to the Digital Calculator\n\n");

    while (!finished) {
        displayMenu();

        status = readMenuChoice(&choice);

        if (status == 0) {
            printf("\nEnd of input reached.\n");
            break;
        }
        if (status < 0) {
            printf("Invalid selection: please enter a number from 1 to 5.\n\n");
            continue;
        }

        switch (choice) {
        case 1:
        case 2:
        case 3:
        case 4:
            status = performCalculation(choice);
            if (status == 0) {
                printf("\nEnd of input reached.\n");
                finished = 1;
            }
            break;
        case 5:
            printf("Goodbye.\n");
            finished = 1;
            break;
        default:
            printf("Invalid selection: please enter a number from 1 to 5.\n\n");
            break;
        }
    }

    return 0;
}

#ifdef CALCULATOR_RTTHREAD
static void calculator(int argc, char **argv)
{
    (void)argc;
    (void)argv;
    calculator_main();
}
MSH_CMD_EXPORT(calculator, start the digital calculator);
#endif
