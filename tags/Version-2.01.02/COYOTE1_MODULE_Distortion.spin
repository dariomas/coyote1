''=======================================================================  
'' TITLE: COYOTE1_MODULE_Tube_Distortion.spin
''
'' DESCRIPTION:
''
''   A basic "knee" distortion which implements a transfer gain change from 1:1
''   to 32:1 at a selectable "drive" threshold.  The distortion is applied to
''   both the positive and negative sides of the signal.  An output gain
''   compensation stage boosts the output signal to maintain a relatively
''   uniform output level across the drive range.
''
''   INPUTS:
''      IN:           Audio In
''      DRIVE:        Sets the distortion knee point. Higher settings produce more
''                    more crunch.
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
''  1.0.0  07-19-08  Initial Release.
''  1.1.0  08-14-08  Implemented the "Drive" socket behavior, and added a
''                   corresponding output gain compensation.
''
''=======================================================================  

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
                        long    $20_80_00_01                                           'Module Signature
                        long    $00_02_00_00                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    0                                                      'SRAM requirement (heap)  
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions 
                        long    9                                                      'Number of sockets

                        'Socket 0
                        byte    "In",0                                                 'Socket name  
                        long    0 | hw#SOCKET_FLAG__SIGNAL | hw#SOCKET_FLAG__INPUT     'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 1
                        byte    "Out",0                                                'Socket name   
                        long    1 | hw#SOCKET_FLAG__SIGNAL                             'Socket flags and ID
                        byte    0  {null string}                                       'Units  
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 2
                        byte    "Drive(Positive)",0                                    'Socket name 
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low            
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 3
                        byte    "Edge(Positive)",0                                     'Socket name 
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low            
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 4
                        byte    "Drive(Negative)",0                                    'Socket name 
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low            
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 5
                        byte    "Edge(Negative)",0                                     'Socket name 
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low            
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 6
                        byte    "+Asymmetric",0                                        'Socket name 
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value
                        
                        'Socket 7
                        byte    "+Bypass",0                                            'Socket name 
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Socket flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 8
                        byte    "+On",0                                                'Socket name 
                        long    4                                                      'Socket flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    1                                                      'Default Value

                        byte    "Tube Distortion",0                                    'Module name
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
                        
                        mov     p_socket_audio_in,  p_module_control_block
                        add     p_socket_audio_in,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (0 << 2))
                        mov     p_socket_audio_out, p_module_control_block
                        add     p_socket_audio_out, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (1 << 2))
                        mov     p_socket_drive_pos, p_module_control_block
                        add     p_socket_drive_pos, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2))
                        mov     p_socket_edge_pos,  p_module_control_block
                        add     p_socket_edge_pos,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2))
                        mov     p_socket_drive_neg, p_module_control_block
                        add     p_socket_drive_neg, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (4 << 2))
                        mov     p_socket_edge_neg,  p_module_control_block
                        add     p_socket_edge_neg,  #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (5 << 2))
                        mov     p_socket_asymmetric,p_module_control_block
                        add     p_socket_asymmetric,#(hw#MCB_OFFSET__SOCKET_EXCHANGE + (6 << 2))
                        mov     p_socket_bypass,    p_module_control_block               
                        add     p_socket_bypass,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (7 << 2)) 
                        mov     p_socket_on,        p_module_control_block
                        add     p_socket_on,        #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (8 << 2)) 
                        

                        '------------------------------------
                        'Init
                        '------------------------------------
                        mov     pending_audio_out, #0
                        
'------------------------------------
'Effect processing loop
'------------------------------------

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
                        wrlong  pending_audio_out, p_socket_audio_out
                        rdlong  audio_in_sample, p_socket_audio_in   
                        
                        '------------------------------------
                        'Bypass
                        '------------------------------------
                        'Read bypass state
                        rdlong  r1, p_socket_bypass  
                        cmp     SIGNAL_TRUE, r1   wc, wz

                        'Update on/off indication
        if_c_or_z       mov     r2, 0
        if_nc_and_nz    mov     r2, SIGNAL_TRUE
                        wrlong  r2, p_socket_on
                        
                        'If bypassed, then just pass audio through
        if_c_or_z       mov     audio_in_sample, pending_audio_out
        if_c_or_z       jmp     #_frame_sync


                        '------------------------------------
                        'Do Drive
                        '------------------------------------
                        rdlong  y,p_socket_drive_pos
                        shr     y,#15
                        mov     x, audio_in_sample

                        'Signed multiply y{32, signed} = ((x{32, signed} >> 16) * y{16, unsigned})
                        test    x, sign_bit  wz
                 if_nz  neg     x, x
                        shr     x, #16
                        call    #_mult
                 if_nz  neg     y, y
        
                        '------------------------------------
                        'Do distortion
                        '------------------------------------
                        {
                        rdlong  r1, p_socket_drive_pos
                        mov     drive, KNOB_POSITION_MAX
                        sub     drive, r1 
                        'shr     drive, #23                      ' drive = (KNOB_POSITION_MAX - (*p_socket_drive)) >> 22
                        shr     drive, #6                      ' drive = (KNOB_POSITION_MAX - (*p_socket_drive)) >> 22
                        }
                        
                        'Get audio sample
                        mov     r2, y
                        'sar     r2, #16

                        'Distort the positive side of the waveform
                        '  The distortion is generated by a transfer slope "knee" which changes the in/out transfer function from 1:1 below
                        '  the "drive" threshold to 32:1 above the "drive" threshold.
                        mov      x, r2
                        
                        mov      is_negative, x
                        shr      is_negative, #31
                        
                        cmp      is_negative, #1 wz
                  if_z  neg      x, x
                  
                        cmps     x, CLIPPING_THRESHOLD  wc
                  if_c  jmp      #_noclip

                        sub      x, CLIPPING_THRESHOLD                        
                        
                        shr      x, #16
                        rdlong   r1, p_socket_edge_pos
                        mov      y, KNOB_POSITION_MAX
                        sub      y, r1
                        shr      y, #15
                        call     #_mult
                        mov      x, y

                        add      x, CLIPPING_THRESHOLD
                        
_noclip
                        cmp      is_negative, #1 wz    
                  if_z  neg      x, x
                         

                        '------------------------------------
                        'Do distortion
                        '------------------------------------
                        
                        cmp      is_negative, #1 wz
                  if_z  neg      x, x
                  
                        cmps     x, CLIPPING_THRESHOLD2  wc
                  if_c  jmp      #_noclip2

                        sub      x, CLIPPING_THRESHOLD2
                                               
                        shr      x, #16
                        rdlong   r1, p_socket_edge_neg
                        mov      y, KNOB_POSITION_MAX
                        sub      y, r1
                        shr      y, #15
                        call     #_mult
                        mov      x, y
                        
                        add      x, CLIPPING_THRESHOLD2
                        
_noclip2
                        cmp      is_negative, #1 wz    
                  if_z  neg      x, x
                        
                        '-----------------------------------------------------
                        mov     pending_audio_out, x
                        

                        'Done Distortion
                        jmp     #_frame_sync

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
SIGN_BIT                long   $80000000
SIGNAL_TRUE             long   $40000000
KNOB_POSITION_MAX       long   hw#KNOB_POSITION_MAX

CLIPPING_THRESHOLD      long   $01000000
CLIPPING_THRESHOLD2     long   $02000000     

'------------------------------------
'Module End                                      
'------------------------------------

'NOTE:  This label is used in the module descriptor data table to calculate the total length of the module's code.
'       It is critical that this label appear AFTER all initialized data, otherwise some initialized data will be
'       lost when modules are saved/restored in OpenStomp Workbench, or converted into Dynamic modules.
_module_end             long   0

'------------------------------------
'Uninitialized Data
'------------------------------------
                          
r1                        res     1
r2                        res     1

audio_in_sample           res     1

p_system_state_block      res     1
p_module_control_block    res     1
p_ss_overrun_detect       res     1
previous_microframe       res     1
current_microframe        res     1 
p_frame_counter           res     1

p_socket_audio_in         res     1 
p_socket_audio_out        res     1 
p_socket_drive_pos        res     1
p_socket_drive_neg        res     1
p_socket_edge_pos         res     1
p_socket_edge_neg         res     1
p_socket_asymmetric       res     1    
p_socket_bypass           res     1 
p_socket_on               res     1

pre_amped_signal          res     1
drive                     res     1
is_negative               res     1
temp                      res     1
pending_audio_out         res     1


                          fit                 