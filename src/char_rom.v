module char_rom #(
    parameter DATA_WIDTH = 35,     // Width of ROM data (35 bits for each character)
    parameter ADDR_WIDTH = 7,      // Address width
    parameter ADDR_MIN = 32,
    parameter ADDR_MAX = 127
)(
    input wire [ADDR_WIDTH-1:0] address,
    output wire [DATA_WIDTH-1:0] data
);

wire [DATA_WIDTH-1:0] d;

// a permutation of signals that allows the character ROM to be synthesized using fewer gates
assign data = { d[32], d[24], d[21], d[26], d[19], d[29], d[17], d[13], d[25], d[12],
                d[0],  d[14], d[4],  d[28], d[18], d[3],  d[31], d[22], d[1],  d[11],
                d[34], d[15], d[30], d[23], d[2],  d[8],  d[27], d[7],  d[33], d[20],
                d[10], d[9],  d[5],  d[16], d[6] };

reg [DATA_WIDTH-1:0] mem [0:ADDR_MAX-ADDR_MIN];

initial begin
    $readmemb("font.bin", mem);  // load char bitmaps from file
end

assign d = |address[ADDR_WIDTH-1:5] ? mem[address-ADDR_MIN] : '1;

endmodule
