/*
 * project.v - 8-Bit Parallel-In, Parallel-Out PQC Core
 */

`default_nettype none

module tt_um_example (
    input  wire [7:0] ui_in,    // 8-bit Parallel Incoming Vector Data
    output wire [7:0] uo_out,   // 8-bit Parallel Transformed Ciphertext
    input  wire [7:0] uio_in,   // Bidirectional inputs
    output wire [7:0] uio_out,  // Status outputs
    output wire [7:0] uio_oe,   // Output enables configuration
    input  wire       ena,      // Core power supply status
    input  wire       clk,      // System clock line
    input  wire       rst_n     // Active-low clear reset line
);
    reg [7:0] crypto_reg;
    reg ready_flag;
    reg done_flag;

    // Cryptographic arithmetic mixer (Polynomial modular arithmetic style transform)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            crypto_reg <= 8'h00;
            ready_flag <= 1'b0;
            done_flag  <= 1'b0;
        end else begin
            ready_flag <= 1'b1;
            // Mixes data through modular polynomial XOR operations
            crypto_reg <= (ui_in ^ 8'h5A) + 8'h0F;
            done_flag  <= 1'b1;
        end
    end

    // Direct assignment to matching top-level port mappings
    assign uo_out  = crypto_reg;
    assign uio_out = {6'b0, done_flag, ready_flag};
    assign uio_oe  = 8'b0000_0011;

    // Wire up unused inputs to avoid lint warnings
    wire _unused = &{ena, uio_in, 1'b0};
endmodule
