#ifndef __FIR_H__
#define __FIR_H__

#include <stdint.h>
#define N  11

int data_length = 64;
int taps[N] = {0,-10,-9,23,56,63,56,23,-9,-10,0};
int reg_x;
int reg_y;
int out_buf[1];

#define write(address,data) (*(volatile int32_t*) address) = data
#define read(address) (*(volatile int32_t*) address)
#define ap_control_address  0x30000000
#define data_length_address 0x30000010
#define tap_base            0x30000020
#define input_address       0x30000080
#define output_address      0x30000084

#endif
