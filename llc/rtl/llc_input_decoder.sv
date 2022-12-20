// Copyright (c) 2011-2021 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "cache_consts.svh" 
`include "cache_types.svh" 
`include "llc_fifo_packet.svh"

// llc_input_decoder.sv 
// Author: Joseph Zuckerman
// processes available incoming signals with priority 

module llc_input_decoder(
    input logic clk, 
    input logic rst,
    input logic llc_rst_tb_valid_int,
    input logic llc_rsp_in_valid_int,
    input logic llc_req_in_valid_int,
    input logic llc_dma_req_in_valid_int, 
    input logic recall_pending, 
    input logic recall_valid,
    input logic dma_read_pending,
    input logic dma_write_pending,
    input logic req_pending, 
    input logic flush_stall,
    input logic rst_stall, 
    input logic req_stall, 
    input logic req_in_stalled_valid,
    input logic decode_en,
    input logic rd_set_en, 
    //input logic is_dma_read_to_resume, 
    //input logic is_dma_write_to_resume,
    input logic dma_read_to_resume_in_pipeline,
    input logic dma_write_to_resume_in_pipeline,
    input logic rst_to_resume_in_pipeline,
    input logic flush_to_resume_in_pipeline,
    input line_addr_t rsp_in_addr, 
    input line_addr_t req_in_addr, 
    input line_addr_t dma_req_in_addr, 
    input line_addr_t req_in_recall_addr,
    input llc_set_t rst_flush_stalled_set,
    input llc_set_t req_in_stalled_set, 
    input llc_tag_t req_in_stalled_tag,
    input addr_t dma_addr,
    input logic [4:0] process_state, // state of process_request, needed to make certain decisions for DMAs
    llc_req_in_t.in llc_req_in,

    //fifo to mem signals
    input logic fifo_decoder_mem_full,
    output logic fifo_decoder_mem_push,
    //output fifo_mem_packet fifo_mem_in, //not consistent with other modules, but commented out anyways to reduce redundant output signals
    output logic fifo_full_decoder,
    output logic is_dma_read_to_resume, //Outputting from here in order to properly pipeline
    output logic is_dma_write_to_resume, //""
    output llc_req_in_packed_t req_in_packet_to_pipeline, // Just a wire for the output of fifo_decoder
    output logic update_req_in_from_stalled, 
    output logic clr_req_in_stalled_valid,  
    output logic look,
    output logic is_rst_to_resume, 
    output logic is_flush_to_resume, 
    output logic set_is_dma_read_to_resume_decoder, 
    output logic set_is_dma_write_to_resume_decoder, 
    output logic clr_is_dma_read_to_resume, 
    output logic clr_is_dma_write_to_resume,
    //signals for setting if read_to_resume/write_to_resume already in pipeline
    output logic set_dma_read_to_resume_in_pipeline,
    output logic set_dma_write_to_resume_in_pipeline,
    output logic clr_dma_read_to_resume_in_pipeline_decoder,
    output logic clr_dma_write_to_resume_in_pipeline_decoder,
    output logic set_rst_to_resume_in_pipeline,
    output logic clr_rst_to_resume_in_pipeline_decoder,
    output logic set_flush_to_resume_in_pipeline,
    output logic clr_flush_to_resume_in_pipeline_decoder,
    output logic is_rst_to_get, 
    output logic is_rsp_to_get, 
    output logic is_req_to_get, 
    output logic is_dma_req_to_get,
    output logic is_req_to_resume, 
    output logic is_rst_to_get_next, 
    output logic is_rsp_to_get_next,
    output logic do_get_req, 
    output logic do_get_dma_req,
    output logic clr_rst_stall, 
    output logic clr_flush_stall, 
    output logic clr_req_stall_decoder,
    output logic update_dma_addr_from_req,
    output logic idle,
    output logic idle_next,
    output llc_set_t set, 
    output llc_set_t set_next,
    output llc_tag_t tag_next,
        
    line_breakdown_llc_t.out line_br
    );
   
    logic can_get_rst_tb, can_get_rsp_in, can_get_req_in, can_get_dma_req_in; 
    assign can_get_rst_tb = llc_rst_tb_valid_int; 
    assign can_get_rsp_in = llc_rsp_in_valid_int; 
    assign can_get_req_in = llc_req_in_valid_int; 
    assign can_get_dma_req_in = llc_dma_req_in_valid_int;
    
    logic is_rst_to_resume_next, is_flush_to_resume_next, is_req_to_resume_next;
    logic is_req_to_get_next, is_dma_req_to_get_next; 
    logic is_dma_read_to_resume_next; // Start is_dma_read_to_resume from here in order to properly pipeline
    logic is_dma_write_to_resume_next; //""
    
    line_addr_t addr_for_set;
    line_breakdown_llc_t line_br_next();
    //llc_req_in_packed_t req_in_packet;
    // assign req_in_packet.coh_msg = llc_req_in.coh_msg;
    // assign req_in_packet.hprot = llc_req_in.hprot;
    // assign req_in_packet.addr = llc_req_in.addr;
    // assign req_in_packet.line = llc_req_in.line;
    // assign req_in_packet.req_id = llc_req_in.line;
    // assign req_in_packet.word_offset = llc_req_in.word_offset;
    // assign req_in_packet.valid_words = llc_req_in.valid_words;

    logic fifo_flush;
    logic fifo_full;
    logic fifo_empty;
    logic fifo_usage;
    fifo_decoder_packet fifo_decoder_in;
    logic fifo_valid_in;
    fifo_decoder_packet fifo_decoder_out;
    logic fifo_valid_out;
    logic fifo_push;
    logic fifo_pop;

    llc_fifo #(.DATA_WIDTH(10), .DEPTH(1), .dtype(fifo_decoder_packet)) fifo_decoder(clk, rst, fifo_flush, 1'b0, fifo_full, fifo_empty, fifo_usage,
        fifo_decoder_in, fifo_push, fifo_decoder_out, fifo_pop);

    assign fifo_decoder_in.idle = idle_next;
    assign fifo_decoder_in.is_rst_to_resume = is_rst_to_resume_next;
    assign fifo_decoder_in.is_flush_to_resume = is_flush_to_resume_next;
    assign fifo_decoder_in.is_req_to_resume = is_req_to_resume_next;
    assign fifo_decoder_in.is_rst_to_get = is_rst_to_get_next;
    assign fifo_decoder_in.is_req_to_get = is_req_to_get_next;
    assign fifo_decoder_in.is_rsp_to_get = is_rsp_to_get_next;
    assign fifo_decoder_in.is_dma_req_to_get = is_dma_req_to_get_next;
    assign fifo_decoder_in.is_dma_read_to_resume = is_dma_read_to_resume_next;
    assign fifo_decoder_in.is_dma_write_to_resume = is_dma_write_to_resume_next;

    assign idle = fifo_decoder_out.idle;
    assign is_rst_to_resume = fifo_decoder_out.is_rst_to_resume;
    assign is_flush_to_resume = fifo_decoder_out.is_flush_to_resume;
    assign is_req_to_resume = fifo_decoder_out.is_req_to_resume;
    assign is_rst_to_get = fifo_decoder_out.is_rst_to_get;
    assign is_req_to_get = fifo_decoder_out.is_req_to_get;
    assign is_rsp_to_get = fifo_decoder_out.is_rsp_to_get;
    assign is_dma_req_to_get = fifo_decoder_out.is_dma_req_to_get;
    assign is_dma_read_to_resume = fifo_decoder_out.is_dma_read_to_resume;
    assign is_dma_write_to_resume = fifo_decoder_out.is_dma_write_to_resume;

    assign fifo_full_decoder = fifo_full;
  
    always_comb begin 
        fifo_push = 1'b0;
        fifo_flush = 1'b0;
        is_rst_to_resume_next =  1'b0; 
        is_flush_to_resume_next = 1'b0;
        is_req_to_resume_next = 1'b0; 
        is_rst_to_get_next = 1'b0; 
        is_rsp_to_get_next = 1'b0;  
        is_req_to_get_next = 1'b0;  
        is_dma_req_to_get_next =  1'b0;  
        set_is_dma_read_to_resume_decoder = 1'b0; 
        set_is_dma_write_to_resume_decoder = 1'b0; 
        clr_is_dma_read_to_resume = 1'b0; 
        clr_is_dma_write_to_resume = 1'b0; 
        update_req_in_from_stalled = 1'b0;
        clr_req_in_stalled_valid = 1'b0;
        do_get_req = 1'b0; 
        do_get_dma_req = 1'b0;  
        idle_next = 1'b0;
        is_dma_read_to_resume_next = 1'b0; // default option is to clear is_dma_read_to_resume
        is_dma_write_to_resume_next = 1'b0; //""
        //If decode_en
        clr_is_dma_read_to_resume = 1'b1; 
        clr_is_dma_write_to_resume = 1'b1;
        set_dma_read_to_resume_in_pipeline = 1'b0;
        set_dma_write_to_resume_in_pipeline = 1'b0;        
        clr_dma_read_to_resume_in_pipeline_decoder = 1'b1;
        clr_dma_write_to_resume_in_pipeline_decoder = 1'b1;
        set_rst_to_resume_in_pipeline = 1'b0;
        clr_rst_to_resume_in_pipeline_decoder = 1'b1;
        set_flush_to_resume_in_pipeline = 1'b0;
        clr_flush_to_resume_in_pipeline_decoder = 1'b1;
        if (recall_pending) begin 
            if(!recall_valid) begin 
                if(can_get_rsp_in) begin 
                    is_rsp_to_get_next = 1'b1;
                    if (!fifo_full) begin
                        fifo_push = 1'b1;
                    end
                end 
            end else begin 
                if (req_pending) begin 
                    is_req_to_resume_next = 1'b1;
                    if (!fifo_full) begin
                        fifo_push = 1'b1;
                    end
                end else if (dma_read_pending) begin
                    if(process_state != 5'b00000 | dma_read_to_resume_in_pipeline) begin
                        fifo_push = 1'b0;
                    end else if (!fifo_full) begin
                        fifo_push = 1'b1;
                        set_dma_read_to_resume_in_pipeline = 1'b1;
                        is_dma_read_to_resume_next = 1'b1; // in this case, send 1 to pipeline
                    end
                    clr_dma_read_to_resume_in_pipeline_decoder = 1'b0;
                    clr_is_dma_read_to_resume = 1'b0;
                    set_is_dma_read_to_resume_decoder = 1'b1;
                end else if (dma_write_pending) begin
                    if(process_state != 5'b00000 | dma_write_to_resume_in_pipeline) begin
                        fifo_push = 1'b0;
                    end else if (!fifo_full) begin
                        fifo_push = 1'b1;
                        set_dma_write_to_resume_in_pipeline = 1'b1;
                        is_dma_write_to_resume_next = 1'b1;
                    end
                    clr_dma_write_to_resume_in_pipeline_decoder = 1'b0;
                    clr_is_dma_write_to_resume = 1'b0; 
                    set_is_dma_write_to_resume_decoder = 1'b1;
                end
            end
        end else if (rst_stall) begin 
            is_rst_to_resume_next = 1'b1;
            clr_rst_to_resume_in_pipeline_decoder = 1'b0;
            if (rst_to_resume_in_pipeline) begin
                fifo_push = 1'b0;
            end else if (!fifo_full) begin
                fifo_push = 1'b1;
                set_rst_to_resume_in_pipeline = 1'b1;
            end
        end else if (flush_stall) begin
            is_flush_to_resume_next = 1'b1; 
            clr_flush_to_resume_in_pipeline_decoder = 1'b0;
            if (flush_to_resume_in_pipeline) begin
                fifo_push = 1'b0;
            end else if (!fifo_full) begin
                fifo_push = 1'b1;
                set_flush_to_resume_in_pipeline = 1'b1;
            end
        end else if (can_get_rst_tb && !dma_read_pending && !dma_write_pending) begin 
            is_rst_to_get_next = 1'b1;
            if (!fifo_full) begin
                fifo_push = 1'b1;
            end
        end else if (can_get_rsp_in) begin 
            is_rsp_to_get_next =  1'b1;
            if (!fifo_full) begin
                fifo_push = 1'b1;
            end
        end else if ((can_get_req_in &&  !req_stall)  ||  (!req_stall  && req_in_stalled_valid)) begin 
            if (req_in_stalled_valid) begin 
                clr_req_in_stalled_valid = 1'b1;
                update_req_in_from_stalled = 1'b1;   
            end else begin
                do_get_req = 1'b1;
            end
            is_req_to_get_next = 1'b1;
            if (!fifo_full) begin
                fifo_push = 1'b1;
            end
        end else if (dma_read_pending) begin
            if(process_state != 5'b00000 | dma_read_to_resume_in_pipeline) begin
                fifo_push = 1'b0;
            end else if (!fifo_full) begin
                fifo_push = 1'b1;
                set_dma_read_to_resume_in_pipeline = 1'b1;
                is_dma_read_to_resume_next = 1'b1; // in this case, send 1 to pipeline
            end
            clr_dma_read_to_resume_in_pipeline_decoder = 1'b0;
            set_is_dma_read_to_resume_decoder = 1'b1;
            clr_is_dma_read_to_resume = 1'b0;
        end else if (dma_write_pending) begin
            if (can_get_dma_req_in) begin
                if(process_state != 5'b00000 | dma_write_to_resume_in_pipeline) begin
                    fifo_push = 1'b0;
                end else if (!fifo_full) begin
                    fifo_push = 1'b1;
                    set_dma_write_to_resume_in_pipeline = 1'b1;
                    is_dma_write_to_resume_next = 1'b1;
                    do_get_dma_req = 1'b1;
                end
                clr_dma_write_to_resume_in_pipeline_decoder = 1'b0;
                set_is_dma_write_to_resume_decoder = 1'b1;
                clr_is_dma_write_to_resume = 1'b0; 
            end
        end else if (can_get_dma_req_in && !req_stall) begin 
            //NOTE: set some global variable called dma_pending
            //NOTE: Check not dma_pending
            //NOTE: Only this case is lower priority than dma read/write, so only this one is affected by late change of global register
            is_dma_req_to_get_next = 1'b1; 
            do_get_dma_req = 1'b1;
            if (!fifo_full) begin
                fifo_push = 1'b1;
            end
        end else begin 
            //fifo_push = 1'b0;
            idle_next = 1'b1; 
        end
    end 
    
    //flop outputs 
    /*
    always_ff@(posedge clk or negedge rst) begin 
        if (!rst) begin 
            idle <= 1'b0; 
            is_rst_to_resume <= 1'b0; 
            is_flush_to_resume <= 1'b0;
            is_req_to_resume <= 1'b0; 
            is_rst_to_get <= 1'b0; 
            is_req_to_get <= 1'b0;
            is_rsp_to_get <= 1'b0; 
            is_dma_req_to_get <= 1'b0;
        end else if (decode_en) begin 
            idle <= idle_next;
            is_rst_to_resume <= is_rst_to_resume_next; 
            is_flush_to_resume <= is_flush_to_resume_next;
            is_req_to_resume <= is_req_to_resume_next; 
            is_rst_to_get <= is_rst_to_get_next; 
            is_req_to_get <= is_req_to_get_next;
            is_rsp_to_get <= is_rsp_to_get_next;
            is_dma_req_to_get <= is_dma_req_to_get_next;
        end
    end
    */

    assign req_in_packet_to_pipeline.coh_msg = llc_req_in.coh_msg;
    assign req_in_packet_to_pipeline.hprot = llc_req_in.hprot;
    assign req_in_packet_to_pipeline.addr = llc_req_in.addr;
    assign req_in_packet_to_pipeline.line = llc_req_in.line;
    assign req_in_packet_to_pipeline.req_id = llc_req_in.req_id;
    assign req_in_packet_to_pipeline.word_offset = llc_req_in.word_offset;
    assign req_in_packet_to_pipeline.valid_words = llc_req_in.valid_words;

    always_comb begin
        fifo_pop = 1'b0; //decoder fifo
        fifo_decoder_mem_push = 1'b0; //mem fifo
        update_dma_addr_from_req = 1'b0;
        clr_rst_stall = 1'b0;
        clr_flush_stall = 1'b0; 
        clr_req_stall_decoder = 1'b0;
        line_br_next.set = 0; 
        line_br_next.tag = 0; 
        addr_for_set = {`LINE_ADDR_BITS{1'b0}};
        if (!fifo_empty & !fifo_decoder_mem_full) begin 
            //decoder and memfifo
            fifo_pop = 1'b1;
            fifo_decoder_mem_push = 1'b1;
            if (is_rsp_to_get) begin 
                addr_for_set = rsp_in_addr; 
            end else if (is_req_to_get) begin 
                addr_for_set = llc_req_in.addr;
            end else if (is_dma_req_to_get  || is_dma_read_to_resume || is_dma_write_to_resume) begin 
                addr_for_set = is_dma_req_to_get ? dma_req_in_addr : dma_addr; 
                if (is_dma_req_to_get) begin 
                    update_dma_addr_from_req = 1'b1;
                end
            end else if (is_req_to_resume) begin 
                addr_for_set = llc_req_in.addr;         
            end

            line_br_next.tag = addr_for_set[(`ADDR_BITS - `OFFSET_BITS -1): `LLC_SET_BITS];
            line_br_next.set = addr_for_set[(`LLC_SET_BITS - 1):0]; 
        
            if (is_flush_to_resume || is_rst_to_resume) begin 
                if (rst_flush_stalled_set == {`LLC_SET_BITS{1'b1}}) begin 
                    clr_rst_stall  =  1'b1; 
                    clr_flush_stall = 1'b1; 
                end    
            end else if (is_rsp_to_get) begin 
                if ((req_stall == 1'b1) 
                    && (line_br_next.tag  == req_in_stalled_tag) 
                    && (line_br_next.set == req_in_stalled_set)) begin 
                    clr_req_stall_decoder = 1'b1;
                end
            end
        end 
    end

    //flop outputs 
    always_ff@(posedge clk or negedge rst) begin 
        if (!rst) begin 
            line_br.tag <= 0; 
            line_br.set <= 0; 
        end else if (!fifo_empty & !fifo_decoder_mem_full) begin 
            line_br.tag <= line_br_next.tag;
            line_br.set <= line_br_next.set;
        end
    end
    
    assign look =  is_flush_to_resume | is_rsp_to_get | 
                   is_req_to_get | is_dma_req_to_get |
                   (is_dma_read_to_resume & ~recall_pending) | 
                   (is_dma_write_to_resume & ~recall_pending); 
    
    assign tag_next = line_br_next.tag;
    assign set_next = (is_flush_to_resume | is_rst_to_resume) ? rst_flush_stalled_set : line_br_next.set;
    assign set = (is_flush_to_resume | is_rst_to_resume) ? rst_flush_stalled_set : line_br.set; 

endmodule
