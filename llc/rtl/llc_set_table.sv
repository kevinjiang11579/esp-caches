// Copyright (c) 2011-2023 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "cache_consts.svh" 
`include "cache_types.svh" 
`include "llc_fifo_packet.svh"

// llc_set_table.sv 
// Author: Kevin Jiang
// processes available incoming signals with priority 

`define TABLE_SIZE 5

module llc_set_table(
    input logic clk,
    input logic rst,
    input llc_set_t set_next,
    //input fifo_proc_update_packet fifo_update_out,
    input logic remove_set_from_table,
    input logic add_set_to_table,
    input logic [2:0] table_pointer_to_remove,
    input logic check_set_table,
    input logic clr_set_table,

    output logic is_set_in_table,
    output logic [2:0] set_table_pointer
);
    logic [`LLC_SET_BITS:0] set_table[`TABLE_SIZE];
    logic [`TABLE_SIZE-1:0] match_array;
    logic [`LLC_SET_BITS:0] incoming_set;

    assign incoming_set = {1'b1, set_next}; //Add a bit to avoid set 0 being matched initially
    genvar i;
    generate
        for (i = 0; i < `TABLE_SIZE; i++) begin
            always_comb begin
                match_array[i] = 1'b0;
                if(set_table[i] == incoming_set && check_set_table) begin
                    match_array[i] = 1'b1;
                end
            end
            always_ff @(posedge clk or negedge rst) begin
                if (!rst) begin
                    set_table[i] <= 0;
                end
                else if (clr_set_table) begin
                    set_table[i] <= 0;
                end
                else begin
                    //if(add_set_to_table || remove_set_from_table) begin
                        if (add_set_to_table && i == set_table_pointer) begin 
                            set_table[i] <= incoming_set;
                        end
                        else if (remove_set_from_table && i == table_pointer_to_remove) begin
                            set_table[i] <= 0;
                        end
                    //end
                end
            end
        end
    endgenerate
    //If there are any matches with set to be added with sets in table, assert this signal
    assign is_set_in_table = |match_array;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            set_table_pointer <= 0;
        end
        else begin
            if (add_set_to_table) begin
                if (set_table_pointer == `TABLE_SIZE - 1) begin
                    set_table_pointer <= 0;
                end
                else begin
                    set_table_pointer <= set_table_pointer + 1;
                end
            end
        end

    end
endmodule