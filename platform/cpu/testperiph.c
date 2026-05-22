
#include <stdio.h>
#include <sys/unistd.h>
#include "xparameters.h"
#include "xil_printf.h"

#include "xgpio.h"
#include "gpio_header.h"

#include "xuartlite.h"
#include "uartlite_header.h"
// to use led and uart
XGpio led_gpio;
XUartLite uart;
// XUartLite_Config uart_config;

// uart defines
#define XUARTLITE_BASEADDRESS XPAR_XUARTLITE_0_BASEADDR

// all config values are 32 bit registerss
#define MSG_SIZE_BYTES (4)
#define SYNC_CONST (0XFFU)
// uart buffers for sending and receiving data
u8 recv_buf[MSG_SIZE_BYTES] = { 0 };
u8 send_buf[MSG_SIZE_BYTES] = { 0 };
u8 recv_count = 0;
u8 send_count = 0;


// useful constants
#define LED_DELAY 	500000
#define LED_CHANNEL 1
#define DIR_OUTPUT 	0
#define XPAR_GPIO_LED_DEVICE_ID 0
// data patterns
#define SOL0 ((u32) 0x00 << 2)
#define SOL1 ((u32) 0x01 << 2)
#define CHK1 ((u32) 0x02 << 2)
#define ROS1 ((u32) 0x03 << 2)


// address space of DRAM memory, from xparamters.h
#define HAMMER_MODULE_BASE XPAR_HAMMER_DEVICE_0_BASEADDR
#define HAMMER_MODULE_HIGH XPAR_HAMMER_DEVICE_0_HIGHADDR
// registers
// WRITE ONLY
#define AG1_REG (0)
#define AG2_REG (1)
#define VICTIM_REG (2)
#define N_ACT_REG (3)
#define CONTROL_REG (4)
// READ ONLY
#define DATA_READ_127_96_REG (5)
#define DATA_READ_95_64_REG (6)
#define DATA_READ_63_32_REG (7)
#define DATA_READ_31_0_REG (8)
#define DATA_VALID_REG (9)
#define STATUS_REG (10)
#define ADDR_REG (11)


// ------ prototypes
// read and write to peripheral registers
void write_reg(u32 reg_idx, u32 data);
void read_reg(u32 reg_idx, u32 * data);
void print_flip_positions(u32 data_xor_expected, int col, int word);
// blocks until buffer is filled with the requested data
void uart_recv(XUartLite *uart, u8 *buf, u8 buf_size);
// blocks until all data is sent through the uart
void uart_send(XUartLite *uart, u8 *buf, u8 buf_size);
// check that the buffer contains the sync constant
int is_sync_const(u8 *buf, u8 buf_size);
// coverts 4 bytes to u32, assumes at least 4 byts in buffer
// buf[0] is put in the high part of the result
u32 u8_arr_to_u32_val(u8 *buf);
u32 expected_data_pattern(u32 pattern, u32 victim);
void do_hammer(u32 ag1, u32 ag2, u32 victim, u32 data_pattern, u32 n_act);


// ------ utils
// a few seconds of delay
#define WAIT \
do { \
    for (volatile int i = 0; i < 10000000; i++) {} \
} while (0)
// give data ack
// set bit 0 then clear it without changing other bits
#define SEND_ACK \
do { \
    u32 status; \
    read_reg(CONTROL_REG, &status); \
    write_reg(CONTROL_REG, status | 0x3); \
    write_reg(CONTROL_REG, status | 0x2); \
} while (0)
// reads and prints status register
#define PRINT_STATUS \
do { \
    u32 tmp; \
    read_reg(STATUS_REG, &tmp); \
    xil_printf("STATUS REG IS: %u\r\n", tmp); \
} while (0)
// wait for the sync signal via uart
#define WAIT_SYNC \
do { \
    uart_recv(&uart, recv_buf, MSG_SIZE_BYTES); \
    while (is_sync_const(recv_buf, MSG_SIZE_BYTES) != 1) { \
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES); \
    } \
} while (0)
// writes sync signal in buffer and sends it over uart
#define SEND_SYNC \
do { \
    for (int i = 0; i < MSG_SIZE_BYTES; i++) { \
        send_buf[i] = SYNC_CONST; \
    } \
    uart_send(&uart, send_buf, MSG_SIZE_BYTES); \
} while (0)

// read and write to peripheral registers
void write_reg(u32 reg_idx, u32 data) {
	Xil_Out32( HAMMER_MODULE_BASE + 0x4*reg_idx, data );
}

void read_reg(u32 reg_idx, u32 * data) {
  *data = Xil_In32( HAMMER_MODULE_BASE + 0x4*reg_idx );
}

void print_flip_positions(u32 data_xor_expected, int col, int word) {
    for (int i = 0; i < 32; i++) {
        if ((data_xor_expected & (1U << (31-i))) != 0) {
            xil_printf("%u,%u,%u\r\n", col, word, i);
        }        
    }
}

// blocks until buffer is filled with the requested data
void uart_recv(XUartLite *uart, u8 *buf, u8 buf_size) {
    u8 recv_count = 0;
    while(1) {
        // retry until buffer is full
        recv_count += XUartLite_Recv(uart, buf + recv_count, (unsigned int) (buf_size - recv_count));
        if (recv_count == buf_size) {
            break;        
        }
    }
}

// blocks until all data is sent through the uart
void uart_send(XUartLite *uart, u8 *buf, u8 buf_size) {
    u8 sent_count = 0;
    while(1) {
        // retry until buffer is full
        sent_count += XUartLite_Send(uart, buf + sent_count, (unsigned int) (buf_size - sent_count));
        if (sent_count == buf_size) {
            break;        
        }
    }
}

// check that the buffer contains the sync constant
int is_sync_const(u8 *buf, u8 buf_size) {
    for (int i = 0; i < buf_size; i++) {
        if (*(buf + i) != SYNC_CONST) {
            return 0;
        }
    }
    return 1;
}

// coverts 4 bytes to u32, assumes at least 4 byts in buffer
// buf[0] is put in the high part of the result
u32 u8_arr_to_u32_val(u8 *buf) {
    return (u32) (
        (((u32) buf[0] & 0XFF) << 24) |
        (((u32) buf[1] & 0XFF) << 16) |
        (((u32) buf[2] & 0XFF) << 8) |
        (((u32) buf[3] & 0XFF) << 0)
    );
}

u32 expected_data_pattern(u32 pattern, u32 victim) {
    u32 expected_data;
    switch (pattern) {
        case SOL1:
            expected_data = (u32) 0xFFFFFFFFU;
            break;
        case SOL0:
            expected_data = (u32) 0x00000000U;
            break;
        case CHK1:
            if (victim % 2 == 0) {
                expected_data = (u32) 0xAAAAAAAAU;
            } else {
                expected_data = (u32) 0x55555555U;
            }
            break;
        case ROS1:
            if (victim % 2 == 0) {
                expected_data = (u32) 0xFFFFFFFFU;
            } else {
                expected_data = (u32) 0x00000000U;
            }
            break;
        default:
            xil_printf("Invalid data pattern %u", pattern);
    }
    return expected_data;
}

// returns flips_count (32 bit words that have flips)
void do_hammer(u32 ag1, u32 ag2, u32 victim, u32 data_pattern, u32 n_act) {
    u32 status;
    // reset the device (active low)
    write_reg(CONTROL_REG, 0x0);

    // configure the peripheral
    write_reg(AG1_REG, ag1);    
    write_reg(AG2_REG, ag2);    
    write_reg(VICTIM_REG, victim);    
    write_reg(N_ACT_REG, n_act);
    write_reg(CONTROL_REG, data_pattern);
  
    // set start bit in control reg
    read_reg(CONTROL_REG, &status);
    write_reg(CONTROL_REG, 0x2 | status);

    //     for (volatile int i = 0; i < 10000000; i++) {}

}

int main() {
	u32 status, data_out;
    u32 flips_found;
    // variables to configure the hammer peripheral    
    u32 ag1, ag2, victim, n_act, pattern_tmp, pattern, expected_data;

    // disable data caches
    Xil_DCacheDisable();

    // initialize GPIO to use led as status indicators
	// XPAR_GPIO_LED_DEVICE_ID: see xparameters.h
	// GPIO_LED is the name of the AXI_GPIO IP from Vivado
    status = XGpio_Initialize(&led_gpio, XPAR_GPIO_LED_DEVICE_ID);
	if(status != XST_SUCCESS) //if status!=0
	{
		xil_printf("Gpio Initialization Failed\r\n");
		return XST_FAILURE; //return 1
	}

    // initialize the uart
    status = XUartLite_Initialize(&uart, XUARTLITE_BASEADDRESS);
    if(status != XST_SUCCESS) //if status!=0
	{
		xil_printf("UART Initialization Failed\r\n");
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x40);
		return XST_FAILURE; //return 1
	}

    // do self test of uart
    status = XUartLite_SelfTest(&uart);
    if(status != XST_SUCCESS) //if status!=0
	{
		xil_printf("UART self-test Failed\r\n");
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x80);
		return XST_FAILURE; //return 1
	}


    // LED0-3 on, initialization complete
    XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x0F);

///////////////////echo for debug/////////////////////////
// recv_buf[0] = 1;
// recv_buf[1] = 2;
// recv_buf[2] = 3;
// recv_buf[3] = 4;
// u8 loops = 0;
// while (1)
// {
//     XUartLite_Send(&uart, recv_buf, MSG_SIZE_BYTES);
//     // uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
//     XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, loops);
//     loops++;
//     WAIT;
// }
// loops =0;
// while(1) {
//     XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, loops);
//     XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, ++loops);
//     uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
//     uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
//     loops++;
//     WAIT;
// }
    while(TRUE) {
        // LED0 and 7 on, ready to sync (previous test completed)
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x81);

        // wait for the starting sequence
        WAIT_SYNC;
        // echo it back
        SEND_SYNC;

        // LED4-7 on, sync received, wiating config
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0xF0);


        // will receive the configuration in the following order
        // ag1 -> ag2 -> victim -> n_act -> pattern
        // the code will echo the value back as confirmation
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
        ag1 = u8_arr_to_u32_val(recv_buf);
        uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
        ag2 = u8_arr_to_u32_val(recv_buf);
        uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
        victim = u8_arr_to_u32_val(recv_buf);
        uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
        n_act = u8_arr_to_u32_val(recv_buf);
        uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying
        uart_recv(&uart, recv_buf, MSG_SIZE_BYTES);
        pattern_tmp = u8_arr_to_u32_val(recv_buf);
        uart_send(&uart, recv_buf, MSG_SIZE_BYTES); // use recv_buf to avoid copying

        // map the pattern received to the one that the code expectes
        switch (pattern_tmp) {
            case 0U:
                pattern = SOL0;
                break;
            case 1U:
                pattern = SOL1;
                break;
            case 2U:
                pattern = CHK1;
                break;
            case 3U:
                pattern = ROS1;
                break;
            default:
                pattern = CHK1;
        }
        expected_data = expected_data_pattern(pattern, victim);

        // LED3-6 on, configuration received, launch hammer
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x3C);

        // do the hammer
        do_hammer(ag1, ag2, victim, pattern, n_act);    

        // LED3-6 on, configuration received, launch hammer
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x28);

        // wait for data valid
        read_reg(DATA_VALID_REG, &status);
        while ((status & 0x00000003) != 3U) {
            // xil_printf("[WAITING] DATA_VALID: %u\r\n", status);
            read_reg(DATA_VALID_REG, &status);
        }
        
        // send sync to say that hammer has finished
        SEND_SYNC;

        // debug -- print configuration values to make sure they are correct
        xil_printf("ag1: %u ag2: %u victim: %u n_act: %u pattern: %u\r\n", ag1, ag2, victim, n_act, pattern_tmp);

        // read flips when peripheral is done
        read_reg(VICTIM_REG, &status);
        for (int i = 0; i < 128; i++) {
            // wait for data valid
            read_reg(DATA_VALID_REG, &status);
            while ((status & 0x00000003) != 3U) {
                // xil_printf("[WAITING] DATA_VALID: %u\r\n", status);
                read_reg(DATA_VALID_REG, &status);
            }
            // read data out
            read_reg(DATA_READ_127_96_REG, &data_out);
            if ((data_out ^ expected_data) != 0) {
                // xil_printf("[col%03d-w1]Expected %08X, found %08X\r\n", i, expected_data, data_out);
                flips_found += 1;
                print_flip_positions(data_out ^ expected_data, i, 0);
            }
            read_reg(DATA_READ_95_64_REG, &data_out);
            if ((data_out ^ expected_data) != 0) {
                // xil_printf("[col%03d-w2]Expected %08X, found %08X\r\n", i, expected_data, data_out);
                flips_found += 1;
                print_flip_positions(data_out ^ expected_data, i, 1);
            }
            read_reg(DATA_READ_63_32_REG, &data_out);
            if ((data_out ^ expected_data) != 0) {
                // xil_printf("[col%03d-w3]Expected %08X, found %08X\r\n", i, expected_data, data_out);
                flips_found += 1;
                print_flip_positions(data_out ^ expected_data, i, 2);
            }
            read_reg(DATA_READ_31_0_REG, &data_out);
            if ((data_out ^ expected_data) != 0) {
                // xil_printf("[col%03d-w4]Expected %08X, found %08X\r\n", i, expected_data, data_out);
                flips_found += 1;
                print_flip_positions(data_out ^ expected_data, i, 3);
            }
            // acknoledge data has been read
            SEND_ACK;
        }

        // LED0 and 7 on, test completed
        XGpio_DiscreteWrite(&led_gpio, LED_CHANNEL, 0x81);

        // signal end
        SEND_SYNC;
    }

    xil_printf("Program done.\r\n");
    return XST_SUCCESS;
}
