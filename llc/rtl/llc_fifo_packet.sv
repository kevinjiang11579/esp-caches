`include "cache_consts.svh"
`include "cache_types.svh"

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

