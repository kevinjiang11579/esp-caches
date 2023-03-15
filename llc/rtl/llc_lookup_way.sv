// Copyright (c) 2011-2021 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps 
`include "cache_consts.svh"
`include "cache_types.svh"
`include "llc_fifo_packet.svh"

//llc_lookup_way.sv 
//Author: Joseph Zuckerman
//looks up way for eviction/replacement 

module llc_lookup_way (
    input logic clk, 
    input logic rst, 
    input logic lookup_en, 
    //input llc_tag_t tag, 
    // input var llc_tag_t tags_buf[`LLC_WAYS],
    // input var llc_state_t states_buf[`LLC_WAYS],
    // input llc_way_t evict_way_buf,

    //fifo from mem inputs and outputs
    input fifo_mem_lookup_packet fifo_lookup_out,
    input logic fifo_empty_lookup,
    input logic fifo_lookup_proc_full,
    output logic fifo_pop_lookup,
    output logic fifo_lookup_proc_push,
    //fifo to proc
    //input logic fifo_full_proc,
    //output logic fifo_push_proc,
    
    output logic evict, 
    output logic evict_next,
    output llc_way_t way, 
    output llc_way_t way_next,
    output line_addr_t addr_evict_next
    ); 
    
    llc_tag_t tag;
    llc_tag_t tags_buf[`LLC_WAYS];
    llc_state_t states_buf[`LLC_WAYS];
    llc_way_t evict_way_buf;
    llc_set_t set;

    always_comb begin
        for (int i = 1; i<=`LLC_WAYS; i++) begin
            tags_buf[i-1] = fifo_lookup_out.rd_tags_pipeline[((`LLC_TAG_BITS*i)-1)-:`LLC_TAG_BITS];
            states_buf[i-1] = fifo_lookup_out.rd_states_pipeline[((`LLC_STATE_BITS*i)-1)-:`LLC_STATE_BITS];          
        end
    end
    assign evict_way_buf = fifo_lookup_out.rd_evict_way_pipeline;

    assign tag = fifo_lookup_out.tag_input;
    assign set = fifo_lookup_out.set;
    assign addr_evict_next = {tags_buf[way_next], set};
    //fifo logic
    always_comb begin
        fifo_pop_lookup = 1'b0;
        fifo_lookup_proc_push = 1'b0;
        //fifo_push_proc = 1'b0;
        // if(lookup_en) begin
        if (!fifo_empty_lookup && !fifo_lookup_proc_full) begin
            fifo_pop_lookup = 1'b1;
            fifo_lookup_proc_push = 1'b1;
        end
           // if (!fifo_full_proc) begin
           //     fifo_push_proc = 1'b1;
           // end
        // end
    end
      

    //LOOKUP
    logic [`LLC_WAYS - 1:0] tag_hits_tmp, empty_ways_tmp, evict_valid_tmp, evict_not_sd_tmp; 
    llc_way_t way_tmp;
    always_comb begin 
        for (int i = 0; i < `LLC_WAYS; i++) begin
            tag_hits_tmp[i] = (tags_buf[i] == tag && states_buf[i] != `INVALID);
            empty_ways_tmp[i] = (states_buf[i] == `INVALID); 
            
            way_tmp = (i + evict_way_buf) & {`LLC_WAY_BITS{1'b1}};
            evict_valid_tmp[i] = (states_buf[way_tmp] == `VALID);
            evict_not_sd_tmp[i] = (states_buf[way_tmp] != `SD); 
        end
    end 

    //way priority encoder
    llc_way_t hit_way, empty_way, evict_way_valid, evict_way_not_sd;
    logic tag_hit, empty_way_found, evict_valid, evict_not_sd; 
    
    pri_enc #(`LLC_WAYS, `LLC_WAY_BITS) hit_way_enc (
        .in(tag_hits_tmp), 
        .out(hit_way), 
        .out_valid(tag_hit)
    );
    
    pri_enc #(`LLC_WAYS, `LLC_WAY_BITS) empty_way_enc (
        .in(empty_ways_tmp), 
        .out(empty_way), 
        .out_valid(empty_way_found)
    );
    
    pri_enc #(`LLC_WAYS, `LLC_WAY_BITS) evict_valid_enc (
        .in(evict_valid_tmp), 
        .out(evict_way_valid), 
        .out_valid(evict_valid)
    );
    
    pri_enc #(`LLC_WAYS, `LLC_WAY_BITS) evict_not_sd_enc (
        .in(evict_not_sd_tmp), 
        .out(evict_way_not_sd), 
        .out_valid(evict_not_sd)
    ); 
    
    always_comb begin 
        if (tag_hit) begin 
            way_next = hit_way;
            evict_next = 1'b0;
        end else if (empty_way_found) begin 
            way_next = empty_way;
            evict_next = 1'b0; 
        end else if (evict_valid) begin 
            way_next = evict_way_valid  + evict_way_buf;
            evict_next = 1'b1;
        end else if (evict_not_sd) begin 
            way_next = evict_way_not_sd + evict_way_buf;
            evict_next = 1'b1;
        end else begin 
            way_next = evict_way_buf;
            evict_next = 1'b1; 
        end
    end

    //flop outputs
    always_ff @(posedge clk or negedge rst) begin 
        if (!rst) begin 
            way <= 0; 
            evict <= 1'b0; 
        // end else if (lookup_en) begin
        end else if(!fifo_empty_lookup && !fifo_lookup_proc_full) begin
            way <= way_next;
            evict <= evict_next;
        end 
    end
endmodule
