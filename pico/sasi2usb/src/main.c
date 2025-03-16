/**
 * Copyright (c) 2020 Raspberry Pi (Trading) Ltd.
 *
 * SPDX-License-Identifier: BSD-3-Clause
 */

 #include <stdio.h>
 #include "pico/stdlib.h"


 #define LED_DELAY_MS 100
 #define PICO_DEFAULT_LED_PIN 25
 
 // Initialize the GPIO for the LED
 void pico_led_init(void) {
    gpio_init(PICO_DEFAULT_LED_PIN);
    gpio_set_dir(PICO_DEFAULT_LED_PIN, GPIO_OUT);
 }
 
 // Turn the LED on or off
 void pico_set_led(bool led_on) {
     // Just set the GPIO on or off
     gpio_put(PICO_DEFAULT_LED_PIN, led_on);
 }
 
 int main() {
     pico_led_init();
     stdio_init_all();
     while (true) {
         pico_set_led(true);
         sleep_ms(LED_DELAY_MS);
         pico_set_led(false);
         sleep_ms(LED_DELAY_MS);
        printf("Hello, world!\n");
     }
 }