/*
 * project.v — Consolidated Parallel Hamming ECC Protection Core
 * Fully matching the default TinyTapeout Template module name
 */

`default_nettype none

// =========================================================================
// 1. TINYTAPEOUT TOP-LEVEL WRAPPER (Name kept exactly as default)
// =========================================================================
module tt_um_example (
    input  wire [7:0] ui_in,    // ui_in[7:0] = 8-bit Parallel Data Input Packet
    output wire [7:0] uo_out,   // uo_out[7:0] = 8-bit Parallel Corrected Data Output
    input  wire [7:0] uio_in,   // Bidirectional input path (unused)
    output wire [7:0] uio_out,  // uio_out[0] = Error Detected, uio_out[1] = Ready flag
    output wire [7:0] uio_oe,   // Bidirectional pin configurations
    input  wire       ena,      // Powered up status indicator
    input  wire       clk,      // System clock
    input  wire       rst_n     // Active-low reset
);
    wire err_detected;
    wire ready_pulse;

    // Connects straight to our parallel controller core below
    serial_alu_ctrl ecc_controller (
        .CLK(clk),
        .RST_n(rst_n),
        .Parallel_in(ui_in), 
        .Data_out(uo_out),   
        .Error_Flag(err_detected),
        .Ready(ready_pulse)
    );

    assign uio_out = {6'b0, ready_pulse, err_detected}; // uio[0]=Error, uio[1]=Ready
    assign uio_oe  = 8'b0000_0011;                       // Configure pins 0 and 1 as outputs

    wire _unused = &{ena, uio_in, 1'b0};
endmodule

// =========================================================================
// 2. PARALLEL CONTROLLER CORE
// =========================================================================
module serial_alu_ctrl (
    input  wire       CLK,
    input  wire       RST_n,
    input  wire [7:0] Parallel_in, 
    output wire [7:0] Data_out,    
    output wire       Error_Flag,  
    output wire       Ready        
);
    reg [7:0] input_latch;
    reg [7:0] output_reg;
    reg       err_reg;
    reg       ready_reg;

    wire [7:0] corrected_data;
    wire       error_found;

    // Connect to the combinational ECC calculations core
    alu_7b u_ecc_engine (
        .raw_packet     (input_latch),
        .clean_packet   (corrected_data),
        .error_detected (error_found)
    );

    always @(posedge CLK) begin
        if (!RST_n) begin
            input_latch <= 8'h00;
            output_reg  <= 8'h00;
            err_reg     <= 1'b0;
            ready_reg   <= 1'b1; // Default ready high under reset state conditions
        end else begin
            input_latch <= Parallel_in;   // Step 1: Ingest parallel inputs
            output_reg  <= corrected_data;// Step 2: Auto-repair single bit anomalies
            err_reg     <= error_found;
            ready_reg   <= 1'b1;
        end
    end

    assign Data_out   = output_reg;
    assign Error_Flag = err_reg;
    assign Ready      = ready_reg;
endmodule

// =========================================================================
// 3. COMBINATIONAL ECC MATH CORE
// =========================================================================
module alu_7b (
    input  wire [7:0] raw_packet,     
    output reg  [7:0] clean_packet,   
    output reg        error_detected  
);
    reg p1, p2, p4; // Syndrome checkers

    always @(*) begin
        // Fast matrix evaluation over all 8 parallel inputs at once
        p1 = raw_packet[0] ^ raw_packet[1] ^ raw_packet[3] ^ raw_packet[4] ^ raw_packet[6];
        p2 = raw_packet[0] ^ raw_packet[2] ^ raw_packet[3] ^ raw_packet[5] ^ raw_packet[6];
        p4 = raw_packet[1] ^ raw_packet[2] ^ raw_packet[3] ^ raw_packet[7];

        if (p1 || p2 || p4) begin
            error_detected = 1'b1;
            clean_packet = raw_packet;
            // Instantly toggle back the flipped bit value
            if (p1 && p2 && !p4)  clean_packet[0] = ~raw_packet[0]; 
            if (p1 && !p2 && p4)  clean_packet[1] = ~raw_packet[1]; 
            if (!p1 && p2 && p4)  clean_packet[2] = ~raw_packet[2]; 
            if (p1 && p2 && p4)   clean_packet[3] = ~raw_packet[3]; 
        end else begin
            error_detected = 1'b0;
            clean_packet   = raw_packet; 
        end
    end
endmodule
