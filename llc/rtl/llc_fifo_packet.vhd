-- Copyright (c) 2011-2022 Columbia University, System Level Design Group
-- SPDX-License-Identifier: Apache-2.0

--/*
-- * 
-- * Description: Record for use in the First In First Out queue.  
-- * Author: Raghav Balu
-- *
-- * $ID$
-- * 
-- */

library IEEE;
use IEEE.STD_LOGIC_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.std_logic_arith.all;

package fifo_packet_pkg is

    type fifo_packet_t is record
        update_req_in_from_stalled : std_logic;
        clr_req_in_stalled_valid : std_logic;
        look : std_logic;
        is_rst_to_resume : std_logic;
        is_flush_to_resume : std_logic;
        set_is_dma_read_to_resume_decoder : std_logic;
        set_is_dma_write_to_resume_decoder : std_logic;
        clr_is_dma_read_to_resume : std_logic;
        clr_is_dma_write_to_resume : std_logic;
        is_rst_to_get : std_logic;
        is_rsp_to_get : std_logic;
        is_req_to_get : std_logic;
        is_dma_req_to_get : std_logic;
        is_req_to_resume : std_logic;
        is_rst_to_get_next : std_logic;
        is_rsp_to_get_next : std_logic;
        do_get_req : std_logic;
        do_get_dma_req : std_logic;
        clr_rst_stall : std_logic;
        clr_flush_stall : std_logic;
        clr_req_stall_decoder : std_logic;
        update_dma_addr_from_req : std_logic;
        idle : std_logic;
        idle_next : std_logic;
    end record fifo_packet_t

end package fifo_packet_pkg
