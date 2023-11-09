`default_nettype none

module user_proj_example #(
    parameter BITS = 32,
    parameter DELAYS=10
)(
`ifdef USE_POWER_PINS
    inout vccd1,	// User area 1 1.8V supply
    inout vssd1,	// User area 1 digital ground
`endif

    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wbs_stb_i,
    input wbs_cyc_i,
    input wbs_we_i,
    input [3:0] wbs_sel_i,
    input [31:0] wbs_dat_i,
    input [31:0] wbs_adr_i,
    output wbs_ack_o,
    output [31:0] wbs_dat_o,

    // Logic Analyzer Signals
    input  [127:0] la_data_in,
    output [127:0] la_data_out,
    input  [127:0] la_oenb,

    // IOs
    input  [`MPRJ_IO_PADS-1:0] io_in,
    output [`MPRJ_IO_PADS-1:0] io_out,
    output [`MPRJ_IO_PADS-1:0] io_oeb,

    // IRQ
    output [2:0] irq
);
    wire clk;
    wire rst;

    wire [`MPRJ_IO_PADS-1:0] io_in;
    wire [`MPRJ_IO_PADS-1:0] io_out;
    wire [`MPRJ_IO_PADS-1:0] io_oeb;

    // wdata and rdata for bram
    wire [31:0] rdata; 
    wire [BITS-1:0] count;

    // set valid, ready and delay signal
    wire valid_lab3;
    wire valid_lab4;
    wire [3:0] wstrb;
    wire [31:0] la_write;
    wire decode_lab3;
    wire decode_lab4;
    // WB
    wire ack;
    wire [31:0] dat_o;

    //tap RAM
    wire [3:0] tap_WE_w;
    wire tap_EN_w;
    wire [31:0] tap_Di_w;
    wire [11:0] tap_A_w;
    wire [31:0] tap_Do_w;

    //data RAM
    wire [3:0] data_WE_w;
    wire data_EN_w;
    wire [31:0] data_Di_w;
    wire [11:0] data_A_w;
    wire [31:0] data_Do_w;
    
    //axi-lite
    wire awready_w;
	wire awvalid_w;
	wire [11:0] awaddr_w;
	wire wready_w;
	wire wvalid_w;
	wire [31:0] wdata_w;
	wire arready_w;
	wire arvalid_w;
	wire [11:0] araddr_w;
	wire rready_w;
	wire rvalid_w;
	wire [31:0] rdata_w;
    
    //axi-stream
    wire ss_tvalid_w;
	wire [31:0] ss_tdata_w;
	wire ss_tready_w;
	wire sm_tready_w; 
	wire sm_tvalid_w; 
	wire [31:0] sm_tdata_w; 

    reg bram_ready;
    reg fir_ready;
    reg [BITS-17:0] delayed_count;

    // WB MI A
    assign valid_lab3 = wbs_cyc_i && wbs_stb_i && decode_lab3;
    assign valid_lab4 = wbs_cyc_i && wbs_stb_i && decode_lab4;
    assign wstrb = wbs_sel_i & {4{wbs_we_i}};
    assign wbs_dat_o =   (decode_lab3) ? dat_o:
                        (decode_lab4) ? rdata:0;

    assign wbs_ack_o =   (decode_lab3) ? ack:
                        (decode_lab4) ? bram_ready:0;
    
    // IO
    assign io_out = count;
    assign io_oeb = {(`MPRJ_IO_PADS-1){rst}};
    // IRQ
    assign irq = 3'b000;	// Unused
    // LA
    assign la_data_out = {{(127-BITS){1'b0}}, count};
    // Assuming LA probes [63:32] are for controlling the count register  
    assign la_write = ~la_oenb[63:32] & ~{BITS{valid_lab4}};
    // Assuming LA probes [65:64] are for controlling the count clk & reset  
    assign clk = (~la_oenb[64]) ? la_data_in[64]: wb_clk_i;
    assign rst = (~la_oenb[65]) ? la_data_in[65]: wb_rst_i;

    // Decoded wishbone address
    assign decode_lab3 = (wbs_adr_i[31:20] == 12'h300) ? 1'b1: 1'b0;
    assign decode_lab4 = (wbs_adr_i[31:20] == 12'h380) ? 1'b1: 1'b0;

    always @(posedge clk) begin
        if (rst) begin
            bram_ready <= 1'b0;
            delayed_count <= 16'b0;
        end else begin
            bram_ready <= 1'b0;
            if (valid_lab4 && !bram_ready) begin
                if (delayed_count == DELAYS) begin
                    delayed_count <= 16'b0;
                    bram_ready <= 1'b1;
                end else begin
                    delayed_count <= delayed_count + 1;
                end
            end
        end
    end
    
    wb_axistream wb_axistream(
    
	.wb_clk_i(wb_clk_i),
	.wb_rst_i(wb_rst_i),
    	.wb_valid_i(valid_lab3),
	.wb_we_i(wstrb),
	.wb_dat_i(wbs_dat_i),
	.wb_adr_i(wbs_adr_i),
	.wb_ack_o(ack),
	.wb_dat_o(dat_o),

	.awready(awready_w),
	.awvalid(awvalid_w),
	.awaddr(awaddr_w),
	.wready(wready_w),
	.wvalid(wvalid_w),
	.wdata(wdata_w),
	.arready(arready_w),
	.arvalid(arvalid_w),
	.araddr(araddr_w),
	.rready(rready_w),
	.rvalid(rvalid_w),
	.rdata(rdata_w),

	.ss_tvalid(ss_tvalid_w),
	.ss_tdata(ss_tdata_w),
	.ss_tready(ss_tready_w),
	.sm_tready(sm_tready_w), 
	.sm_tvalid(sm_tvalid_w), 
	.sm_tdata(sm_tdata_w) 
);
    fir fir(
    //AXI lite
    // coef write address
    .awready(awready_w),
    .awvalid(awvalid_w),
    .awaddr(awaddr_w),
    // coef write data
    .wready(wready_w),
    .wvalid(wvalid_w),
    .wdata(wdata_w),
    // coef read address
    .arready(arready_w),
    .arvalid(arvalid_w),
    .araddr(araddr_w),
    //coef read data
    .rready(rready_w),
    .rvalid(rvalid_w),
    .rdata(rdata_w),
    //AXI stream
    //data
    .ss_tvalid(ss_tvalid_w),
    .ss_tlast(),
    .ss_tdata(ss_tdata_w),
    .ss_tready(ss_tready_w),
    //check
    .sm_tready(sm_tready_w), 
    .sm_tvalid(sm_tvalid_w), 
    .sm_tlast(),
    .sm_tdata(sm_tdata_w), 

    // bram for tap RAM
    .tap_WE(tap_WE_w),
    .tap_EN(tap_EN_w),
    .tap_Di(tap_Di_w),
    .tap_A(tap_A_w),
    .tap_Do(tap_Do_w),

    // bram for data RAM
    .data_WE(data_WE_w),
    .data_EN(data_EN_w),
    .data_Di(data_Di_w),
    .data_A(data_A_w),
    .data_Do(data_Do_w),

    // clk & reset
    .axis_clk(wb_clk_i),
    .axis_rst_n(wb_rst_i)
    );
    bram user_bram (
        .CLK(clk),
        .WE0(wstrb),
        .EN0(valid_lab4),
        .Di0(wbs_dat_i),
        .Do0(rdata),
        .A0(wbs_adr_i)
    );

    bram data_bram (
    	.CLK(wb_clk_i),
        .WE0(data_WE_w),
        .EN0(data_EN_w),
        .Di0(data_Di_w),
        .Do0(data_Do_w),
        .A0(data_A_w)
    );

    bram tap_bram (
    	 .CLK(wb_clk_i),
        .WE0(tap_WE_w),
        .EN0(tap_EN_w),
        .Di0(tap_Di_w),
        .Do0(tap_Do_w),
        .A0(tap_A_w)
    );


endmodule

`default_nettype wire
