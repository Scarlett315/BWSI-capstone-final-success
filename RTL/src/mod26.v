//takes the modulous 26 of an input and outputs that value to final answer matrix?
module mod26#(
    parameter ACC_W = 12, //sum of products width, 12 bits
    parameter DW = 6 // input operand width (INT6)
)(

    input wire [ACC_W-1:0] in, //external input
    output wire [DW-1:0] remainder //external output
);
    // Internal variables for the optimized combinational subtraction loop
    reg [ACC_W+4:0] temp_rem; 
    reg [DW-1:0]    comb_mod26;
    integer         i;

    // Combinational long-division array (Synthesizes to clean subtractor muxes)
    always @(*) begin
        temp_rem = 0;
        
        for (i = ACC_W - 1; i >= 0; i = i - 1) begin
            // Shift left by 1 and pull in the next bit from the input wire
            temp_rem = (temp_rem << 1);
            temp_rem[0] = in[i];
            
            // If the local accumulator hits or exceeds 26, subtract it instantly
            if (temp_rem >= 26) begin
                temp_rem = temp_rem - 26;
            end
        end
        comb_mod26 = temp_rem[DW-1:0];
    end

    assign remainder = comb_mod26; // Directly assign the combinational result to the output

endmodule