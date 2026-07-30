module matmul_mod26_top #(
    parameter N = 2,
    parameter DW = 6,
    parameter ACC_W = $clog2(N * 25 * 25 + 1) + 1,

    parameter KEY_AND_INNER_DIM = N,
    parameter B_COLS = N,

    parameter ADDR_W =
        ((N * B_COLS) <= 1) ? 1 : $clog2(N * B_COLS)
)(
    input wire clk,
    input wire rst_n,

    input wire mode, // 0 = regular key, 1 = inverse key

    input wire start,
    output reg done,

    output wire [
        ((N * KEY_AND_INNER_DIM) <= 1
            ? 1
            : $clog2(N * KEY_AND_INNER_DIM)) - 1 : 0
    ] A_rd_addr,

    output wire [
        ((KEY_AND_INNER_DIM * B_COLS) <= 1
            ? 1
            : $clog2(KEY_AND_INNER_DIM * B_COLS)) - 1 : 0
    ] B_rd_addr,

    input wire signed [DW-1:0] A_rd_data,
    input wire signed [DW-1:0] B_rd_data,

    output wire product_mem_ld_enable,
    output wire [ADDR_W-1:0] product_mem_ld_addr,
    output wire [DW-1:0] product_mem_ld_data
);

    localparam ROW_W =
        (N <= 1) ? 1 : $clog2(N);

    localparam COL_W =
        (B_COLS <= 1) ? 1 : $clog2(B_COLS);

    localparam INNER_W =
        (KEY_AND_INNER_DIM <= 1)
            ? 1
            : $clog2(KEY_AND_INNER_DIM);

    localparam A_ADDR_W =
        ((2 * N * KEY_AND_INNER_DIM) <= 1)
            ? 1
            : $clog2(2 * N * KEY_AND_INNER_DIM);

    localparam B_ADDR_W =
        ((KEY_AND_INNER_DIM * B_COLS) <= 1)
            ? 1
            : $clog2(KEY_AND_INNER_DIM * B_COLS);

    localparam IDLE  = 3'b000;
    localparam FEED  = 3'b001;
    localparam WAIT  = 3'b010;
    localparam WRITE = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] current_state;
    reg [2:0] next_state;

    reg [ROW_W-1:0] i;
    reg [COL_W-1:0] j;
    reg [INNER_W-1:0] k;

    reg [ROW_W-1:0] output_i;
    reg [COL_W-1:0] output_j;

    wire [A_ADDR_W-1:0] regular_key_addr;
    wire [B_ADDR_W-1:0] plaintext_addr;

    wire signed [ACC_W-1:0] mac_result;
    wire mac_valid_out;

    wire [DW-1:0] rem_out;

    assign regular_key_addr =
        (i * KEY_AND_INNER_DIM) + k;

    assign plaintext_addr =
        (k * B_COLS) + j;

    // Regular key occupies the first N*N addresses.
    // Inverse key occupies the next N*N addresses.
    assign A_rd_addr = regular_key_addr;

    assign B_rd_addr = plaintext_addr;

    assign product_mem_ld_enable = (current_state == WRITE);

    assign product_mem_ld_addr = (output_i * B_COLS) + output_j;

    assign product_mem_ld_data = rem_out;

    wire mac_valid_in;
    wire mac_clear_acc;

    assign mac_valid_in =
        (current_state == FEED);

    // Clear the accumulator for the first term of each dot product.
    assign mac_clear_acc =
        (current_state == FEED) && (k == 0);

    mac #(
        .DW(DW),
        .ACC_W(ACC_W)
    ) mac_unit (
        .clk       (clk),
        .rst_n     (rst_n),

        .a         (A_rd_data),
        .b         (B_rd_data),
        .valid_in  (mac_valid_in),
        .clear_acc (mac_clear_acc),

        .acc_out   (mac_result),
        .valid_out (mac_valid_out)
    );

    mod26 #(
        .ACC_W(ACC_W),
        .DW(DW)
    ) mod26_unit (
        .in        (mac_result),
        .remainder (rem_out)
    );

    always @(*) begin
        next_state = current_state;

        case (current_state)
            IDLE: begin
                if (start)
                    next_state = FEED;
            end

            FEED: begin
                if (k == KEY_AND_INNER_DIM - 1)
                    next_state = WAIT;
            end

            // Wait one clock so the final product reaches
            // the MAC accumulator.
            WAIT: begin
                next_state = WRITE;
            end

            WRITE: begin
                if ((output_i == N - 1) &&
                    (output_j == B_COLS - 1))
                    next_state = DONE_STATE;
                else
                    next_state = FEED;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;

            i <= 0;
            j <= 0;
            k <= 0;

            output_i <= 0;
            output_j <= 0;

            done <= 1'b0;
        end
        else begin
            current_state <= next_state;
            done <= 1'b0;

            case (current_state)
                IDLE: begin
                    i <= 0;
                    j <= 0;
                    k <= 0;
                end

                FEED: begin
                    if (k == KEY_AND_INNER_DIM - 1) begin
                        // Save the address of the completed
                        // output matrix element.
                        output_i <= i;
                        output_j <= j;

                        k <= 0;
                    end
                    else begin
                        k <= k + 1'b1;
                    end
                end

                WAIT: begin
                    // The MAC finishes its final accumulation here.
                end

                WRITE: begin
                    // product_mem_ld_enable is high during this state.

                    if (!((output_i == N - 1) &&
                          (output_j == B_COLS - 1))) begin

                        if (j == B_COLS - 1) begin
                            j <= 0;
                            i <= i + 1'b1;
                        end
                        else begin
                            j <= j + 1'b1;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule

    //A[i][k] B[k][j] = C[i][j]

