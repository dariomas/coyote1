''=======================================================================  
'' TITLE: COYOTE1_MODULE_Utility.spin
''
'' DESCRIPTION:
''   A collection of commonly used utility functions:
''      Two Mixers
''      Two Gain controls
''      3 input logic function, configurable as AND/OR/NAND/NOR
''
''   INPUTS:
''      Mix A In 1
''      Mix A In 2
''
''      Mix B In 1
''      Mix B In 2
''
''      Gain A In
''      Gain A Gain
''
''      Gain B In
''      Gain B Gain
''
''      +Logic A In 1
''      +Logic A In 2
''      +Logic A In 3
''      Logic A Mode:   0=AND, 1=OR, 2=NAND, 3=NOR
''         
''
''   OUTPUTS:
''      Mix A Out
''
''      Mix B Out 
''
''      Gain A Out  
''
''      Gain B Out
''
''      +Logic A Out
''
''      
''
'' COPYRIGHT:
''   Copyright (C)2009 Eric Moyer
''
'' LICENSING:
''
''   This program module is free software: you can redistribute it and/or modify
''   it under the terms of the GNU General Public License as published by
''   the Free Software Foundation, either version 3 of the License, or
''   (at your option) any later version.
''
''   This program module is distributed in the hope that it will be useful,
''   but WITHOUT ANY WARRANTY; without even the implied warranty of
''   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
''   GNU General Public License for more details.
''
''   You should have received a copy of the GNU General Public License
''   along with this program module.  If not, see <http://www.gnu.org/licenses/>.
''   
''======================================================================= 
''
''  REVISION HISTORY:
''
''  Rev      Date      Description
''  -------  --------  ---------------------------------------------------
''  1.00.00  02-28-09  Initial creation.
''  1.00.01  05-12-09  Implement gain functions         
''
''=======================================================================  
CON

  ' Logic functions
  FUNCTION_AND                = 1
  FUNCTION_OR                 = 2
  FUNCTION_NAND               = 3
  FUNCTION_NOR                = 4
      
OBJ
  hw        :       "COYOTE1_HW_Definitions.spin"  'Hardware definitions       

PUB get_module_descriptor_p
  ' Store the main RAM address of the module's code into the module descriptor. 
  long[ @_module_descriptor + hw#MDES_OFFSET__CODE_P] := @_module_entry
  ' Return a pointer to the module descriptor 
  return (@_module_descriptor)

DAT

'------------------------------------
'Module Descriptor
'------------------------------------
_module_descriptor      long    hw#MDES_FORMAT_1                                       'Module descriptor format
                        long    (@_module_descriptor_end - @_module_descriptor)        'Module descriptor size (in bytes)
                        long    (@_module_end - @_module_entry)                        'Module legth
                        long    0                                                      'Module code pointer (this is a placeholder which gets overwritten during
                                                                                       '   the get_module_descriptor_p() call) 
                        long    $44_80_00_02                                           'Module Signature
                        long    $00_01_00_01                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    0                                                      'SRAM requirement (heap)
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions  
                        long    17                                                     'Number of sockets

                        'Socket 0
                        byte    "Mix A In 1",0                                         'Socket name 
                        long    0 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 1
                        byte    "Mix A In 2",0                                         'Socket name 
                        long    1 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 2
                        byte    "Mix B In 1",0                                         'Socket name 
                        long    2 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 3
                        byte    "Mix B In 2",0                                         'Socket name 
                        long    3 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 4
                        byte    "Gain A In",0                                          'Socket name 
                        long    4 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 5
                        byte    "Gain A Gain",0                                        'Name
                        long    5 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low
                        long    100                                                    'Range High
                        long    100                                                    'Default Value
                        
                        'Socket 6
                        byte    "Gain B In",0                                          'Socket name 
                        long    6 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 7
                        byte    "Gain B Gain",0                                        'Name
                        long    7 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 8  
                        byte    "+Logic A In 1",0                                      'Name                                                                                                           
                        long    8 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 9  
                        byte    "+Logic A In 2",0                                      'Name                                                                                                           
                        long    9 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 10  
                        byte    "+Logic A In 3",0                                      'Name                                                                                                           
                        long    10 | hw#SOCKET_FLAG__INPUT                             'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 11 
                        byte    "Logic A Mode",0                                       'Name                                                                                                           
                        long    11 | hw#SOCKET_FLAG__INPUT                             'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    3                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 12
                        byte    "Mix A Out",0                                          'Name         
                        long    12 | hw#SOCKET_FLAG__SIGNAL                            'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 13
                        byte    "Mix B Out",0                                          'Name         
                        long    13 | hw#SOCKET_FLAG__SIGNAL                            'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 14
                        byte    "Gain A Out",0                                         'Name         
                        long    14 | hw#SOCKET_FLAG__SIGNAL                            'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 15
                        byte    "Gain B Out",0                                         'Name         
                        long    15 | hw#SOCKET_FLAG__SIGNAL                            'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 16
                        byte    "+Logic A Out",0                                       'Name                                                                                                         
                        long    16                                                     'Flags and ID
                        byte    0  {null string}                                       'Units 
                        long    0                                                      'Range Low
                        long    1                                                      'Range High
                        long    1                                                      'Default Value
                        
                        byte    "Utility",0                                            'Module name
                        long    hw#NO_SEGMENTATION                                     'Segmentation 

_module_descriptor_end  byte    0    


DAT
                        
'------------------------------------
'Module Code 
'------------------------------------
                        org
                        
_module_entry
                        mov     p_module_control_block, PAR                     'Get pointer to Module Control Block
                        rdlong  p_system_state_block, p_module_control_block    'Get pointer to System State Block

                        'Initialize pointers into System State block
                        mov     p_ss_frame_counter,  p_system_state_block
                        mov     p_ss_overrun_detect, p_system_state_block
                        add     p_ss_overrun_detect, #(hw#SS_OFFSET__OVERRUN_DETECT)

                        'Initialize pointers to the socket exhange
                        mov     p_socket_mix_a_in_1,    p_module_control_block
                        add     p_socket_mix_a_in_1,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (0 << 2))
                        mov     p_socket_mix_a_in_2,    p_module_control_block
                        add     p_socket_mix_a_in_2,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (1 << 2))
                        mov     p_socket_mix_b_in_1,    p_module_control_block
                        add     p_socket_mix_b_in_1,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2))
                        mov     p_socket_mix_b_in_2,    p_module_control_block
                        add     p_socket_mix_b_in_2,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2)) 
                        mov     p_socket_gain_a_in,     p_module_control_block
                        add     p_socket_gain_a_in,     #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (4 << 2)) 
                        mov     p_socket_gain_a_gain,   p_module_control_block
                        add     p_socket_gain_a_gain,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (5 << 2))
                        mov     p_socket_gain_b_in,     p_module_control_block
                        add     p_socket_gain_b_in,     #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (6 << 2)) 
                        mov     p_socket_gain_b_gain,   p_module_control_block
                        add     p_socket_gain_b_gain,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (7 << 2))
                        mov     p_socket_logic_a_in_1,  p_module_control_block
                        add     p_socket_logic_a_in_1,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (8 << 2))
                        mov     p_socket_logic_a_in_2,  p_module_control_block
                        add     p_socket_logic_a_in_2,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (9 << 2))
                        mov     p_socket_logic_a_in_3,  p_module_control_block
                        add     p_socket_logic_a_in_3,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (10<< 2))
                        mov     p_socket_logic_a_mode,  p_module_control_block
                        add     p_socket_logic_a_mode,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (11<< 2))
                        mov     p_socket_mix_a_out,     p_module_control_block
                        add     p_socket_mix_a_out,     #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (12<< 2))
                        mov     p_socket_mix_b_out,     p_module_control_block
                        add     p_socket_mix_b_out,     #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (13<< 2))
                        mov     p_socket_gain_a_out,    p_module_control_block
                        add     p_socket_gain_a_out,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (14<< 2))
                        mov     p_socket_gain_b_out,    p_module_control_block
                        add     p_socket_gain_b_out,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (15<< 2))
                        mov     p_socket_logic_a_out,   p_module_control_block
                        add     p_socket_logic_a_out,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (16<< 2))


'------------------------------------
'Effect processing loop
'------------------------------------

                        '------------------------------------
                        'Init
                        '------------------------------------

                        
                        '------------------------------------
                        'Sync
                        '------------------------------------
                        rdlong  previous_microframe, p_ss_frame_counter         'Initialize previous microframe
                        
                        'Wait for the beginning of a new microframe
_frame_sync             rdlong  current_microframe, p_ss_frame_counter
                        cmp     previous_microframe, current_microframe  wz
              if_z      jmp     #_frame_sync                                    'If current_microframe = previoius_microframe

                        'Verify sync, and report an overrun condition if it has occurred.
                        '
                        'NOTE: An overrun condition is reported to the OS by writing a non-zero value to the "overrun detect" field in the
                        '      SYSTEM_STATE block.  The code below writes the value of current_microframe in order to conserve code space,
                        '      achieve portability, and limit execution time. That value will be non-zero 99.9999999767169% of the time,
                        '      which is sufficiently reliable for overrun reporting
                        '
                        add     previous_microframe, #1
                        cmp     previous_microframe, current_microframe  wz
              if_nz     wrlong  current_microframe, p_ss_overrun_detect
                        
                        mov     previous_microframe, current_microframe         'previous_microframe = current_microframe
                        

                        '------------------------------------
                        'Mix A
                        '------------------------------------
                        rdlong  r1, p_socket_mix_a_in_1
                        rdlong  r2, p_socket_mix_a_in_2
                        add     r1, r2
                        wrlong  r1, p_socket_mix_a_out

                        '------------------------------------
                        'Mix B
                        '------------------------------------
                        rdlong  r1, p_socket_mix_b_in_1
                        rdlong  r2, p_socket_mix_b_in_2
                        add     r1, r2
                        wrlong  r1, p_socket_mix_b_out

                        '------------------------------------
                        'Gain A
                        '------------------------------------
                        rdlong  y,p_socket_gain_a_gain
                        shr     y,#15
                        rdlong  x,p_socket_gain_a_in

                        'Signed multiply y<32> = (x<16> * y<16>)
                        test    x, sign_bit  wz
                 if_nz  neg     x, x
                        shr     x, #16
                        call    #_mult
                 if_nz  neg     y, y

                        wrlong  y,p_socket_gain_a_out

                        '------------------------------------
                        'Gain B
                        '------------------------------------
                        rdlong  y,p_socket_gain_b_gain
                        shr     y,#15
                        rdlong  x,p_socket_gain_b_in

                        'Signed multiply y<32> = (x<16> * y<16>)
                        test    x, sign_bit  wz
                 if_nz  neg     x, x
                        shr     x, #16
                        call    #_mult
                 if_nz  neg     y, y

                        wrlong  y,p_socket_gain_b_out 

                        '------------------------------------
                        'LOGIC A
                        '------------------------------------

                        ' (Not yet implemented)
                        
                        '--------------------------------------
                        'Done UTILITY
                        '--------------------------------------
                        jmp     #_frame_sync
                                          

'------------------------------------
'16x16 Multiply                                    
'------------------------------------
' Multiply x[15..0] by y[15..0] (y[31..16] must be 0)
' on exit, product in y[31..0]
'------------------------------------
_mult                   shl x,#16               'get multiplicand into x[31..16]
                        mov t,#16               'ready for 16 multiplier bits
                        shr y,#1 wc             'get initial multiplier bit into c
                        
_mult_loop              if_c add y,x wc         'conditionally add multiplicand into product
                        rcr y,#1 wc             'get next multiplier bit into c.
                                                ' while shift product
                        djnz t,#_mult_loop      'loop until done
_mult_ret               ret                     'return with product in y[31..0] 




'------------------------------------
'Initialized Data                                      
'------------------------------------


CONTROL_SOCKET_MAX_VALUE    long  hw#CONTROL_SOCKET_MAX_VALUE
HALF_MAX                    long  $0000FFFF
SIGNAL_TRUE                 long  $40000000        'True/False threshold of socket values
SIGN_BIT                    long  $80000000

'------------------------------------
'Module End                                      
'------------------------------------

'NOTE:  This label is used in the module descriptor data table to calculate the total length of the module's code.
'       It is critical that this label appear AFTER all initialized data, otherwise some initialized data will be
'       lost when modules are saved/restored in OpenStomp Workbench, or converted into Dynamic modules.
_module_end                 long   0

'------------------------------------
'Uninitialized Data
'------------------------------------
                          
r1                        res     1             ' General purpose register
r2                        res     1             ' General purpose register

x                         res     1             ' Used for multiply and divide operations
y                         res     1             ' Used for multiply and divide operations  
t                         res     1             ' Used for multiply and divide operations  

p_system_state_block      res     1             ' Pointer to System State block
p_module_control_block    res     1             ' Pointer to Module Control block
p_ss_overrun_detect       res     1             ' Pointer to Overrun Detect field in the System State block
p_ss_frame_counter        res     1             ' Pointer to the frame counter

p_socket_mix_a_in_1       res     1             ' Pointer to MIX A IN 1 socket
p_socket_mix_a_in_2       res     1             ' Pointer to MIX A IN 2 socket   
p_socket_mix_b_in_1       res     1             ' Pointer to MIX B IN 1 socket
p_socket_mix_b_in_2       res     1             ' Pointer to MIX B IN 2 socket   
p_socket_gain_a_in        res     1             ' Pointer to GAIN A IN socket
p_socket_gain_a_gain      res     1             ' Pointer to GAIN A GAIN socket
p_socket_gain_b_in        res     1             ' Pointer to GAIN B IN socket
p_socket_gain_b_gain      res     1             ' Pointer to GAIN B GAIN socket
p_socket_logic_a_in_1     res     1             ' Pointer to LOGIC A IN 1 socket
p_socket_logic_a_in_2     res     1             ' Pointer to LOGIC A IN 2 socket
p_socket_logic_a_in_3     res     1             ' Pointer to LOGIC A IN 3 socket
p_socket_logic_a_mode     res     1             ' Pointer to LOGIC A MODE socket    
p_socket_mix_a_out        res     1             ' Pointer to MIX A OUT socket   
p_socket_mix_b_out        res     1             ' Pointer to MIX B OUT socket
p_socket_gain_a_out       res     1             ' Pointer to GAIN A OUT socket   
p_socket_gain_b_out       res     1             ' Pointer to GAIN B OUT socket
p_socket_logic_a_out      res     1             ' Pointer to LOGIC A OUT socket  

previous_microframe       res     1             ' Value of the previous microframe counter
current_microframe        res     1             ' Value of the current microframe counter

                          fit                 