// Copyright (c) 2011-2023 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "cache_consts.svh" 
`include "cache_types.svh" 
`include "llc_fifo_packet.svh"

// llc_pipe_reg.sv 
// Author: Kevin Jiang
// pipeline register for pipelined LLC, uses valid-ready protocol to give back-pressure

module llc_pipe_reg #(
    parameter int unsigned DATA_WIDTH = 32,
    parameter type dtype = logic [DATA_WIDTH-1:0]
    )(
    input logic clk,
    input logic rst,
    input logic ready_in, // ready goes upstream
    input logic valid_in, // valid goes downstream
    input dtype data_in, // data goes downstream
    output logic ready_out,
    output logic valid_out,
    output dtype data_out
);
// valid_out[t] is valid_in[t-1]
// ready_out[t] is ready_in[t]
// ready_in and valid_in must both be 1 for data_out to update
// Upstream logic should only assert valid_in if ready_out is asserted
// Downstream logic can assert ready_in whenever

    assign ready_out = ready_in;

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            data_out <= '0;
        end
        else if (valid_in && ready_in) begin
            data_out <= data_in;
        end
    end

    always_ff @(posedge clk or negedge rst) begin
        if (!rst) begin
            valid_out <= '0;
        end
        else if (ready_in) begin
            valid_out <= valid_in;
        end
    end
    
endmodule