module hill_cipher_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire start,

    input  wire mode_in, // 0 = encrypt, 1 = decrypt

    input  wire load_done,
    input  wire inverse_done,
    input  wire mult_done,
    input  wire write_done,

    output reg  loadEnable,
    output reg  inverseBegin,
    output reg  matmulBegin,
    output reg  writeEnable,

    output reg  busy,
    output reg  done,

    output reg  mode
);

    localparam IDLE     = 3'b000;
    localparam LOAD     = 3'b001;
    localparam INVERSE  = 3'b010;
    localparam MULTIPLY = 3'b011;
    localparam WRITE    = 3'b100;

    reg [2:0] currentState;
    reg [2:0] nextState;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            currentState <= IDLE;
        else
            currentState <= nextState;
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            mode <= 1'b0;
        else if ((currentState == IDLE) && start)
            mode <= mode_in;
    end

    always @(*) begin
        nextState = currentState;

        case (currentState)

            IDLE: begin
                if (start)
                    nextState = LOAD;
            end

            LOAD: begin
                if (load_done) begin
                    if (mode)
                        nextState = INVERSE;
                    else
                        nextState = MULTIPLY;
                end
            end

            INVERSE: begin
                if (inverse_done)
                    nextState = MULTIPLY;
            end

            MULTIPLY: begin
                if (mult_done)
                    nextState = WRITE;
            end

            WRITE: begin
                if (write_done)
                    nextState = IDLE;
            end

            default: begin
                nextState = IDLE;
            end

        endcase
    end

    always @(*) begin
        loadEnable  = 1'b0;
        inverseBegin = 1'b0;
        matmulBegin = 1'b0;
        writeEnable = 1'b0;
        busy        = 1'b0;
        done        = 1'b0;

        case (currentState)

            IDLE: begin
                busy = 1'b0;
            end

            LOAD: begin
                busy = 1'b1;
                loadEnable = 1'b1;

                if (load_done && !mode)
                    matmulBegin = 1'b1;

                if (load_done && mode)
                    inverseBegin = 1'b1;
            end

            INVERSE: begin
                busy = 1'b1;

                if (inverse_done)
                    matmulBegin = 1'b1;
            end

            MULTIPLY: begin
                busy = 1'b1;

                if (mult_done)
                    writeEnable = 1'b1;
            end

            WRITE: begin
                busy = 1'b1;
                writeEnable = 1'b1;

                if (write_done)
                    done = 1'b1;
            end

            default: begin
                busy = 1'b0;
            end

        endcase
    end

endmodule