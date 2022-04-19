`include "cache_consts.svh"
`include "cache_types.svh"

<<<<<<< HEAD
// llc_fifo_packet.sv
// Author: Kevin Yunchuan Jiang
// Struct for bundling signals through FIFO

typedef struct packed{
    logic update_req_in_from_stalled;
    logic clr_req_in_stalled_valid;  
    logic look;
    logic is_rst_to_resume;
    logic is_flush_to_resume;
    logic set_is_dma_read_to_resume_decoder;
    logic set_is_dma_write_to_resume_decoder; 
    logic clr_is_dma_read_to_resume;
    logic clr_is_dma_write_to_resume;
    logic is_rst_to_get;
    logic is_rsp_to_get;
    logic is_req_to_get;
    logic is_dma_req_to_get;
    logic is_req_to_resume;
    logic is_rst_to_get_next;
    logic is_rsp_to_get_next;
    logic do_get_req;
    logic do_get_dma_req;
    logic clr_rst_stall;
    logic clr_flush_stall;
    logic clr_req_stall_decoder;
    logic update_dma_addr_from_req;
    logic idle;
    logic idle_next;
    llc_set_t set;
    llc_set_t set_next;
}fifo_packet_t;
=======
//This structure is used for FIFO between input decoder and local memory
typedef struct packed{
    llc_set_t set;
    llc_set_t set_next;
    llc_tag_t tag_input;
}decoder_mem_packet;

typedef struct packed{
    llc_tag_t tag_input;
    llc_tag_t tags_mem[`LLC_WAYS];
    llc_state_t states_mem[`LLC_NUM_PORTS];
    llc_way_t evict_way_mem;
}fifo_mem_lookup_packet;

typedef struct packed{
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
}fifo_decoder_packet;
>>>>>>> fifowork_kyj

