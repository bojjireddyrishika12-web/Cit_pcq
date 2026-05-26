/*
 * project.v - 8-Bit Parallel-In, Serial-Processed, Parallel-Out PQC Core
 * Meets the exact TinyTapeout 8-Input / 8-Output parallel pin specifications
 */

`default_nettype none

// =========================================================================
// 1. TINYTAPEOUT TOP-LEVEL WRAPPER (8-In, 8-Out Parallel Interface)
// =========================================================================
module tt_um_example (
    input  wire [7:0] ui_in,    // ui_in[7:0] = 8-bit Parallel Incoming Vector Data
    output wire [7:0] uo_out,   // uo_out[7:0] = 8-bit Parallel Transformed Ciphertext
    input  wire [7:0] uio_in,   // Bidirectional inputs (unused)
    output wire [7:0] uio_out,  // uio_out[0] = Ready status, uio_out[1] = Done status
    output wire [7:0] uio_oe,   // Output enables configuration matrix
    input  wire       ena,      // Core power supply status
    input  wire       clk,      // System clock line
    input  wire       rst_n     // Active-low clear reset line
);
    wire [7:0] internal_ciphertext;
    wire ready_flag;
    wire done_flag;

    // Connects straight to the serial-parallel hybrid engine below
    pqc_top_accelerator pqc_core (
        .clk(clk),
        .rst_n(rst_n),
        .parallel_in(ui_in),
        .ready(ready_flag),
        .done(done_flag),
        .ciphertext(internal_ciphertext)
    );

    // Drive parallel outputs and status lines
    assign uo_out  = internal_ciphertext;
    assign uio_out = {6'b0, done_flag, ready_flag};
    assign uio_oe  = 8'b0000_0011; // Pins 0 and 1 set as dedicated output status lanes

    wire _unused = &{ena, uio_in, 1'b0};
endmodule

// =========================================================================
// 2. CONTROL UNIT / FSM & INTERNAL SERIALIZATION CORE
// =========================================================================
module pqc_top_accelerator (
    input wire clk,
    input wire rst_n,
    input wire [7:0] parallel_in,
    output reg ready,
    output reg done,
    output reg [7:0] ciphertext
);
    localparam STATE_LOAD   = 3'd0;
    localparam STATE_SERIAL = 3'd1;
    localparam STATE_NTT    = 3'd2;
    localparam STATE_MOD    = 3'd3;
    localparam STATE_DONE   = 3'd4;

    reg [2:0] current_state, next_state;
    reg [3:0] bit_count;
    reg [7:0] internal_shift_reg;

    wire [7:0] w_rand_coeffs;
    wire [7:0] w_public_key;
    wire [7:0] w_secret_key;
    wire [15:0] w_arith_out;
    wire [7:0] w_ntt_out;
    wire [7:0] w_reduced_coeffs;

    rng_module u1_rng (
        .clk(clk), .rst_n(rst_n), .seed(internal_shift_reg[3:0]), .rand_coeffs(w_rand_coeffs)
    );

    key_gen_unit u2_keygen (
        .rand_coeffs(w_rand_coeffs), .public_key(w_public_key), .secret_key(w_secret_key)
    );

    poly_arithmetic_unit u3_arith (
        .poly_a(w_public_key), .poly_b(internal_shift_reg), .op_sel(1'b1), .poly_out(w_arith_out)
    );

    ntt_accelerator u4_ntt (
        .poly_in(internal_shift_reg), .ntt_out(w_ntt_out)
    );

    modular_reduction_unit u5_modred (
        .wide_data(w_arith_out), .reduced_coeffs(w_reduced_coeffs)
    );

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state      <= STATE_LOAD;
            bit_count          <= 4'd0;
            internal_shift_reg <= 8'h00;
        end else begin
            current_state <= next_state;
            case (current_state)
                STATE_LOAD: begin
                    internal_shift_reg <= parallel_in; 
                    bit_count          <= 4'd0;
                end
                STATE_SERIAL: begin
                    internal_shift_reg <= {internal_shift_reg[0], internal_shift_reg[7:1]};
                    bit_count          <= bit_count + 4'd1;
                end
                STATE_DONE: begin
                    bit_count          <= 4'd0;
                end
                default: begin
                    bit_count          <= 4'd0;
                end
            endcase
        end
    end

    always @(*) begin
        next_state = current_state;
        ready = 1'b0;
        done = 1'b0;

        case (current_state)
            STATE_LOAD: begin
                ready = 1'b1;
                next_state = STATE_SERIAL;
            end
            STATE_SERIAL: begin
                if (bit_count == 4'd7) next_state = STATE_NTT;
            end
            STATE_NTT: begin
                next_state = STATE_MOD;
            end
            STATE_MOD: begin
                next_state = STATE_DONE;
            end
            STATE_DONE: begin
                done = 1'b1; 
                next_state = STATE_LOAD;
            end
            default: next_state = STATE_LOAD;
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ciphertext <= 8'h00;
        end else if (current_state == STATE_MOD) begin
            ciphertext <= w_ntt_out;
        end
    end
endmodule

// =========================================================================
// 3. SUB-MODULE ARCHITECTURES
// =========================================================================
module rng_module (
    input wire clk,
    input wire rst_n,
    input wire [3:0] seed,
    output reg [7:0] rand_coeffs
);
    reg [7:0] lfsr;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            lfsr <= (seed == 0) ? 8'hA5 : {4'hA, seed};
        end else begin
            lfsr <= {lfsr[6:0], lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3]};
        end
    end
    always @(*) begin
        rand_coeffs = lfsr;
    end
endmodule

module key_gen_unit (
    input wire [7:0] rand_coeffs,
    output wire [7:0] public_key,
    output wire [7:0] secret_key
);
    assign secret_key = rand_coeffs;
    assign public_key = rand_coeffs ^ 8'h5A;
endmodule

module poly_arithmetic_unit (
    input wire [7:0] poly_a,
    input wire [7:0] poly_b,
    input wire op_sel, 
    output reg [15:0] poly_out
);
    integer i;
    reg [1:0] a_chunk, b_chunk;
    reg [3:0] prod_chunk;
    reg [1:0] sum_chunk;

    always @(*) begin
        poly_out = 0;
        for (i = 0; i < 4; i = i + 1) begin
            a_chunk = poly_a[i*2 +: 2];
            b_chunk = poly_b[i*2 +: 2];
            if (!op_sel) begin
                sum_chunk = a_chunk + b_chunk;
                poly_out[i*4 +: 4] = {2'b0, sum_chunk};
            end else begin
                prod_chunk = a_chunk * b_chunk;
                poly_out[i*4 +: 4] = prod_chunk;
            end
        end
    end
endmodule

module ntt_accelerator (
    input wire [7:0] poly_in,
    output wire [7:0] ntt_out
);
    assign ntt_out = {poly_in[1:0], poly_in[5:4], poly_in[3:2], poly_in[7:6]} ^ 8'h0F;
endmodule

module modular_reduction_unit (
    input wire [15:0] wide_data,
    output reg [7:0] reduced_coeffs
);
    integer i;
    reg [3:0] raw_val;
    reg [2:0] mod_val;

    always @(*) begin
        for (i = 0; i < 4; i = i + 1) begin
            raw_val = wide_data[i*4 +: 4];
            mod_val = raw_val % 5; 
            reduced_coeffs[i*2 +: 2] = mod_val[1:0];
        end
    end
endmodule
