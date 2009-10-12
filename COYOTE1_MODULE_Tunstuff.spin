''=======================================================================  
'' TITLE: COYOTE1_MODULE_Tunstuff.spin         
''
'' DESCRIPTION:
''
'' COPYRIGHT:
''   Copyright (C)2008 Eric Moyer
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
''  Rev    Date      Description
''  -----  --------  ---------------------------------------------------
''  1.0.0  07-19-08  Initial Release.
''
''======================================================================= 
''
''  Notes:
''
''  This module uses all the available SRAM in order to provide the longest
''  possible dealay loop.  If you want to use this module in cobmination
''  with other modules that also use SRAM, you can reduce the SRAM buffer size
''  below accordingly.
''
''=======================================================================  
CON

  STATE_LOCKOUT  = 0
  STATE_IDLE     = 1
  STATE_BASELINE = 2
  STATE_ACTIVE   = 3

  C_SRAM_BUFFER_SIZE           = 1024 * 512 * 3  'SRAM requirement (1.5M Bytes)
  C_SRAM_SAMPLE_SIZE           = 2               'Bytes per SRAM sample

  'Local flags
  FLAG__BUTTON_CAPTURE = $00000001
  FLAG__BUTTON_ADD     = $00000002
  FLAG__LED_CAPTURE    = $00000004
  FLAG__LED_ADD        = $00000008
  
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
                        long    $11_80_00_01                                           'Module Signature
                        long    $00_01_00_00                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    C_SRAM_BUFFER_SIZE                                     'SRAM requirement (heap)
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions 
                        long    7                                                      'Number of sockets
                                                                                        
                        'Socket 0
                        byte    "In 1",0                                               'Name  
                        long    0 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 1
                        byte    "In 2",0                                               'Name  
                        long    1 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value
                        
                        'Socket 2
                        byte    "Out",0                                                'Name         
                        long    2 | hw#SOCKET_FLAG__SIGNAL                             'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 3
                        byte    "+Capture",0                                           'Name
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units     
                        long    0                                                      'Range Low
                        long    hw#CONTROL_SOCKET_MAX_VALUE                            'Range High
                        long    0                                                      'Default Value

                        'Socket 4
                        byte    "+Add",0                                               'Name
                        long    4 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units     
                        long    0                                                      'Range Low
                        long    hw#CONTROL_SOCKET_MAX_VALUE                            'Range High
                        long    0                                                      'Default Value

                        'Socket 5
                        byte    "+Capture LED",0                                       'Name                                                                                                           
                        long    5                                                      'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 6
                        byte    "+Add LED",0                                           'Name                                                                                                           
                        long    6                                                      'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        byte    "Tunstuff",0                                           'Module name
                        long    hw#NO_SEGMENTATION                                     'Segmentation 
         
_module_descriptor_end  byte    0

DAT
                        
'------------------------------------
'Entry
'------------------------------------
                        org
                        
_module_entry
                        mov     p_module_control_block, PAR                     'Get pointer to Module Control Block
                        rdlong  p_system_state_block, p_module_control_block    'Get pointer to System State Block

                        'Initialize pointers into System State block
                        mov     p_frame_counter,    p_system_state_block
                        mov     p_ss_overrun_detect,p_system_state_block
                        add     p_ss_overrun_detect,#(hw#SS_OFFSET__OVERRUN_DETECT)    
                        mov     r1,                 p_module_control_block
                        add     r1,                 #(hw#MCB_OFFSET__HEAP_BASE_P)
                        rdlong  heap_base_address, r1

                        mov     p_socket_audio_in1, p_module_control_block
                        add     p_socket_audio_in1, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (0 << 2))
                        mov     p_socket_audio_in2, p_module_control_block
                        add     p_socket_audio_in2, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (1 << 2))
                        mov     p_socket_audio_out, p_module_control_block
                        add     p_socket_audio_out, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2))
                        mov     p_socket_capture,   p_module_control_block
                        add     p_socket_capture,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2)) 
                        mov     p_socket_add,       p_module_control_block
                        add     p_socket_add,       #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (4 << 2)) 
                        mov     p_socket_cap_led,   p_module_control_block
                        add     p_socket_cap_led,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (5 << 2)) 
                        mov     p_socket_add_led,   p_module_control_block
                        add     p_socket_add_led,   #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (6 << 2))

'------------------------------------
'Effect processing loop
'------------------------------------

                        '------------------------------------
                        'Init
                        '------------------------------------
                        rdlong  previous_microframe, p_frame_counter            'Initialize previous microframe
                        mov     sram_p_in, heap_base_address
                        mov     state, #STATE_IDLE
                        mov     blink_counter, #0

                        'Determine SRAM end address                        
                        mov     sram_end_address, heap_base_address       ' sram_end_address = (heap_base_address + SRAM_BUFFER_SIZE) - 1
                        add     sram_end_address, SRAM_BUFFER_SIZE
                        sub     sram_end_address, #1

                        'Set MEMBUS interface as outputs
                        or       dira, PINGROUP__MEM_INTERFACE
                        or       dira, PIN__LCD_MUX
                        andn     outa, PIN__LCD_MUX

                        '------------------------------------
                        'Clear SRAM
                        '------------------------------------
                        mov     sram_data, #0
                        mov     sram_address, heap_base_address

_lock1                  lockset hw#LOCK_ID__MEMBUS   wc
              if_c      jmp     #_lock1
              
                        call    #_sram_write
                        mov     r2, SRAM_BUFFER_SIZE
                                     
_clear_loop             call    #_sram_burst_write
                        sub     r2, #C_SRAM_SAMPLE_SIZE  wc                    
              if_nc     jmp     #_clear_loop
                        lockclr hw#LOCK_ID__MEMBUS  

                        '------------------------------------
                        'Sync
                        '------------------------------------
                        rdlong  previous_microframe, p_frame_counter            'Initialize previous microframe
                        
                        'Wait for the beginning of a new microframe
_frame_sync             rdlong  current_microframe, p_frame_counter
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
                        'Read the button states
                        '------------------------------------

                        'Clear the button flags
                        mov     local_flags, #0

                        'Detect whether the "Capture" button is held
                        rdlong  r1, p_socket_capture  
                        cmp     SIGNAL_TRUE, r1   wc, wz
           if_c_or_z    or      local_flags, #FLAG__BUTTON_CAPTURE

                        'Detect whether the "Add" button is held
                        rdlong  r1, p_socket_add  
                        cmp     SIGNAL_TRUE, r1   wc, wz
           if_c_or_z    or      local_flags, #FLAG__BUTTON_ADD

                        '------------------------------------
                        'Process state transitions
                        '------------------------------------


                        'CASE: LOCKOUT ----------------------------------
                        cmp     state, #STATE_LOCKOUT wz
              if_nz     jmp     #_case_idle
                        
                        'Go to IDLE state if both buttons released, and timeout met
                        test    local_flags, #(FLAG__BUTTON_CAPTURE | FLAG__BUTTON_ADD)  wz     
              if_z      sub     lockout_counter, #1 wz
              if_z      mov     state,  #STATE_IDLE
                        
                        'CASE: IDLE -------------------------------------     
_case_idle              cmp     state, #STATE_IDLE  wz
              if_nz     jmp     #_case_baseline

                        'Blink LED0
                        add     blink_counter, #1
                        test    blink_counter, BLINK_BIT  wz
              if_nz     or      local_flags, #FLAG__LED_CAPTURE                    'Light "Capture" LED
              if_z      andn    local_flags, #FLAG__LED_CAPTURE                    'Clear "Capture" LED

                        'Clear delay length
                        mov     delay_offset, #0

                        'Go to BASELINE state if "Capture" button pressed
                        test    local_flags, #FLAG__BUTTON_CAPTURE   wz     
              if_nz     mov     state,  #STATE_BASELINE
              '
                        'STATE: BASELINE --------------------------------- 
_case_baseline          cmp     state, #STATE_BASELINE  wz
              if_nz     jmp     #_case_active

                        'Increase delay length
                        add     delay_offset, #2
                        
                        or      local_flags, #FLAG__LED_CAPTURE                    'Light "Capture" LED   
                        test    local_flags, #FLAG__BUTTON_CAPTURE   wz
              if_z      mov     state,  #STATE_ACTIVE

                        'Enter the active state if the max loop length has been reached
                        mov     r1, SRAM_BUFFER_SIZE
                        sub     r1, #4  
                        cmp     r1, delay_offset wz
              if_z      mov     state,  #STATE_ACTIVE

                        'STATE: ACTIVE -----------------------------------  
_case_active            cmp     state, #STATE_ACTIVE  wz
              if_nz     jmp     #_case_end
                         
                        andn    local_flags, #FLAG__LED_CAPTURE                    'Clear "Capture" LED 

_case_end
                        'Go to LOCKOUT state if button 0 and button 1 pressed
                        test    local_flags, #FLAG__BUTTON_CAPTURE               wz
              if_nz     test    local_flags, #FLAG__BUTTON_ADD                   wz    
              if_nz     mov     state,  #STATE_LOCKOUT
              if_nz     mov     lockout_counter, LOCKOUT_COUNTER_INIT                      
                        
                        '------------------------------------
                        'Determine read pointer
                        '------------------------------------
                        mov     sram_p_out, sram_p_in
                        sub     sram_p_out, delay_offset  wc
                        cmps    sram_p_out, heap_base_address  wc    'if(sram_p_out < heap_base_address)
              if_c      add     sram_p_out, SRAM_BUFFER_SIZE         '   sram_p_out += SRAM_BUFFER_SIZE;
                        
                        '------------------------------------
                        'Do delay
                        '------------------------------------
                        
                        'Read delayed value
                        mov     sram_address, sram_p_out
_lock2                  lockset hw#LOCK_ID__MEMBUS   wc
              if_c      jmp     #_lock2
                        call    #_sram_read
                        lockclr hw#LOCK_ID__MEMBUS
                      
                        'Read incoming signal
                        rdlong  r2, p_socket_audio_in1
                        rdlong  r1, p_socket_audio_in2
                        add     r2, r1
                        mov     input_mix, r2                     
                        
                        'Sum the delayed sample to the current (if in ACTIVE mode, and left "silence" button not pressed)
                        cmp     state, #STATE_ACTIVE  wz
              if_nz     jmp     #_not_active
                        test    local_flags, #FLAG__BUTTON_CAPTURE  wz
              if_nz     or      local_flags, #FLAG__LED_CAPTURE                     'Light "Capture" LED  
              if_z      add     r2, sram_data
_not_active

                        'Send to output
                        andn    r2, NOISE_MASK
                        wrlong  r2, p_socket_audio_out

                        'If "Add" Button held, or in BASELINE state, then add input signal to feedback loop
                        mov     r2, input_mix  
                        test    local_flags, #FLAG__BUTTON_ADD   wc
                        cmp     state, #STATE_BASELINE wz    
         if_z_or_c      add     sram_data, r2
         if_z_or_c      or      local_flags, #FLAG__LED_ADD                        'Light "Add" LED   
         if_nz_and_nc   andn    local_flags, #FLAG__LED_ADD                        'Clear "ADD" LED
       
              
                        'Save to sram
                        'mov     sram_data, y
                        mov     sram_address, sram_p_in
_lock3                  lockset hw#LOCK_ID__MEMBUS   wc
              if_c      jmp     #_lock3
                        call    #_sram_write
                        lockclr hw#LOCK_ID__MEMBUS 
                        
                        'Bump pointers
                        add      sram_p_in, #C_SRAM_SAMPLE_SIZE  
                        cmp      sram_end_address, sram_p_in  wc
              if_c      mov      sram_p_in, heap_base_address


                        
                        '------------------------------------
                        'Output LED flag states to thier LED output conduits
                        '------------------------------------
                        test    local_flags, #FLAG__LED_CAPTURE  wz
              if_z      mov     r2, 0
              if_nz     mov     r2, SIGNAL_TRUE   
                        wrlong  r2, p_socket_cap_led

                        test    local_flags, #FLAG__LED_ADD  wz
              if_z      mov     r2, 0
              if_nz     mov     r2, SIGNAL_TRUE   
                        wrlong  r2, p_socket_add_led
                        

                        '------------------------------------
                        'Done
                        '------------------------------------
                        jmp     #_frame_sync


'------------------------------------
'MEMBUS Read
'------------------------------------
_sram_read

                        or      dira, PINGROUP__MEMBUS
                        
                        'Write HIGH address
                        mov     r1, sram_address
                        and     r1, PINGROUP__MEMBUS
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_HIGH

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK

                        'Write MID address
                        mov     r1, sram_address
                        shl     r1, #8
                        and     r1, PINGROUP__MEMBUS   
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_MID

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK
 
                        'Write LOW address
                        mov     r1, sram_address
                        shl     r1, #16
                        and     r1, PINGROUP__MEMBUS   
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_LOW

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK

                        'Setup Read
                        andn    dira, PINGROUP__MEMBUS

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__READ_BYTE

                        'Clear data longword
                        mov     sram_data, #0

                        'Read HIGH byte
                        or      outa, PIN__MEMBUS_CLK
                        mov     sram_data, ina
                        andn    outa, PIN__MEMBUS_CLK
                        and     sram_data, PINGROUP__MEMBUS
                        
                        'Read LOW byte
                        or      outa, PIN__MEMBUS_CLK
                        mov     r1, ina
                        andn    outa, PIN__MEMBUS_CLK
                        and     r1, PINGROUP__MEMBUS  
                        shr     r1, #8
                        or      sram_data, r1

                        'convert 24 bit word to 32 bit word
                        shl     sram_data, #8


                        andn    outa, PINGROUP__MEM_INTERFACE
_sram_read_ret          ret
                        
                         
'------------------------------------
'MEMBUS Write
'------------------------------------
_sram_write

                        or      dira, PINGROUP__MEMBUS
                        
                        'Write HIGH address
                        mov     r1, sram_address
                        and     r1, PINGROUP__MEMBUS
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_HIGH

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK

                        'Write MID address
                        mov     r1, sram_address
                        shl     r1, #8
                        and     r1, PINGROUP__MEMBUS  
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_MID

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK

                        'Write LOW address
                        mov     r1, sram_address
                        shl     r1, #16
                        and     r1, PINGROUP__MEMBUS
                        andn    outa, PINGROUP__MEMBUS
                        or      outa, r1

                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__SET_ADDR_LOW

                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK
                        
_sram_burst_write
                      
                        'Setup Write
                        andn    outa, PINGROUP__MEMBUS_CNTL
                        or      outa, #hw#MEMBUS_CNTL__WRITE_BYTE

                        'Write HIGH byte
                        mov     r1, sram_data
                        shr     r1, #8
                        and     r1, PINGROUP__MEMBUS
                        andn    outa, PINGROUP__MEMBUS   
                        or      outa, r1
                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK
                        
                        'Write LOW byte
                        mov     r1, sram_data
                        and     r1, PINGROUP__MEMBUS
                        andn    outa, PINGROUP__MEMBUS   
                        or      outa, r1
                        or      outa, PIN__MEMBUS_CLK
                        andn    outa, PIN__MEMBUS_CLK

                        andn    outa, PINGROUP__MEM_INTERFACE
                        andn    dira, PINGROUP__MEMBUS 
_sram_burst_write_ret                        
_sram_write_ret         ret                             

'------------------------------------
'Multiply                                    
'------------------------------------
' Multiply x[15..0] by y[15..0] (y[31..16] must be 0)
' on exit, product in y[31..0]
'------------------------------------
_mult                   shl x,#16               'get multiplicand into x[31..16]
                        mov t,#16               'ready for 16 multiplier bits
                        shr y,#1 wc             'get initial multiplier bit into c
_loop
                        if_c add y,x wc         'conditionally add multiplicand into product
                        rcr y,#1 wc             'get next multiplier bit into c.
                                                ' while shift product
                        djnz t,#_loop           'loop until done
_mult_ret               ret

x                       long    $00000000
y                       long    $00000000
t                       long    $00000000

'------------------------------------
'Initialized Data                                      
'------------------------------------

SRAM_BUFFER_SIZE        long   C_SRAM_BUFFER_SIZE 
PINGROUP__MEM_INTERFACE long   hw#PINGROUP__MEM_INTERFACE
PINGROUP__MEMBUS        long   hw#PINGROUP__MEMBUS
PINGROUP__MEMBUS_CNTL   long   hw#PINGROUP__MEMBUS_CNTL 
PIN__MEMBUS_CLK         long   hw#PIN__MEMBUS_CLK
PIN__LCD_MUX            long   hw#PIN__LCD_MUX
MID_ADDR_MASK           long   $0000ff00
NOISE_MASK              long   $0000ffff
SIGNAL_TRUE             long   $40000000  

BLINK_BIT               long   $00001000
LOCKOUT_COUNTER_INIT    long   $00004000

'------------------------------------
'Module End                                      
'------------------------------------

'NOTE:  This label is used in the module descriptor data table to calculate the total length of the module's code.
'       It is critical that this label appear AFTER all initialized data, otherwise some initialized data will be
'       lost when modules are saved/restored in OpenStomp Workbench, or converted into Dynamic modules.
'       This label should appear BEFORE the uninitialized data, otherwise that data will be stored unnecessarily
'       when modules are saved/restored in OpenStomp Workbench, making them larger.
_module_end             long   0

'------------------------------------
'Uninitialized Data
'------------------------------------

previous_microframe       res     1
current_microframe        res     1
p_module_control_block    res     1 
p_system_state_block      res     1
heap_base_address         res     1
p_frame_counter           res     1
p_ss_overrun_detect       res     1

p_socket_audio_in1        res     1
p_socket_audio_in2        res     1  
p_socket_audio_out        res     1
p_socket_capture          res     1
p_socket_add              res     1
p_socket_cap_led          res     1
p_socket_add_led          res     1

r1                        res     1
r2                        res     1

sram_p_in                 res     1
sram_p_out                res     1
sram_address              res     1
sram_data                 res     1
sram_end_address          res     1

capture_count             res     1

local_flags               res     1
state                     res     1
blink_counter             res     1
lockout_counter           res     1
delay_offset              res     1
input_mix                 res     1

                          fit                 