#include "fir.h"

void __attribute__ ( ( section ( ".mprjram" ) ) ) initfir() {
	//initial your fir
	write(data_length_address,data_length);
	for(int i=0;i<N;i=i+1){
		write((tap_base+4*i),taps[i]);
	}
	reg_x = 0;
	reg_y = 0;
	out_buf[0] = 0;
}

int* __attribute__ ( ( section ( ".mprjram" ) ) ) fir(){
	// initialize fir (data_length, taps, ... etc)
	initfir();

	// check ap_idle = 1(bit[2] = 1), ap_start = 1;

	if (((read(ap_control_address) & (1<<2)) == 0x00000004)){
		write((ap_control_address),((read(ap_control_address) | 1)));
	}

	//write down your fir
	for(int register i=0;i<data_length;i=i+1){
		reg_x = i;
		
		if (read(ap_control_address) & (1<<4) == 0x00000010) write(input_address,reg_x);

		if (read(ap_control_address) & (1<<5) == 0x00000020) reg_y = read(output_address);
		
		out_buf[0] = reg_y;

		return out_buf;
	}
}
