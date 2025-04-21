module apb_design #(
  parameter DW = 32,
  parameter AW = 12
)(
  input              PCLK,
  input              PRESETn,
  input  [AW-1:0]    PADDR,     // long term
  input              PSEL,      // xtn specific
  input              PENABLE,   // xtn specific
  input              PWRITE,    // long term
  input  [DW-1:0]    PWDATA,    // long term
  output reg [DW-1:0] PRDATA,   // long term
  output             PREADY,    // xtn specific
  output             PSLVERR    // long term
);

  reg [DW-1:0] mem [0:15];

  assign PREADY  = 1'b1;
  assign PSLVERR = 1'b0;
  wire [3:0] addr_index = PADDR[5:2];

  always @(posedge PCLK or negedge PRESETn) begin
    if (!PRESETn)
      PRDATA <= 0;
    else if (PSEL && PENABLE && !PWRITE)
      PRDATA <= mem[addr_index];
    else if (PSEL && PENABLE && PWRITE)
      mem[addr_index] <= PWDATA;
  end

endmodule
