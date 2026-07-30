module mac#(
    parameter DW    = 6,
    parameter ACC_W = 12
)(
    input clk,
    input rst_n,

    input signed [DW-1:0] a,
    input signed [DW-1:0] b,
    input valid_in,
    input clear_acc,

    output reg signed [ACC_W-1:0] acc_out,
    output reg valid_out
);
    reg signed [2*DW-1:0] product;
    reg valid_d;
    reg clear_d;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            product <= 1'b0;
            valid_d <= 1'b0;
            clear_d <= 1'b0;

            acc_out <= 1'b0;
            valid_out <= 1'b0;
        end
        else begin
            //Stage 1 (clock gated)
            valid_d <= valid_in;
            clear_d <= clear_acc;
            //product <= a*b;

            if(valid_in) begin
                product <= a*b; //only updates when valid data is high, also the ony change made
            end

            //Stage 2 (accumulator)
            if (valid_d) begin
                if (clear_d)
                    acc_out <= product;
                else
                    acc_out <= acc_out + product;

                valid_out <= 1'b1;
            end
            else begin
                valid_out <= 1'b0;
            end
        end
    end
endmodule
