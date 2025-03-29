`timescale 1ns / 1ps

module apb_slave #(
    parameter DW = 32,
    parameter AW = 32
)(
    input logic PCLK,
    input logic PRESETn,
    input logic PSEL,
    input logic PENABLE,
    input logic PWRITE,
    input logic [AW-1:0] PADDR,
    input logic [DW-1:0] PWDATA,
    output logic [DW-1:0] PRDATA,
    output logic PREADY
);

    logic [DW-1:0] mem [0:15]; // Simple memory storage

    always_ff @(posedge PCLK or negedge PRESETn) begin
        if (!PRESETn) begin
            PREADY <= 0;
            PRDATA <= 0;
        end else begin
            if (PSEL && PENABLE) begin
                PREADY <= 1;
                if (PWRITE) begin
                    mem[PADDR[3:0]] <= PWDATA; // Write operation
                end else begin
                    PRDATA <= mem[PADDR[3:0]]; // Read operation
                end
            end else begin
                PREADY <= 0;
            end
        end
    end
endmodule
