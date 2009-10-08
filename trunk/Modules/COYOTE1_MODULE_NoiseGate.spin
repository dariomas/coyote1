''=======================================================================  
'' TITLE: COYOTE1_MODULE_NoiseGate.spin        
''
'' DESCRIPTION:
''   Noise gate.
''
''   INPUTS:
''      IN:           Audio In
''      SENSITIVITY:  The gate threshold level
''      TIME:         The time for which the gate will remain open after triggering.
''      +BYPASS:      Effect bypass control
''
''   OUTPUTS:
''      OUT:          Audio Out
''      +ON:          Set when effect is active (i.e. not bypassed).
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
''  1.0.0  08-27-08  Initial Release.
''
''======================================================================= 

CON

' Low frequency oscillator (LFO) definitions
LFO_PERIOD_MIN_MSEC         = 10
LFO_PERIOD_MAX_MSEC         = 5000


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
                        long    $44_80_00_00                                           'Module Signature
                        long    $00_01_00_00                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    0                                                      'SRAM requirement (heap)
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions 
                        long    7                                                      'Number of sockets
                                                                                        
                        'Socket 0
                        byte    "In",0                                                 'Name  
                        long    0 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 1
                        byte    "Out",0                                                'Name         
                        long    1 | hw#SOCKET_FLAG__SIGNAL                             'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 2
                        byte    "Sensitivity",0                                        'Name
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low
                        long    100                                                    'Range High
                        long    30                                                     'Default Value

                        'Socket 3
                        byte    "Time",0                                               'Name                                                                                                             
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "mSec",0                                               'Units  
                        long    0                                                      'Range Low            
                        long    1489                                                   'Range High
                        long    500                                                    'Default Value

                        'Socket 4
                        byte    "+Bypass",0                                            'Name                                                                                                           
                        long    4 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 5
                        byte    "+On",0                                                'Name                                                                                                         
                        long    5                                                      'Flags and ID
                        byte    0  {null string}                                       'Units 
                        long    0                                                      'Range Low
                        long    1                                                      'Range High
                        long    1                                                      'Default Value

                        'Socket 6
                        byte    "+Gate Open",0                                         'Name                                                                                                         
                        long    6                                                      'Flags and ID
                        byte    0  {null string}                                       'Units 
                        long    0                                                      'Range Low
                        long    1                                                      'Range High
                        long    1                                                      'Default Value

                        byte    "Noise Gate",0                                         'Module name
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
                        mov     p_frame_counter,    p_system_state_block
                        mov     p_ss_overrun_detect,p_system_state_block
                        add     p_ss_overrun_detect,#(hw#SS_OFFSET__OVERRUN_DETECT)
                        
                        mov     p_socket_audio_in,  p_module_control_block
                        add     p_socket_audio_in,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (0 << 2))
                        mov     p_socket_audio_out, p_module_control_block
                        add     p_socket_audio_out, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (1 << 2))
                        mov     p_socket_sensitivity, p_module_control_block
                        add     p_socket_sensitivity, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2)) 
                        mov     p_socket_time,      p_module_control_block
                        add     p_socket_time,      #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2)) 
                        mov     p_socket_bypass,    p_module_control_block
                        add     p_socket_bypass,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (4 << 2)) 
                        mov     p_socket_on,        p_module_control_block
                        add     p_socket_on,        #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (5 << 2))
                        mov     p_socket_gate_open, p_module_control_block
                        add     p_socket_gate_open, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (6 << 2))  

'------------------------------------
'Effect processing loop
'------------------------------------

                        '------------------------------------
                        'Init
                        '------------------------------------ 
                        mov     gate_counter, #0

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
                        'Get audio in sample
                        '------------------------------------
                        rdlong  audio_in_sample, p_socket_audio_in   
                        
                        '------------------------------------
                        'Bypass
                        '------------------------------------
                        'Read bypass state
                        rdlong  r1, p_socket_bypass  
                        cmp     SIGNAL_TRUE, r1   wc, wz

                        'Update on/off indication
        if_c_or_z       mov     r2, #0
        if_nc_and_nz    mov     r2, SIGNAL_TRUE        
                        wrlong  r2, p_socket_on
                        
                        'If bypassed, then just pass audio through
        if_c_or_z       wrlong  audio_in_sample, p_socket_audio_out
        if_c_or_z       jmp     #_frame_sync
                        
                        '------------------------------------
                        'If a signal which meets threshold is detected, set the gate counter to the time value
                        '------------------------------------

                        ' Get audio sample
                        abs     r1, audio_in_sample

                        ' Get sensitivity threshold
                        mov     r2, KNOB_POSITION_MAX
                        rdlong  r3, p_socket_sensitivity
                        sub     r2, r3
                        shr     r2, #4

                        ' Get gate time
                        rdlong  r3, p_socket_time
                        shr     r3, #15
                        add     r3, #511

                        ' If gate threshold met, reset the gate counter
                        cmp     r2, r1 wc
              if_c      mov     gate_counter, r3
  

                        '------------------------------------
                        'Decrement the gate counter, if non-zero
                        '------------------------------------
                        cmp     gate_counter, #0 wz
              if_nz     sub     gate_counter, #1

                        '------------------------------------
                        'Pass audio if the gate counter is non-zero, otherwise output silence
                        '------------------------------------
              if_nz     mov     r1,  audio_in_sample
              if_z      mov     r1,  #0
                        wrlong  r1, p_socket_audio_out

                        '------------------------------------
                        'Report gate state
                        '------------------------------------
              if_nz     mov     r2, SIGNAL_TRUE
              if_z      mov     r2, #0      
                        wrlong  r2, p_socket_gate_open

                        '------------------------------------
                        'Done
                        '------------------------------------
                        jmp     #_frame_sync


'------------------------------------
'Initialized Data                                      
'------------------------------------
SIGNAL_TRUE             long   $40000000
KNOB_POSITION_MAX       long  hw#KNOB_POSITION_MAX  

'------------------------------------
'Module End                                      
'------------------------------------

'NOTE:  This label is used in the module descriptor data table to calculate the total length of the module's code.
'       It is critical that this label appear AFTER all initialized data, otherwise some initialized data will be
'       lost when modules are saved/restored in OpenStomp Workbench, or converted into Dynamic modules.
_module_end             long  0

'------------------------------------
'Uninitialized Data
'------------------------------------                          
r1                        res     1
r2                        res     1
r3                        res     1

audio_in_sample           res     1

p_system_state_block      res     1
p_module_control_block    res     1
previous_microframe       res     1
current_microframe        res     1
p_ss_overrun_detect       res     1   

p_frame_counter           res     1  
p_socket_audio_in         res     1 
p_socket_audio_out        res     1 
p_socket_sensitivity      res     1 
p_socket_time             res     1 
p_socket_bypass           res     1 
p_socket_on               res     1
p_socket_gate_open        res     1

gate_counter              res     1

                          fit                 