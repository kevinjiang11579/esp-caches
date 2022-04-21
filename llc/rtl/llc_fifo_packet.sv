`include "cache_consts.svh"
`include "cache_types.svh"

//This structure is used for FIFO between input decoder and local memory
typedef struct packed{
    llc_set_t set;
    llc_set_t set_next;
    llc_tag_t tag_input;
}decoder_mem_packet;

//typedef struct packed{
//    llc_tag_t tag_input;
//    llc_tag_t tags_mem[`LLC_WAYS];
//    llc_state_t states_mem[`LLC_NUM_PORTS];
//    llc_way_t evict_way_mem;
//}fifo_mem_lookup_packet;

typedef struct packed{
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
}fifo_decoder_packet;

