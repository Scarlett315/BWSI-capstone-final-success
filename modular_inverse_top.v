module modular_inverse_top #(
    parameter N = 2,
    parameter DW = 6,
    parameter ACC_W = 12
    )  (

    input wire clk,
    input wire rst_n,

    input wire start,
    output reg done,

    output wire [$clog2(N*N)-1:0] in_rd_addr, // key mem
    input wire [DW-1:0] in_rd_data,

    output wire out_w_en,
    output wire [$clog2(N*N)-1:0] out_w_addr, // inverse mem
    output wire [DW-1:0] out_w_data, 
    output wire invalid_key        // key invalid-- cannot compute modular inverse
);
    // FSM states
    localparam IDLE = 3'd0, LOAD = 3'd1, CALC_DET = 3'd2, FIND_ADJ = 3'd3, MULTIPLY_AND_WRITE = 3'd4;
    reg [2:0] state, next_state;

    // ------------------ wires/regs ---------------------
    wire calc_det_done, load_done, find_adj_done, mult_and_write_done; // controller

    // counters
    reg [$clog2(N*N)-1:0] load_counter; 
    reg [$clog2(N*N)-1:0] out_counter; 
    
    //loading *insert loading icon here*...
    assign in_rd_addr = load_counter;

    // register arrays for the key, adjugate, and inverse
    reg signed [DW-1:0] key_reg [0:3];
    reg signed [DW-1:0] adj_reg [0:3];
    reg signed [DW-1:0] inverse_reg [0:3];

    wire signed [DW-1:0] a, b, c, d; // key_reg
    assign a = key_reg[0]; // assign these wires for calcs :>
    assign b = key_reg[1];
    assign c = key_reg[2];
    assign d = key_reg[3];

    // determinant stuff
    reg [ACC_W-1:0] det;
    wire [DW-1:0] det_mod26, det_inv;
    wire signed [ACC_W-1:0] det_biased = det + 650; // add a multiple of 26 to det to handle negative values :>

    // multiplying
    wire signed [2*DW-1:0] inverse_mult_result;
    assign inverse_mult_result = det_inv * adj_reg[out_counter];

    wire [DW-1:0] inverse_mod_result; // for writing into the final matrix

    wire det_invalid;
    assign invalid_key = det_invalid;

    // ------------- instantiations ------------------ 

    // take the mod26 of the determinant
    mod26 #(
        .ACC_W(ACC_W),
        .DW(DW)
    ) mod26_det (
        .in (det_biased),
        .remainder (det_mod26)
    );    

    // modular inverse of determinant
    det_mod26_inv #( 
        .DW(DW)
        ) det_mod26_inv_inst (
        .det_mod(det_mod26),
        .det_mod_inv(det_inv),
        .invalid(det_invalid)
    );

    // take the mod26 of each value that will be in the output matrix
    mod26 #(
        .ACC_W(ACC_W),
        .DW(DW)
    ) mod26_final (
        .in (inverse_mult_result),
        .remainder (inverse_mod_result)
    );    
        
    // ------------------ FSM ----------------------

    always @(*) begin
        next_state = state;

        case (state)
            IDLE: begin
                if (start == 1'b1) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                if (load_done == 1'b1) begin
                    next_state = CALC_DET;
                end
            end

            CALC_DET: begin 
                if (calc_det_done == 1'b1) begin
                    next_state = FIND_ADJ;
                end
            end

            FIND_ADJ: begin

                if (find_adj_done == 1'b1) begin
                    next_state = MULTIPLY_AND_WRITE;
                end
            end

            MULTIPLY_AND_WRITE: begin

                if (mult_and_write_done == 1'b1) begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase

    end

    // --------------- control & calculations ----------------
    // https://crypto.interactive-maths.com/hill-cipher.html

    assign load_done = (state == LOAD && load_counter == 3);
    assign calc_det_done = (state == CALC_DET);
    assign find_adj_done = (state == FIND_ADJ);
    assign mult_and_write_done = (state == MULTIPLY_AND_WRITE && out_counter == 3);

    always @(posedge clk) begin
        if (!rst_n) begin
            load_counter <= 0;
            out_counter  <= 0;

            key_reg[0] <= 0;
            key_reg[1] <= 0;
            key_reg[2] <= 0;
            key_reg[3] <= 0;

            det <= 0;

            adj_reg[0] <= 0;
            adj_reg[1] <= 0;
            adj_reg[2] <= 0;
            adj_reg[3] <= 0;

            inverse_reg[0] <= 0;
            inverse_reg[1] <= 0;
            inverse_reg[2] <= 0;
            inverse_reg[3] <= 0;
        end else begin
            case (state)

                IDLE: begin
                    load_counter <= 0;
                    out_counter  <= 0;
                end

                LOAD: begin
                    key_reg[load_counter] <= in_rd_data;
                    load_counter <= load_counter + 1'b1;
                end

                CALC_DET: begin
                    det <= a * d - b * c;
                end

                FIND_ADJ: begin
                    adj_reg[0] <= d;
                    adj_reg[1] <= -b + 26;
                    adj_reg[2] <= -c + 26;
                    adj_reg[3] <= a;
                end

                MULTIPLY_AND_WRITE: begin
                    inverse_reg[out_counter] <= inverse_mod_result;
                    out_counter <= out_counter + 1'b1;
                end

            endcase
        end
    end

    // --------------- state update --------------
    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            done  <= 1'b0;
        end else begin
            state <= next_state;
            done  <= mult_and_write_done;
        end
    end

    // ------------- output logic -------------------
    assign out_w_addr = out_counter;
    assign out_w_data = inverse_mod_result;
    assign out_w_en = (state == MULTIPLY_AND_WRITE);

endmodule


// ---------- finds the modular inverse of the determinant % 26 using a look-up table -------------------
module det_mod26_inv # ( 
    parameter DW = 6
)(
    input wire [DW-1:0] det_mod, // AFTER %26
    output reg [DW-1:0] det_mod_inv, // modular inverse
    output reg invalid
);

    always @(*) begin
        invalid = 0;

        case (det_mod)
            1:  det_mod_inv = 1;
            3:  det_mod_inv = 9;
            5:  det_mod_inv = 21;
            7:  det_mod_inv = 15;
            9:  det_mod_inv = 3;
            11: det_mod_inv = 19;
            15: det_mod_inv = 7;
            17: det_mod_inv = 23;
            19: det_mod_inv = 11;
            21: det_mod_inv = 5;
            23: det_mod_inv = 17;
            25: det_mod_inv = 25;

            default: begin 
                det_mod_inv = 0;
                invalid = 1; // only determinants coprime with 26 will work
            end
        endcase
    end

endmodule