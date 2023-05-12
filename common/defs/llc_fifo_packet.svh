`ifndef __LLC_FIFO_PACKET_SVH__
`define __LLC_FIFO_PACKET_SVH__

`include "cache_consts.svh"
`include "cache_types.svh"

//Packet format of the interface signals are defined here
typedef struct packed{
    mix_msg_t	  coh_msg;	// gets, getm, puts, putm, dma_read, dma_write
    hprot_t	  hprot; // used for dma write burst end (0) and non-aligned addr (1)
    line_addr_t	  addr;
    line_t	  line; // used for dma burst length too
    cache_id_t    req_id;
    word_offset_t word_offset;
    word_offset_t valid_words;
}llc_req_in_packed_t;

typedef struct packed{
    coh_msg_t coh_msg;
    line_addr_t	addr;
    line_t	line;
    cache_id_t  req_id;
}llc_rsp_in_packed_t;


typedef struct packed{
   mix_msg_t        coh_msg;   // gets, getm, puts, putm, dma_read, dma_write
   hprot_t          hprot;     // used for dma write burst end (0) and non-aligned addr (1)
   line_addr_t      addr;
   line_t           line;      // used for dma burst length too
   llc_coh_dev_id_t req_id;
   word_offset_t    word_offset;
   word_offset_t    valid_words;
}llc_dma_req_in_packed_t;


//This structure is used for FIFO between input decoder and local memory
typedef struct packed{
    dma_length_t dma_length;
    llc_req_in_packed_t req_in_packet;
    llc_rsp_in_packed_t rsp_in_packet;
    llc_dma_req_in_packed_t dma_req_in_packet;
    llc_set_t set;
    //llc_set_t set_next;
    llc_tag_t tag_input;
    logic [2:0] table_pointer_to_remove;
    //forwarded signals from input decoder
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
    logic is_dma_read_to_resume;
    logic is_dma_write_to_resume;
    //logic idle;
}fifo_decoder_mem_packet;

typedef struct packed{
    dma_length_t dma_length;
    llc_req_in_packed_t req_in_packet;
    llc_rsp_in_packed_t rsp_in_packet;
    llc_dma_req_in_packed_t dma_req_in_packet;
    llc_set_t set;
    llc_tag_t tag_input;
    logic [2:0] table_pointer_to_remove;
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
    logic is_dma_read_to_resume;
    logic is_dma_write_to_resume;
    logic [`LLC_WAYS-1:0] rd_dirty_bit_pipeline;
    llc_way_t rd_evict_way_pipeline;
    logic [((`BITS_PER_LINE*`LLC_WAYS)-1):0] rd_lines_pipeline;
    logic [((`LLC_TAG_BITS*`LLC_WAYS)-1):0] rd_tags_pipeline; //1D version of tags to fit inside struct
    logic [((`MAX_N_L2*`LLC_WAYS-1)):0] rd_sharers_pipeline;
    logic [((`MAX_N_L2_BITS*`LLC_WAYS-1)):0] rd_owner_pipeline;
    logic [((`HPROT_WIDTH*`LLC_WAYS-1)):0] rd_hprots_pipeline;
    logic [((`LLC_STATE_BITS*`LLC_WAYS)-1):0] rd_states_pipeline; //1D version of states to fit inside struct
}fifo_mem_proc_packet;

typedef struct packed{
    llc_set_t set;
    logic [2:0] table_pointer_to_remove;
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
    logic is_dma_read_to_resume;
    logic is_dma_write_to_resume;
    logic is_flush_pipeline;
    // logic [`LLC_WAYS-1:0] rd_dirty_bit_pipeline;
    // llc_way_t rd_evict_way_pipeline;
    // logic [((`BITS_PER_LINE*`LLC_WAYS)-1):0] rd_lines_pipeline;
    // logic [((`LLC_TAG_BITS*`LLC_WAYS)-1):0] rd_tags_pipeline; //1D version of tags to fit inside struct
    // logic [((`MAX_N_L2*`LLC_WAYS-1)):0] rd_sharers_pipeline;
    // logic [((`MAX_N_L2_BITS*`LLC_WAYS-1)):0] rd_owner_pipeline;
    // logic [((`HPROT_WIDTH*`LLC_WAYS-1)):0] rd_hprots_pipeline;
    // logic [((`LLC_STATE_BITS*`LLC_WAYS)-1):0] rd_states_pipeline; //1D version of states to fit inside struct
}fifo_proc_update_packet;


typedef struct packed{
//    llc_tag_t tag_input;
//    llc_tag_t tags_mem[`LLC_WAYS];
//    llc_state_t states_mem[`LLC_NUM_PORTS];
//    llc_way_t evict_way_mem;
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
    llc_tag_t tag_input;
    logic[((`LLC_TAG_BITS*`LLC_WAYS)-1):0] rd_tags_pipeline; //1D version of tags to fit inside struct
    logic[((`LLC_STATE_BITS*`LLC_WAYS)-1):0] rd_states_pipeline; //1D version of states to fit inside struct
    llc_way_t rd_evict_way_pipeline;
    llc_set_t set;
    //llc_tag_t tags_mem[`LLC_WAYS];
    //llc_state_t states_mem[`LLC_NUM_PORTS];
    //llc_way_t evict_way_mem;
}fifo_mem_lookup_packet;

typedef struct packed{
    llc_way_t way;
    logic evict;
    line_addr_t addr_evict;
}fifo_lookup_proc_packet;

typedef struct packed{
    //llc_req_in_packed_t req_in_packet;
    logic idle;
    logic is_rst_to_resume; 
    logic is_flush_to_resume;
    logic is_req_to_resume; 
    logic is_rst_to_get; 
    logic is_req_to_get;
    logic is_rsp_to_get;
    logic is_dma_req_to_get;
    logic is_dma_read_to_resume;
    logic is_dma_write_to_resume;
}fifo_decoder_packet;

`endif
