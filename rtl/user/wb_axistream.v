module wb_axistream
(
    // Wishbone Slave ports (WB MI A)
    input wb_clk_i,
    input wb_rst_i,
    input wb_valid_i,
    input wb_we_i,
    input [31:0] wb_dat_i,
    input [31:0] wb_adr_i,
    output wb_ack_o,
    output [31:0] wb_dat_o,

    //AXI lite
    // coef write address
    input                       awready,
    output                       awvalid,
    output  [11:0]    awaddr,
    // coef write data
    input                       wready,
    output                       wvalid,
    output  [31:0]    wdata,
    // coef read address
    input                       arready,
    output                       arvalid,
    output  [11:0]    araddr,
    //coef read data
    output                       rready,
    input                       rvalid,
    input  [31:0]    rdata,

    //AXI stream
    //data
    output                      ss_tvalid,
    output  [31:0]    ss_tdata,
    input                       ss_tready,
    //check
    output                       sm_tready, 
    input                      sm_tvalid, 
    input   [31:0] sm_tdata
);
    wire write;
    wire read;
    assign write = (wb_valid_i && wb_we_i) ? 1:0;
    assign read = (wb_valid_i && !wb_we_i) ? 1:0;
    // lite
    assign awvalid = (write) ? 1:0;
    assign wvalid = (write) ? 1:0;
    assign arvalid = (read) ? 1:0;
    assign rready = 1;

    assign awaddr = (write && awready) ? wb_adr_i:0;
    assign araddr = (read && arready) ? wb_adr_i:0;

    assign wdata = (write && wready) ? wb_dat_i:0;
    assign wb_dat_o = (read && rready) ? rdata: 0;

    // stream
    assign ss_tvalid = 1;
    assign ss_tdata = (write && ss_tready) ? wb_dat_i: 0;

    assign sm_tready = 1;
    assign wb_dat_o = (read && sm_tvalid) ? sm_tdata: 0;

    assign wb_ready = (!wb_we_i && wb_valid_i && ss_tvalid) ? 1: 0;
    assign ss_tready = (!wb_we_i && wb_valid_i && ss_tvalid) ? 1: 0;
    
    assign wb_ack_o = (ss_tvalid || sm_tvalid || wvalid || rvalid) ? 1 : 0;

endmodule
