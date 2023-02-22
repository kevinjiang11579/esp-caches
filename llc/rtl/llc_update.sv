// Copyright (c) 2011-2021 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "cache_consts.svh"
`include "cache_types.svh"
`include "llc_fifo_packet.svh"

// llc_update.sv
// Author: Joseph Zuckerman
// write back to memory 

module llc_update(
    input logic clk, 
    input logic rst, 
    input logic update_en,
    /*input logic is_rst_to_resume, 
    input logic is_flush_to_resume, 
    input logic is_rsp_to_get, 
    input logic is_req_to_get, 
    input logic is_dma_req_to_get, */
    //input logic is_dma_read_to_resume,
    input logic is_dma_read_to_resume_modified, 
    input logic is_dma_read_to_resume_process,  
    //input logic is_dma_write_to_resume,
    input logic is_dma_write_to_resume_modified, 
    input logic is_dma_write_to_resume_process,  
    //input logic is_req_to_resume,
    input logic update_evict_way, 
    input var logic dirty_bits_buf[`LLC_WAYS],
    input var llc_state_t states_buf[`LLC_WAYS],
    input var hprot_t hprots_buf[`LLC_WAYS],
    input var line_t lines_buf[`LLC_WAYS],
    input var llc_tag_t tags_buf[`LLC_WAYS],
    input var sharers_t sharers_buf[`LLC_WAYS],
    input var owner_t owners_buf[`LLC_WAYS],
    input llc_way_t evict_way_buf, 
    input llc_way_t way, 
    input logic llc_rst_tb_done_ready_int,
    input logic flush_stall, 
    input logic rst_stall, 

    //fifo_update signals
    input fifo_proc_update_packet fifo_update_out,
    input logic fifo_empty_update,
    output logic fifo_pop_update,

    output logic clr_rst_to_resume_in_pipeline_update,
    output logic clr_flush_to_resume_in_pipeline_update,

    output logic remove_set_from_table, // Assert when updating
    output logic [2:0] table_pointer_to_remove,

    output logic wr_en, 
    output logic wr_en_evict_way, 
    output logic wr_data_dirty_bit,
    output logic [(`LLC_NUM_PORTS-1):0] wr_rst_flush,
    output logic wr_rst_flush_or,
    output logic incr_rst_flush_stalled_set,
    output hprot_t wr_data_hprot,
    output llc_state_t wr_data_state,
    output sharers_t wr_data_sharers,
    output llc_tag_t wr_data_tag,
    output owner_t wr_data_owner, 
    output llc_way_t wr_data_evict_way,
    output line_t wr_data_line,
    output logic llc_rst_tb_done_valid_int,
    output logic llc_rst_tb_done_o 
);
    logic is_flush_to_resume;
    logic is_rst_to_resume;
    logic is_req_to_resume;
    logic is_rst_to_get;
    logic is_rsp_to_get;
    logic is_req_to_get; 
    logic is_dma_req_to_get;
    logic is_dma_read_to_resume;
    logic is_dma_write_to_resume;

    assign table_pointer_to_remove = fifo_update_out.table_pointer_to_remove;
    assign is_rst_to_resume = fifo_update_out.is_rst_to_resume;
    assign is_flush_to_resume = fifo_update_out.is_flush_to_resume;
    assign is_req_to_resume = fifo_update_out.is_req_to_resume;
    assign is_rst_to_get = fifo_update_out.is_rst_to_get;
    assign is_req_to_get = fifo_update_out.is_req_to_get;
    assign is_rsp_to_get = fifo_update_out.is_rsp_to_get;
    assign is_dma_req_to_get = fifo_update_out.is_dma_req_to_get;
    assign is_dma_read_to_resume = is_dma_read_to_resume_modified ? is_dma_read_to_resume_process : fifo_update_out.is_dma_read_to_resume;
    assign is_dma_write_to_resume = is_dma_write_to_resume_modified ? is_dma_write_to_resume_process : fifo_update_out.is_dma_write_to_resume;
    assign wr_rst_flush_or = |(wr_rst_flush);
    always_comb begin 
        wr_rst_flush = {`LLC_NUM_PORTS{1'b0}};
        wr_data_state = 0;
        wr_data_dirty_bit = 1'b0; 
        wr_data_sharers = 0;
        wr_data_evict_way = 0;
        wr_data_tag = 0; 
        wr_data_line = 0;
        wr_data_hprot = 0; 
        wr_data_owner = 0; 
        wr_data_evict_way = 0; 
        wr_en = 1'b0; 
        wr_en_evict_way = 1'b0;
        incr_rst_flush_stalled_set = 1'b0;
        llc_rst_tb_done_valid_int = 1'b0; 
        llc_rst_tb_done_o = 1'b0;
        fifo_pop_update = 1'b0;
        clr_rst_to_resume_in_pipeline_update = 1'b0;
        clr_flush_to_resume_in_pipeline_update = 1'b0;
        remove_set_from_table = 1'b0;
        if (update_en && llc_rst_tb_done_ready_int) begin
            remove_set_from_table = 1'b1; 
            if(!fifo_empty_update) begin
                fifo_pop_update = 1'b1;
            end
            if (is_rst_to_resume) begin 
                wr_rst_flush  = {`LLC_NUM_PORTS{1'b1}};
                wr_data_state = `INVALID;
                wr_data_dirty_bit = 1'b0; 
                wr_data_sharers = 0; 
                wr_data_evict_way = 0; 
                wr_en_evict_way = 1'b1;
                incr_rst_flush_stalled_set = 1'b1;
                if (!flush_stall &&  !rst_stall) begin 
                    llc_rst_tb_done_valid_int = 1'b1; 
                    llc_rst_tb_done_o = 1'b1;
                end
                clr_rst_to_resume_in_pipeline_update = 1'b1;
            end else if (is_flush_to_resume) begin 
                wr_data_state = `INVALID;
                wr_data_dirty_bit = 1'b0; 
                wr_data_sharers = 0; 
                wr_data_evict_way = 0; 
                incr_rst_flush_stalled_set = 1'b1; 
                for (int cur_way = 0; cur_way < `LLC_WAYS; cur_way++) begin 
                    if (states_buf[cur_way] == `VALID && hprots_buf[cur_way] == `DATA) begin 
                        wr_rst_flush[cur_way] = 1'b1; 
                    end
                end
                if (!flush_stall &&  !rst_stall) begin 
                    llc_rst_tb_done_valid_int = 1'b1; 
                    llc_rst_tb_done_o = 1'b1;
                end
                clr_flush_to_resume_in_pipeline_update = 1'b1;
            end else if (is_rsp_to_get || is_req_to_get || is_dma_req_to_get ||
                         is_dma_read_to_resume || is_dma_write_to_resume || is_req_to_resume) begin 
                wr_en = 1'b1; 
                wr_data_tag = tags_buf[way]; 
                wr_data_state = states_buf[way];
                wr_data_line = lines_buf[way];  
                wr_data_hprot = hprots_buf[way]; 
                wr_data_owner = owners_buf[way]; 
                wr_data_sharers = sharers_buf[way]; 
                wr_data_dirty_bit = dirty_bits_buf[way];
                wr_data_evict_way = evict_way_buf;
                wr_en_evict_way = update_evict_way;
            end
        end
    end
endmodule
