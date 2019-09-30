`timescale 1ps / 1ps 
`include "cache_consts.svh"
`include "cache_types.svh"

// localmem.sv 
// llc memory 
// author: Joseph Zuckerman

module localmem (clk, rst, rd_set, rd_en, wr_addr, wr_data_line, wr_data_tag, wr_data_sharers, wr_data_owner, wr_data_hprot, wr_data_dirty_bit, wr_data_evict_way, wr_data_state, wr_en, rd_data_line, rd_data_tag, rd_data_sharers, rd_data_owner, rd_data_hprot, rd_data_dirty_bit, rd_data_evict_way, rd_data_state);  
    input logic clk, rst; 

    input llc_set_t rd_set;
    input logic rd_en;

    input llc_set_t wr_set;
    input llc_way_t wr_way;
    input line_t wr_data_line;
    input llc_tag_t wr_data_tag;
    input sharers_t wr_data_sharers; 
    input owner_t wr_data_owner; 
    input hprot_t wr_data_hprot; 
    input logic wr_data_dirty_bit;  
    input llc_way_t wr_data_evict_way;  
    input  llc_state_t wr_data_state;
    input logic wr_en;

    output line_t rd_data_line[`NUM_PORTS];
    output llc_tag_t rd_data_tag[`NUM_PORTS];
    output sharers_t rd_data_sharers[`NUM_PORTS];
    output owner_t rd_data_owner[`NUM_PORTS];
    output hprot_t rd_data_hprot[`NUM_PORTS];
    output logic rd_data_dirty_bit[`NUM_PORTS];
    output llc_way_t rd_data_evict_way[`NUM_PORTS];
    output llc_state_t rd_data_state[`NUM_PORTS];

    owner_t rd_data_owner_tmp[`NUM_PORTS][`OWNER_BRAMS_PER_WAY];
    sharers_t rd_data_sharers_tmp[`NUM_PORTS][`SHARERS_BRAMS_PER_WAY]; 
    hprot_t rd_data_hprot_tmp[`NUM_PORTS][`HPROT_BRAMS_PER_WAY]; 
    logic rd_data_sharers_tmp[`NUM_PORTS][`DIRTY_BIT_BRAMS_PER_WAY]; 
    llc_state_t rd_data_state_tmp[`NUM_PORTS][`STATE_BRAMS_PER_WAY]; 
    llc_tag_t rd_data_tag_tmp[`NUM_PORTS][`TAG_BRAMS_PER_WAY]; 
    llc_way_t rd_data_evict_way_tmp[`NUM_PORTS][`EVICT_WAY_BRAMS_PER_WAY]; 
    sharers_t rd_data_line_tmp[`NUM_PORTS][`LINE_BRAMS_PER_WAY]; 
  
    //write enable decoder for ways 
    logic wr_en_port[`NUM_PORTS];
    always_comb begin 
        for (int i = 0; i < `NUM_PORTS; i++) begin 
            wr_en_port[i] = 1'b0; 
            if (wr_way == i) begin 
                wr_en_port[i] == 1'b1;
            end 
        end
    end

    logic wr_en_owner_bank[`OWNER_BRAMS_PER_WAY];
    logic wr_en_sharers_bank[`SHARERS_BRAMS_PER_WAY];
    logic wr_en_hprot_bank[`HPROT_BRAMS_PER_WAY];
    logic wr_en_dirty_bit_bank[`DIRTY_BIT_BRAMS_PER_WAY];
    logic wr_en_state_bank[`STATE_BRAMS_PER_WAY];
    logic wr_en_tag_bank[`TAG_BRAMS_PER_WAY];
    logic wr_en_evict_way_bank[`EVICT_WAY_BRAMS_PER_WAY];
    logic wr_en_line_bank[`LINE_BRAMS_PER_WAY];

    always_comb begin 
            for (int j = 0; j < `OWNER_BRAMS_PER_WAY; j++) begin 
                wr_en_owner_bank[j] = 1'b0;
                if (`OWNER_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS)]) begin 
                    wr_en_owner_bank[j] = 1'b1;
                end
            end 
            for (int j = 0; j < `SHARERS_BRAMS_PER_WAY; j++) begin 
                wr_en_sharers_bank[j] = 1'b0;
                if (`SHARERS_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS)]) begin 
                    wr_en_sharers_bank[j] = 1'b1;
                end
            end
            for (int j = 0; j < `HPROT_BRAMS_PER_WAY; j++) begin 
                wr_en_hprot_bank[j] = 1'b0;
                if (`HPROT_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS)]) begin 
                    wr_en_hprot_bank[j] = 1'b0;
                end
            end 
            for (int j = 0; j < `DIRTY_BIT_BRAMS_PER_WAY; j++) begin 
                wr_en_dirty_bit_bank[j] = 1'b0;
                if (`DIRTY_BIT_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS)]) begin 
                    wr_en_dirty_bit_bank[j] = 1'b1;
                end
            end 
            for (int j = 0; j < `STATE_BRAMS_PER_WAY; j++) begin 
                wr_en_state_bank[j] = 1'b0;
                if (`STATE_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS)]) begin 
                    wr_en_state_bank[j] = 1'b1;
                end
            end 
            for (int j = 0; j < `TAG_BRAMS_PER_WAY; j++) begin 
                wr_en_tag_bank[j] = 1'b0;
                if (`TAG_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS)]) begin 
                    wr_en_tag_bank[j] = 1'b1;
                end
            end 
            for (int j = 0; j < `EVICT_WAY_BRAMS_PER_WAY; j++) begin 
                wr_en_evict_way_bank[j] = 1'b0;
                if (`EVICT_WAY_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS)]) begin 
                    wr_en_evict_way_bank[j] = 1'b1;
                end
            end 
            for (int j = 0; j < `LINE_BRAMS_PER_WAY; j++) begin 
                wr_en_line_bank[j] = 1'b0;
                if (`LINE_BRAMS_PER_WAY == 1 || j == wr_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS)]) begin 
                    wr_en_line_bank[j] = 1'b1;
                end
            end     
    end

    genvar i, j, k; 
    generate begin: memories
        for (i = 0; i < (`NUM_PORTS / 2); i++) begin 
            //owner memory
            //need 4 bits for owner - 4096x4 BRAM
            for (j = 0; j < `OWNER_BRAMS_PER_WAY; j++) begin
                BRAM_4096x4 owner_bram(
                    .CLK(clk), 1
                    .A0({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_owner), 
                    .Q0(rd_data_owner_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_owner_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_owner), 
                    .Q1(rd_data_owner_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_owner_bank[j]), 
                    .CE1(rd_en));
            end
            //sharers memory 
            //need 16 bits for sharers - 1024x16 BRAM
            for (j = 0; j < `SHARERS_BRAMS_PER_WAY; j++) begin
                BRAM_1024x16 sharers_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_1024_ADDR_WIDTH - (`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_sharers), 
                    .Q0(rd_data_sharers_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_sharers_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_1024_ADDR_WIDTH - (`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_sharers), 
                    .Q1(rd_data_sharers_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_sharers_bank[j],
                    .CE1(rd_en));

            end
            //hprot memory 
            //need 1 bit for hport - 16384x1 BRAM
            for (j = 0; j < `HPROT_BRAMS_PER_WAY; j++) begin
                BRAM_16384x1 hprot_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_16384_ADDR_WIDTH - (`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_hprot), 
                    .Q0(rd_data_hprot_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_hprot_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_16384_ADDR_WIDTH - (`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_hprot), 
                    .Q1(rd_data_hprot_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_hprot_bank[j]),
                    .CE1(rd_en));
            end
            //dirty bit memory 
            //need 1 dirty bit1 - 16384x1 BRAM
            for (j = 0; j < `DIRTY_BIT_BRAMS_PER_WAY; j++) begin
                BRAM_16384x1 dirty_bit_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_16384_ADDR_WIDTH - (`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_dirty_bit), 
                    .Q0(rd_data_dirty_bit_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_dirty_bit_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_16384_ADDR_WIDTH - (`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_dirty_bit), 
                    .Q1(rd_data_dirty_bit_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_dirty_bit_bank[j]),
                    .CE1(rd_en));
            end
            //state memory 
            //need 3 bits for state - 4096x4 BRAM
            for (j = 0; j < `STATE_BRAMS_PER_WAY; j++) begin
                BRAM_4096x4 state_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_state), 
                    .Q0(rd_data_state_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_state_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_state), 
                    .Q1(rd_data_state_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_state_bank[j]),
                    .CE1(rd_en));
            end
            //tag memory 
            //need ~15-20 bits for tag - 512x32 BRAM
            for (j = 0; j < `TAG_BRAMS_PER_WAY; j++) begin
                BRAM_512x32 tag_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_512_ADDR_WIDTH - (`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_tag), 
                    .Q0(rd_data_tag_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_tag_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_512_ADDR_WIDTH - (`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_tag), 
                    .Q1(rd_data_tag_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_tag_bank[j]),
                    .CE1(rd_en));
            end
            //evict ways memory 
            //need 2-5 bits for eviction  - 4096x4 BRAM
            for (j = 0; j < `EVICT_WAY_BRAMS_PER_WAY; j++) begin
                BRAM_4096x4 evict_way_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_evict_way), 
                    .Q0(rd_data_evict_way_tmp[2*i][j]),
                    .WE0(wr_en_port[2*i] & wr_en_evict_way_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_4096_ADDR_WIDTH - (`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_evict_way), 
                    .Q1(rd_data_evict_way_tmp[2*i+1][j]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_evict_way_bank[j]),
                    .CE1(rd_en));
            end
            //line memory 
            //128 bits - using 512x32 BRAM, need 4 BRAMs per line 
            for (j = 0; j < `LINE_BRAMS_PER_WAY; j++) begin 
                for (k = 0; k < BRAMS_PER_`LINE; k++) begin 
                    BRAM_512x32 line_bram( 
                    .CLK(clk), 
                    .A0({{(`BRAM_512_ADDR_WIDTH - (`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b0, rd_set[(`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS - 1):0]}),
                    .D0(wr_data_line[(32*(k+1)-1):(32*k)]), 
                    .Q0(rd_data_line_tmp[2*i][j][(32*(k+1)-1):(32*k)]),
                    .WE0(wr_en_port[2*i] & wr_en_line_bank[j]),
                    .CE0(rd_en),
                    .A1({{(`BRAM_512_ADDR_WIDTH - (`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS) - 1){1'b0}} , 1'b1, rd_set[(`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS - 1):0]}),
                    .D1(wr_data_line[(32*(k+1)-1):(32*k)]), 
                    .Q1(rd_data_line_tmp[2*i+1][j][(32*(k+1)-1):(32*k)]), 
                    .WE1(wr_en_port[2*i+1] & wr_en_line_bank[j]),
                    .CE1(rd_en)); 
                end
            end 
        end
    endgenerate

    always_comb begin 
        for (int i = 0; i < `NUM_PORTS; i++) begin 
            for (int j = 0; j < `OWNER_BRAMS_PER_WAY; j++) begin 
                if (`OWNER_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `OWNER_BRAM_INDEX_BITS)]) begin 
                    rd_data_owner[i] = rd_data_owner_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `SHARERS_BRAMS_PER_WAY; j++) begin 
                if (`SHARERS_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `SHARERS_BRAM_INDEX_BITS)]) begin 
                    rd_data_sharers[i] = rd_data_sharers_tmp[i][j]; 
                end
            end
            for (int j = 0; j < `HPROT_BRAMS_PER_WAY; j++) begin 
                if (`HPROT_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `HPROT_BRAM_INDEX_BITS)]) begin 
                    rd_data_hprot[i] = rd_data_hprot_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `DIRTY_BIT_BRAMS_PER_WAY; j++) begin 
                if (`DIRTY_BIT_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `DIRTY_BIT_BRAM_INDEX_BITS)]) begin 
                    rd_data_dirty_bit[i] = rd_data_dirty_bit_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `STATE_BRAMS_PER_WAY; j++) begin 
                if (`STATE_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `STATE_BRAM_INDEX_BITS)]) begin 
                    rd_data_state[i] = rd_data_state_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `TAG_BRAMS_PER_WAY; j++) begin 
                if (`TAG_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `TAG_BRAM_INDEX_BITS)]) begin 
                    rd_data_tag[i] = rd_data_tag_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `EVICT_WAY_BRAMS_PER_WAY; j++) begin 
                if (`EVICT_WAY_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `EVICT_WAY_BRAM_INDEX_BITS)]) begin 
                    rd_data_evict_way[i] = rd_data_evict_way_tmp[i][j]; 
                end
            end 
            for (int j = 0; j < `LINE_BRAMS_PER_WAY; j++) begin 
                if (`LINE_BRAMS_PER_WAY == 1 || j == rd_set[(`LLC_SET_BITS-1):(`LLC_SET_BITS - `LINE_BRAM_INDEX_BITS)]) begin 
                    rd_data_line[i] = rd_data_line_tmp[i][j]; 
                end
            end 
        end
    end

endmodule
