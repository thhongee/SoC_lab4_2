`timescale 1ns / 1ps
module fir
#(
    parameter pADDR_WIDTH = 12,
    parameter pDATA_WIDTH = 32,
    parameter Tape_Num  = 11
)
(
    //AXI lite
    // coef write address
    output reg                      awready,
    input wire                      awvalid,
    input wire [pADDR_WIDTH-1:0]    awaddr,
    // coef write data
    output reg                      wready,
    input wire                      wvalid,
    input wire signed [pDATA_WIDTH-1:0]    wdata,
    // coef read address
    output reg                      arready,
    input wire                      arvalid,
    input wire [pADDR_WIDTH-1:0]    araddr,
    //coef read data
    input wire                      rready,
    output reg                      rvalid,
    output reg signed [pDATA_WIDTH-1:0]    rdata,
    //AXI stream
    //data
    input wire                      ss_tvalid,
    input wire                      ss_tlast,
    input wire signed [pDATA_WIDTH-1:0]    ss_tdata,
    output reg                      ss_tready,
    //check
    input  wire                     sm_tready, 
    output reg                     sm_tvalid, 
    output reg                     sm_tlast,
    output reg signed [(pDATA_WIDTH-1):0] sm_tdata, 

    // bram for tap RAM
    output reg [3:0]                tap_WE,
    output reg                      tap_EN,
    output reg signed [(pDATA_WIDTH-1):0]  tap_Di,
    output reg [(pADDR_WIDTH-1):0]  tap_A,
    input  wire signed [(pDATA_WIDTH-1):0] tap_Do,

    // bram for data RAM
    output reg [3:0]                data_WE,
    output reg                      data_EN,
    output reg signed [(pDATA_WIDTH-1):0]  data_Di,
    output reg [(pADDR_WIDTH-1):0]  data_A,
    input  wire signed [(pDATA_WIDTH-1):0] data_Do,

    // clk & reset
    input  wire           axis_clk,
    input  wire           axis_rst_n
);
//////////////////////////////////////////////////
parameter ZERO = 3'b000;
parameter ONE = 3'b001;
parameter TWO = 3'b010;
parameter THREE = 3'b011;
parameter FOUR = 3'b100;
parameter FIVE = 3'b101;
parameter SIX = 3'b110;
parameter SEVEN = 3'b111;
// FSM start ///////////////////////////////////////
reg [2:0] cstate;
reg [2:0] nstate;
reg acc_done;
always @(posedge axis_clk or negedge axis_rst_n)begin
    if(!axis_rst_n)  cstate <= ZERO;
    else            cstate <= nstate;
end

///////////////////////////////////////////////////
reg [9:0] total_count;                  // MAX 600
reg [3:0] count;                        // MAX 11
reg [pADDR_WIDTH-1:0] data_index;       //[11:0]
reg acc_wait;
reg check_wait;
///////////////////////////////////////////////////
always @(*)begin
    case(cstate)
        ZERO:begin
            if(start)           nstate = ONE;
            else if(arvalid)    nstate = SEVEN; 
            else                nstate = ZERO;
        end ONE: begin
            // write in BRAM
            if(ss_tvalid && ss_tready)  nstate = TWO;
            else                        nstate = ONE;
        end TWO: begin
            // read from BRAM and cal acc
            if(!acc_wait)            nstate = TWO;
            else                    nstate = THREE;
        end THREE: begin
            nstate = FOUR; 
        end FOUR: begin
            if((total_count < 11 & data_index == 12'h00) || total_count >= 11 & count == 11) nstate = FIVE;
            else        nstate = TWO;
        end FIVE: begin
            nstate = SIX;
        end SIX: begin
            // the last data
            if(total_count == 600 || arvalid)      nstate = SEVEN;
            else                        nstate = ONE;
        end SEVEN: begin
            // finish
            if(awvalid && wvalid)       nstate = ZERO; 
            else if(check_wait)         nstate = ONE; 
            else                        nstate = SEVEN;
        end
        default:begin
            nstate = ZERO;
        end
    endcase
end
///////////////////////////////////////////////////

// reset reg ////////////////////////////////////////////
reg [pADDR_WIDTH-1:0] index;            //[11:0]
reg [pADDR_WIDTH-1:0] coef_index;       //[11:0]
reg [pDATA_WIDTH-1:0] acc;              //[31:0]
reg bram_ready;
always @(posedge axis_clk)begin
    if(cstate == ZERO)begin
        index <= 12'h00;
        data_index <= 12'h00;
        coef_index <= 12'h00;
        acc <= 0;
        total_count <= 0;
        count <= 0;
        acc_wait <= 0;
        check_wait <= 0;
    end
end

// axis_rst_n ///////////////////////////////////////////
always @(negedge axis_rst_n)begin
    if(!axis_rst_n)begin
        bram_ready <= 0;
        ss_tready <= 0;
        awready <= 0;
        wready <= 0;
        arready <= 0;
        rvalid <= 0;
        sm_tvalid <= 0;
    end
end

// AXI lite //////////////////////////////////////////////
//tap_num from testbench//////////////////
reg start;
reg data_length;
always @(posedge axis_clk)begin
    if(cstate == ZERO)begin
        if(awvalid && wvalid)begin
            awready <= 1'b1;
            wready <= 1'b1;
        end
        if(wvalid && wready && awvalid && awready) begin
            if(awaddr == 12'h30)begin
                start <= 1;
            end else if(awaddr == 12'h34) begin
                data_length <= wdata;
            end else begin
                // set tap
                tap_WE <= 4'b1111;
                tap_EN <= 1'b1;
                tap_A <= awaddr;
                tap_Di <= wdata;
                awready <= 1'b0;
                wready <= 1'b0;
            end
        end
    end
end

// check tap & ap ////////////////////////////////////////////////
always @(posedge axis_clk or negedge axis_rst_n)begin
    if(cstate == SEVEN)begin
        if(arvalid)begin
            arready <= 1'b1;
            tap_WE <= 4'b0000;
            tap_EN <= 1'b1;
            tap_A <= araddr;
        end
        if(arready && arvalid)begin
            arready <= 0;
            if(total_count == 600 && araddr == 12'h30)      rdata <= 32'h0000_0006;
            else if(total_count != 600 && araddr == 12'h30) rdata <= 32'h0000_0000;
            else                                            rdata <= tap_Do;

            bram_ready <= 1;
            if(bram_ready) begin
                rvalid <= 1'b1;
                bram_ready <= 0;
            end
        end
        if(rvalid && rready)begin
            if(total_count != 600 && araddr == 12'h30)      check_wait <= 1;
            rvalid <= 1'b0;
            arready <= 1'b0;
        end
    end
end

always @(posedge axis_clk)begin
    if(check_wait)  check_wait <= 0;
end

// AXI stream data in FIR///////////////////////////
// write data from testbench into BRAM//////////////////
always @(posedge axis_clk)begin
    if(cstate == ONE)begin
        if(ss_tvalid)begin
            ss_tready <= 1'b1;
        end
        if(ss_tvalid && ss_tready)begin
            // send data in BRAM
            data_EN <= 1'b1;
            data_WE <= 4'b1111;
            data_A <= index;
            data_Di <= ss_tdata;
            // handshake
            ss_tready <= 0;

            // count how many data has been sent in BRAM
            total_count <= total_count + 1;
            // reset index if index exceed 11
            if(index == 12'h28)     index <= 12'h00;
            else                    index <= index + 4;
            // get start data & coef address
            data_index <= index;
            coef_index <= 12'h00;
            // ready for the first coef
            tap_EN <= 1;
            tap_WE <= 4'b0000;
            tap_A <= coef_index;
            // initial 
            count <= 0;
            acc <= 0;
        end
    end
end

// READ data from BRAM////////////////////////////////
always @(posedge axis_clk)begin
    if(cstate == TWO)begin
        if(!acc_wait) begin
            acc_wait <= 1;
            // get coef
            tap_EN <= 1;
            tap_WE <= 4'b0000;
            tap_A <= coef_index;
            // get data
            data_EN <= 1;
            data_WE <= 4'b0000;
            data_A <= data_index;
        end else acc_wait <= 0;
    end
end

always @(posedge axis_clk)begin
    if(cstate == THREE)begin
        // calculate acc
        acc = data_Do * tap_Do + acc;
        // count 11 yet ?
        count = count + 1;
    end
end

// determine first 10 data
always @(posedge axis_clk)begin
    if(cstate == FOUR)begin
        if(total_count < 11) begin
            if(data_index == 12'h00)begin
                coef_index <= 12'h00;
                
            end else begin
                coef_index <= coef_index + 4;
                data_index <= data_index - 4;
            end
        end else begin
            if(count == 11)begin
                coef_index <= 12'h00;
            end else begin
                coef_index <= coef_index + 4;
                if(data_index == 12'h00)    data_index <= 12'h28;
                else                        data_index <= data_index - 4;
            end
        end
    end
end

always @(posedge axis_clk)begin
    if(cstate == FIVE)begin
        sm_tvalid <= 1;
        sm_tdata <= acc;
    end
end

always @(posedge axis_clk)begin
    if(cstate == SIX)begin
        if(sm_tready && sm_tvalid)begin
            sm_tvalid <= 0;
        end
        if(total_count == 600)begin
            start <= 0;
        end
    end
end

endmodule