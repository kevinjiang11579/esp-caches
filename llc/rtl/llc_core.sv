// Copyright (c) 2011-2021 Columbia University, System Level Design Group
// SPDC-License-Identifier: Apache-2.0

`timescale 1ps / 1ps
`include "cache_consts.svh"
`include "cache_types.svh"
`include "llc_fifo_packet.svh"

// llc.sv
// Author: Joseph Zuckerman
// Top level LLC module 

module llc_core(
    input logic clk,
    input logic rst, 
    input logic llc_req_in_valid,
    input logic llc_dma_req_in_valid,
    input logic llc_rsp_in_valid,
    input logic llc_mem_rsp_valid,
    input logic llc_rst_tb_i,
    input logic llc_rst_tb_valid,
    input logic llc_rsp_out_ready,
    input logic llc_dma_rsp_out_ready,
    input logic llc_fwd_out_ready, 
    input logic llc_mem_req_ready,
    input logic llc_rst_tb_done_ready,
    
    llc_req_in_t.in llc_req_in_i,
    llc_dma_req_in_t.in llc_dma_req_in_i,
    llc_rsp_in_t.in llc_rsp_in_i, 
    llc_mem_rsp_t.in llc_mem_rsp_i,
    
    output logic llc_dma_req_in_ready, 
    output logic llc_req_in_ready,
    output logic llc_rsp_in_ready,
    output logic llc_mem_rsp_ready,
    output logic llc_rst_tb_ready,
    output logic llc_rsp_out_valid,
    output logic llc_dma_rsp_out_valid,
    output logic llc_fwd_out_valid,
    output logic llc_mem_req_valid,
    output logic llc_rst_tb_done_valid,
    output logic llc_rst_tb_done,
 
    llc_dma_rsp_out_t.out llc_dma_rsp_out,
    llc_rsp_out_t.out  llc_rsp_out,
    llc_fwd_out_t.out llc_fwd_out,   
    llc_mem_req_t.out llc_mem_req
    
`ifdef STATS_ENABLE
    , input  logic llc_stats_ready,
    output logic llc_stats_valid,
    output logic llc_stats
`endif
    );

    llc_req_in_t llc_req_in(); 
    llc_dma_req_in_t llc_dma_req_in(); 
    llc_rsp_in_t llc_rsp_in(); 
    llc_mem_rsp_t llc_mem_rsp();
    logic llc_rst_tb; 

    //STATE MACHINE
    
    localparam DECODE = 3'b000;
    localparam READ_SET = 3'b001;
    localparam READ_MEM = 3'b010;
    localparam LOOKUP = 3'b011; 
    localparam PROCESS = 3'b100; 
    localparam UPDATE = 3'b101; 

    logic[2:0] state, next_state; 
    always_ff @(posedge clk or negedge rst) begin 
        if (!rst) begin 
            state <= READ_MEM; 
        end else begin 
            state <= next_state; 
        end
    end 
    
    //wires 
    logic fifo_full_decoder; //fifo wire

    //addr decoder to local mem fifo signals
    logic fifo_decoder_mem_flush;
    logic fifo_decoder_mem_full;
    logic fifo_decoder_mem_empty;
    logic fifo_decoder_mem_usage;
    fifo_decoder_mem_packet fifo_decoder_mem_in;
    logic fifo_decoder_mem_valid_in;
    fifo_decoder_mem_packet fifo_decoder_mem_out;
    logic fifo_decoder_mem_valid_out;
    logic fifo_decoder_mem_push;
    logic fifo_decoder_mem_pop;
    
    logic fifo_full_lookup;
    logic fifo_full_proc;

    logic process_done, idle, idle_next; 
    logic rst_stall, clr_rst_stall;
    logic flush_stall, clr_flush_stall, set_flush_stall; 
    logic do_get_dma_req, is_flush_to_resume, is_rst_to_resume, is_rst_to_get_next, is_rsp_to_get_next, look; 
    logic llc_rsp_out_ready_int, llc_dma_rsp_out_ready_int, llc_fwd_out_ready_int, llc_mem_req_ready_int, llc_rst_tb_done_ready_int; 

    always_comb begin 
        next_state = state; 
        case(state) 
            //READ_SET : 
                //if (fifo_full_decoder) begin
                  //  next_state = READ_MEM; 
                //end
            // READ_MEM : 
            //     if (fifo_decoder_mem_full) begin
            //         next_state = LOOKUP; 
            //     end
            LOOKUP : 
                if (fifo_full_lookup) begin
                    next_state = PROCESS;
                end
            PROCESS :   
                if (process_done) begin 
                    next_state = UPDATE; 
                end
            UPDATE :   
                if ((is_flush_to_resume || is_rst_to_resume) && !flush_stall && !rst_stall) begin 
                    if (llc_rst_tb_done_ready_int) begin 
                        next_state = LOOKUP;
                    end
                end else begin 
                    next_state = LOOKUP;
                end
            default : 
                next_state = LOOKUP;
       endcase
    end

    logic decode_en, rd_set_en, rd_mem_en, update_en, process_en, lookup_en; 
    assign decode_en = (state == DECODE);
    assign rd_set_en = (state == READ_SET);
    assign rd_mem_en = (state == READ_MEM);
    assign lookup_en = (state == LOOKUP); 
    // assign process_en = (state == PROCESS) | (state == LOOKUP);
    assign process_en = (state == PROCESS) | fifo_full_proc;
    assign update_en = (state == UPDATE); 
    
    //wires
    logic req_stall, clr_req_stall_decoder, clr_req_stall_process, set_req_stall; 
    logic req_in_stalled_valid, clr_req_in_stalled_valid, set_req_in_stalled_valid;  
    logic clr_rst_flush_stalled_set, incr_rst_flush_stalled_set;
    logic update_dma_addr_from_req, incr_dma_addr; 
    logic recall_pending, clr_recall_pending, set_recall_pending; 
    logic req_pending, set_req_pending, clr_req_pending; 
    logic dma_read_pending, clr_dma_read_pending, set_dma_read_pending;    
    logic dma_write_pending, clr_dma_write_pending, set_dma_write_pending;    
    logic recall_valid, clr_recall_valid, set_recall_valid, set_recall_evict_addr;    
    logic is_dma_read_to_resume;
    logic clr_is_dma_read_to_resume;
    logic is_dma_read_to_resume_process, is_dma_read_to_resume_modified; 
    logic set_is_dma_read_to_resume_decoder, set_is_dma_read_to_resume_process; 
    logic is_dma_write_to_resume;
    logic clr_is_dma_write_to_resume;
    logic is_dma_write_to_resume_process, is_dma_write_to_resume_modified; 
    logic set_is_dma_write_to_resume_decoder, set_is_dma_write_to_resume_process; 
    logic dma_read_to_resume_in_pipeline, set_dma_read_to_resume_in_pipeline, clr_dma_read_to_resume_in_pipeline_decoder, clr_dma_read_to_resume_in_pipeline_process;
    logic dma_write_to_resume_in_pipeline, set_dma_write_to_resume_in_pipeline, clr_dma_write_to_resume_in_pipeline_decoder, clr_dma_write_to_resume_in_pipeline_process;
    logic update_evict_way, set_update_evict_way, incr_evict_way_buf;
    logic is_rst_to_get, is_req_to_get, is_req_to_resume, is_dma_req_to_get, is_rsp_to_get, do_get_req; 
    logic llc_req_in_ready_int, llc_dma_req_in_ready_int, llc_rsp_in_ready_int, llc_rst_tb_ready_int, llc_mem_rsp_ready_int;
    logic llc_req_in_valid_int, llc_dma_req_in_valid_int, llc_rsp_in_valid_int, llc_rst_tb_valid_int, llc_mem_rsp_valid_int;  
    logic llc_rst_tb_done_o, rst_in, rst_state;
    logic llc_rsp_out_valid_int, llc_dma_rsp_out_valid_int, llc_fwd_out_valid_int, llc_mem_req_valid_int, llc_rst_tb_done_valid_int; 
    logic wr_en_lines_buf, wr_en_tags_buf, wr_en_sharers_buf, wr_en_owners_buf, wr_en_hprots_buf, wr_en_dirty_bits_buf, wr_en_states_buf;
    logic update_req_in_stalled, update_req_in_from_stalled, set_req_in_stalled; 
    logic rd_en, wr_en, wr_en_evict_way, evict, evict_next;
    logic [(`LLC_NUM_PORTS-1):0] wr_rst_flush;
    logic wr_rst_flush_or;
    logic [4:0] process_state;
    logic rst_to_resume_in_pipeline, set_rst_to_resume_in_pipeline, clr_rst_to_resume_in_pipeline_decoder, clr_rst_to_resume_in_pipeline_update;
    logic flush_to_resume_in_pipeline, set_flush_to_resume_in_pipeline, clr_flush_to_resume_in_pipeline_decoder, clr_flush_to_resume_in_pipeline_update;
    llc_req_in_packed_t req_in_packet_to_pipeline;
    llc_rsp_in_packed_t rsp_in_packet_to_pipeline;
    //llc_set_table signals
    logic remove_set_from_table, add_set_to_table, is_set_in_table, check_set_table;
    logic [2:0] table_pointer_to_remove, set_table_pointer;
    // llc_dma_req_in_packed_t dma_req_in_packet_to_pipeline;

    //lookup to process fifo signals
    logic fifo_flush_proc;
    logic fifo_empty_proc;
    logic fifo_usage_proc;
    fifo_mem_proc_packet fifo_proc_in;
    logic fifo_valid_in_proc;
    fifo_mem_proc_packet fifo_proc_out;
    logic fifo_valid_out_proc;
    logic fifo_push_proc;
    logic fifo_pop_proc;

    //process to update fifo signals
    logic fifo_flush_update;
    logic fifo_full_update;
    logic fifo_empty_update;
    logic fifo_usage_update;
    fifo_proc_update_packet fifo_update_in;
    logic fifo_valid_in_update;
    fifo_proc_update_packet fifo_update_out;
    logic fifo_valid_out_update;
    logic fifo_push_update;
    logic fifo_pop_update;

    //mem lookup fifo signals
    logic fifo_flush_lookup;
    logic fifo_empty_lookup;
    logic fifo_usage_lookup;
    fifo_mem_lookup_packet fifo_lookup_in;
    logic fifo_valid_in_lookup;
    fifo_mem_lookup_packet fifo_lookup_out;
    logic fifo_valid_out_lookup;
    logic fifo_push_lookup;
    logic fifo_pop_lookup;
  
    addr_t dma_addr;
    line_addr_t addr_evict, recall_evict_addr;
    line_addr_t req_in_addr, rsp_in_addr, dma_req_in_addr, req_in_stalled_addr, req_in_recall_addr; 
    llc_set_t rst_flush_stalled_set;
    llc_set_t req_in_stalled_set; 
    llc_set_t set, set_next, set_in;     
    llc_tag_t req_in_stalled_tag, tag_next;
    //llc_tag_t tag;
    llc_way_t way, way_next;
    
    logic wr_data_dirty_bit;
    hprot_t wr_data_hprot;
    line_t wr_data_line; 
    llc_state_t wr_data_state;
    llc_tag_t wr_data_tag;
    llc_way_t wr_data_evict_way;
    sharers_t wr_data_sharers;
    owner_t wr_data_owner; 
 
    logic rd_data_dirty_bit[`LLC_WAYS];
    hprot_t rd_data_hprot[`LLC_WAYS];
    line_t rd_data_line[`LLC_WAYS];
    llc_state_t rd_data_state[`LLC_WAYS];
    llc_tag_t rd_data_tag[`LLC_WAYS];
    llc_way_t rd_data_evict_way; 
    sharers_t rd_data_sharers[`LLC_WAYS];
    owner_t rd_data_owner[`LLC_WAYS];
    
    logic dirty_bits_buf[`LLC_WAYS];
    hprot_t hprots_buf[`LLC_WAYS];
    line_t lines_buf[`LLC_WAYS];
    llc_state_t states_buf[`LLC_WAYS];
    llc_tag_t tags_buf[`LLC_WAYS];
    llc_way_t evict_way_buf; 
    sharers_t sharers_buf[`LLC_WAYS];
    owner_t owners_buf[`LLC_WAYS];

    logic dirty_bits_buf_updated[`LLC_WAYS];
    hprot_t hprots_buf_updated[`LLC_WAYS];
    line_t lines_buf_updated[`LLC_WAYS];
    llc_state_t states_buf_updated[`LLC_WAYS];
    llc_tag_t tags_buf_updated[`LLC_WAYS];
    llc_way_t evict_way_buf_updated; 
    sharers_t sharers_buf_updated[`LLC_WAYS];
    owner_t owners_buf_updated[`LLC_WAYS];

    logic dirty_bits_buf_wr_data;
    hprot_t hprots_buf_wr_data;
    line_t lines_buf_wr_data;
    llc_state_t states_buf_wr_data;
    llc_tag_t tags_buf_wr_data;
    sharers_t sharers_buf_wr_data;
    owner_t owners_buf_wr_data;
    
    //assign set_in = rd_set_en ? set_next : set;
    //assign set_in = fifo_decoder_mem_out.set; // This is the set that localmem takes from decoder
    assign llc_rsp_in_ready_int = !fifo_full_decoder & is_rsp_to_get_next; 
    assign llc_rst_tb_ready_int = !fifo_full_decoder & is_rst_to_get_next; 
    assign llc_req_in_ready_int = !fifo_full_decoder & do_get_req; 
    assign llc_dma_req_in_ready_int = !fifo_full_decoder & do_get_dma_req;
    assign rd_en = fifo_decoder_mem_push;
    //assign tag = line_br.tag;

    //fifo_decoder_mem signals
    assign fifo_decoder_mem_in.table_pointer_to_remove = set_table_pointer;
    assign fifo_decoder_mem_in.req_in_packet = req_in_packet_to_pipeline;
    assign fifo_decoder_mem_in.rsp_in_packet = rsp_in_packet_to_pipeline;
    //assign fifo_decoder_mem_in.dma_req_in_packet = dma_req_in_packet_to_pipeline;
    assign fifo_decoder_mem_in.look = look;
    //assign fifo_decoder_mem_in.idle = idle;
    assign fifo_decoder_mem_in.set = set_next;
    assign fifo_decoder_mem_in.tag_input = tag_next;
    assign fifo_decoder_mem_in.is_rst_to_resume = is_rst_to_resume;
    assign fifo_decoder_mem_in.is_flush_to_resume = is_flush_to_resume;
    assign fifo_decoder_mem_in.is_req_to_resume = is_req_to_resume;
    assign fifo_decoder_mem_in.is_rst_to_get = is_rst_to_get;
    assign fifo_decoder_mem_in.is_req_to_get = is_req_to_get;
    assign fifo_decoder_mem_in.is_rsp_to_get = is_rsp_to_get;
    assign fifo_decoder_mem_in.is_dma_req_to_get = is_dma_req_to_get;
    assign fifo_decoder_mem_in.is_dma_read_to_resume = is_dma_read_to_resume;
    assign fifo_decoder_mem_in.is_dma_write_to_resume = is_dma_write_to_resume;

    //fifo_lookup input signals
    //decoder control signals and tag_input are simply forwarded
    assign fifo_lookup_in.is_rst_to_resume = fifo_decoder_mem_out.is_rst_to_resume;
    assign fifo_lookup_in.is_flush_to_resume = fifo_decoder_mem_out.is_flush_to_resume;
    assign fifo_lookup_in.is_req_to_resume = fifo_decoder_mem_out.is_req_to_resume;
    assign fifo_lookup_in.is_rst_to_get = fifo_decoder_mem_out.is_rst_to_get;
    assign fifo_lookup_in.is_req_to_get = fifo_decoder_mem_out.is_req_to_get;
    assign fifo_lookup_in.is_rsp_to_get = fifo_decoder_mem_out.is_rsp_to_get;
    assign fifo_lookup_in.is_dma_req_to_get = fifo_decoder_mem_out.is_dma_req_to_get;
    assign fifo_lookup_in.tag_input = fifo_decoder_mem_out.tag_input;
    //other input signals
    always_comb begin //for loop for flattening tags input
        for (int i = 1; i<=`LLC_WAYS; i++) begin
            fifo_lookup_in.rd_tags_pipeline[((`LLC_TAG_BITS*i)-1)-:`LLC_TAG_BITS]=rd_data_tag[i-1];
            fifo_lookup_in.rd_states_pipeline[((`LLC_STATE_BITS*i)-1)-:`LLC_STATE_BITS]=rd_data_state[i-1];
        end
    end
    assign fifo_lookup_in.rd_evict_way_pipeline = rd_data_evict_way;
    //fifo_lookup output signals
    //Leaving the buffers out for now

    //fifo_proc input signals, acutally coming from mem instead of lookup to save one cycle
    assign fifo_proc_in.table_pointer_to_remove = fifo_decoder_mem_out.table_pointer_to_remove;
    assign fifo_proc_in.req_in_packet = fifo_decoder_mem_out.req_in_packet;
    assign fifo_proc_in.rsp_in_packet = fifo_decoder_mem_out.rsp_in_packet;
    //assign fifo_proc_in.dma_req_in_packet = fifo_decoder_mem_out.dma_req_in_packet;
    assign fifo_proc_in.set = fifo_decoder_mem_out.set;
    assign fifo_proc_in.tag_input = fifo_decoder_mem_out.tag_input;
    assign fifo_proc_in.is_rst_to_resume = fifo_decoder_mem_out.is_rst_to_resume;
    assign fifo_proc_in.is_flush_to_resume = fifo_decoder_mem_out.is_flush_to_resume;
    assign fifo_proc_in.is_req_to_resume = fifo_decoder_mem_out.is_req_to_resume;
    assign fifo_proc_in.is_rst_to_get = fifo_decoder_mem_out.is_rst_to_get;
    assign fifo_proc_in.is_req_to_get = fifo_decoder_mem_out.is_req_to_get;
    assign fifo_proc_in.is_rsp_to_get = fifo_decoder_mem_out.is_rsp_to_get;
    assign fifo_proc_in.is_dma_req_to_get = fifo_decoder_mem_out.is_dma_req_to_get;
    assign fifo_proc_in.is_dma_read_to_resume = fifo_decoder_mem_out.is_dma_read_to_resume;
    assign fifo_proc_in.is_dma_write_to_resume = fifo_decoder_mem_out.is_dma_write_to_resume;
    always_comb begin //for loop for flattening localmem input
        for (int i = 1; i<=`LLC_WAYS; i++) begin
            fifo_proc_in.rd_dirty_bit_pipeline[(i-1)-:1]=rd_data_dirty_bit[i-1];
            fifo_proc_in.rd_lines_pipeline[((`BITS_PER_LINE*i)-1)-:`BITS_PER_LINE]=rd_data_line[i-1];
            fifo_proc_in.rd_tags_pipeline[((`LLC_TAG_BITS*i)-1)-:`LLC_TAG_BITS]=rd_data_tag[i-1];
            fifo_proc_in.rd_sharers_pipeline[((`MAX_N_L2*i)-1)-:`MAX_N_L2]=rd_data_sharers[i-1];
            fifo_proc_in.rd_owner_pipeline[((`MAX_N_L2_BITS*i)-1)-:`MAX_N_L2_BITS]=rd_data_owner[i-1];
            fifo_proc_in.rd_hprots_pipeline[((`HPROT_WIDTH*i)-1)-:`HPROT_WIDTH]=rd_data_hprot[i-1];
            fifo_proc_in.rd_states_pipeline[((`LLC_STATE_BITS*i)-1)-:`LLC_STATE_BITS]=rd_data_state[i-1];
        end
    end
    assign fifo_proc_in.rd_evict_way_pipeline = rd_data_evict_way;

    //fifo_update input signals
    assign fifo_update_in.table_pointer_to_remove = fifo_proc_out.table_pointer_to_remove;
    assign fifo_update_in.set = fifo_proc_out.set;
    assign fifo_update_in.is_rst_to_resume = fifo_proc_out.is_rst_to_resume;
    assign fifo_update_in.is_flush_to_resume = fifo_proc_out.is_flush_to_resume;
    assign fifo_update_in.is_req_to_resume = fifo_proc_out.is_req_to_resume;
    assign fifo_update_in.is_rst_to_get = fifo_proc_out.is_rst_to_get;
    assign fifo_update_in.is_req_to_get = fifo_proc_out.is_req_to_get;
    assign fifo_update_in.is_rsp_to_get = fifo_proc_out.is_rsp_to_get;
    assign fifo_update_in.is_dma_req_to_get = fifo_proc_out.is_dma_req_to_get;
    assign fifo_update_in.is_dma_read_to_resume = fifo_proc_out.is_dma_read_to_resume;
    assign fifo_update_in.is_dma_write_to_resume = fifo_proc_out.is_dma_write_to_resume;
    
    always_comb begin //always block for fifo logic
        fifo_decoder_mem_flush = 1'b0;
        fifo_flush_lookup = 1'b0;
        fifo_flush_proc = 1'b0;
        fifo_flush_update = 1'b0;
        //mem logic, see address decoder and localmem for logic
        /*if (!fifo_full_mem) begin
            fifo_push_mem = 1'b1;
        end
        else begin
            fifo_push_mem = 1'b0;
        end
        if (!fifo_empty_mem) begin
            fifo_pop_mem = 1'b1;
        end
        else begin
            fifo_pop_mem = 1'b0;
        end*/   

        //lookup logic
        /*if (!fifo_full_lookup) begin
            fifo_push_lookup = 1'b1;
        end
        else begin
            fifo_push_lookup = 1'b0;
        end
        if (!fifo_empty_lookup) begin
            fifo_pop_lookup = 1'b1;
        end
        else begin
            fifo_pop_lookup = 1'b0;
        end  */    
    end

    //always_ff @(posedge clk or negedge rst) begin // for loop for packing tags output
    //    for (int i = 1; i<`LLC_WAYS; i++) begin
    //        
    //    end
    //end 

    //interfaces
    line_breakdown_llc_t line_br();
    llc_dma_req_in_t llc_dma_req_in_next(); 
    llc_rsp_out_t llc_rsp_out_o();
    llc_dma_rsp_out_t llc_dma_rsp_out_o(); 
    llc_fwd_out_t llc_fwd_out_o(); 
    llc_mem_req_t llc_mem_req_o();
    llc_mem_rsp_t llc_mem_rsp_next();
 
`ifdef STATS_ENABLE
    logic llc_stats_ready_int, llc_stats_valid_int, llc_stats_o;
`endif

    //instances
    llc_regs regs_u(.*); 
    llc_input_decoder input_decoder_u(.*);
    llc_interfaces interfaces_u (.*); 
    //fifo for decoder to local memory
    llc_fifo #(.DATA_WIDTH((`LLC_REQ_IN_WIDTH + `LLC_RSP_IN_WIDTH + `LLC_SET_BITS + `LLC_TAG_BITS + 10 + 3)), .DEPTH(1), .dtype(fifo_decoder_mem_packet)) fifo_decoder_mem (clk, rst, fifo_decoder_mem_flush, 1'b0, fifo_decoder_mem_full, fifo_decoder_mem_empty, fifo_decoder_mem_usage,
        fifo_decoder_mem_in, fifo_decoder_mem_push, fifo_decoder_mem_out, fifo_decoder_mem_pop);    
    //fifo for mem to proc
    llc_fifo #(.DATA_WIDTH((`LLC_REQ_IN_WIDTH + `LLC_RSP_IN_WIDTH + `LLC_SET_BITS + `LLC_TAG_BITS + 9 + 3 + `LLC_WAY_BITS + (1 + `BITS_PER_LINE + `LLC_TAG_BITS + `MAX_N_L2 + `MAX_N_L2_BITS + `HPROT_WIDTH + `LLC_STATE_BITS)*`LLC_WAYS)),
        .DEPTH(1), .dtype(fifo_mem_proc_packet)) fifo_proc(clk, rst, fifo_flush_proc, 1'b0, fifo_full_proc, fifo_empty_proc, fifo_usage_proc, fifo_proc_in, fifo_push_proc, fifo_proc_out, fifo_pop_proc);
    //fifo for proc to update
    llc_fifo #(.DATA_WIDTH(`LLC_SET_BITS + 9 + 3), .DEPTH(1), .dtype(fifo_proc_update_packet)) fifo_update(clk, rst, fifo_flush_update, 1'b0, fifo_full_update, fifo_empty_update, fifo_usage_update,
        fifo_update_in, fifo_push_update, fifo_update_out, fifo_pop_update);
    //fifo for mem to lookup
    llc_fifo #(.DATA_WIDTH((`LLC_TAG_BITS*`LLC_WAYS) + (`LLC_STATE_BITS*`LLC_NUM_PORTS) + `LLC_TAG_BITS + `LLC_WAY_BITS + 7), .DEPTH(1), .dtype(fifo_mem_lookup_packet)) fifo_lookup(clk, rst, fifo_flush_lookup, 1'b0, fifo_full_lookup, fifo_empty_lookup, fifo_usage_lookup,
        fifo_lookup_in, fifo_push_lookup, fifo_lookup_out, fifo_pop_lookup);
`ifdef XILINX_FPGA
    llc_localmem localmem_u(.*);
`endif
`ifdef GF12
    llc_localmem_gf12 localmem_u(.*);
`endif
    llc_update update_u (.*);
    llc_bufs bufs_u(.*);
    llc_lookup_way lookup_way_u(.*); 
    llc_process_request process_request_u(.*);
    llc_set_table set_table_u(.*);
    
endmodule
