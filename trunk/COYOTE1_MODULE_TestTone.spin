''=======================================================================  
'' TITLE: COYOTE1_MODULE_TestTone.spin        
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
''  1.0.0  07-25-08  Initial Release.
''  1.0.1  08-07-08  Remove bogus RAM and SRAM requirements.
''
''======================================================================= 

CON

' Audio oscillator definitions
OSC_FREQ_MIN_HZ             = 10
OSC_FREQ_MAX_HZ             = 20000


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
                        long    $42_80_00_00                                           'Module Signature
                        long    $00_01_00_01                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    0                                                      'SRAM requirement (heap)
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions 
                        long    4                                                      'Number of sockets

                        'Socket 0
                        byte    "Out",0                                                'Name         
                        long    1 | hw#SOCKET_FLAG__SIGNAL                             'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    0                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 1
                        byte    "Freq",0                                               'Name
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "Hz",0                                                 'Units  
                        long    OSC_FREQ_MIN_HZ                                        'Range Low
                        long    OSC_FREQ_MAX_HZ                                        'Range High
                        long    1000                                                   'Default Value

                        'Socket 2
                        byte    "+Bypass",0                                            'Name                                                                                                           
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 3
                        byte    "+On",0                                                'Name                                                                                                         
                        long    4                                                      'Flags and ID
                        byte    0  {null string}                                       'Units 
                        long    0                                                      'Range Low
                        long    1                                                      'Range High
                        long    1                                                      'Default Value

                        byte    "TestTone",0                                           'Module name
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

                        mov     p_socket_audio_out, p_module_control_block
                        add     p_socket_audio_out, #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (0 << 2))
                        mov     p_socket_freq,      p_module_control_block
                        add     p_socket_freq,      #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (1 << 2)) 
                        mov     p_socket_bypass,    p_module_control_block
                        add     p_socket_bypass,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2)) 
                        mov     p_socket_on,        p_module_control_block
                        add     p_socket_on,        #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2)) 

'------------------------------------
'Effect processing loop
'------------------------------------

                        '------------------------------------
                        'Init
                        '------------------------------------ 
                        mov     sawtooth_value, #0                              'Initialize the sawtooth wave
                        mov     sawtooth_rising, #1
                        mov     angle_16_16_fxp, #0
                        mov     blink_counter, #0 

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
                        'Bypass
                        '------------------------------------
                        'Read bypass state
                        rdlong  r1, p_socket_bypass  
                        cmp     SIGNAL_TRUE, r1   wc, wz

                        'Update on/off indication
        if_c_or_z       mov     r2, 0
        if_nc_and_nz    mov     r2, SIGNAL_TRUE        
                        wrlong  r2, p_socket_on
                        
                        'If bypassed, then output nothing
        if_c_or_z       mov     x, 0                
        if_c_or_z       wrlong  x, p_socket_audio_out
        if_c_or_z       jmp     #_frame_sync
                        
                        '------------------------------------
                        'Audio frequency oscillator
                        '------------------------------------
                        rdlong  x, p_socket_freq
                        shr     x, #20
                        add     x, #1
                        mov     y, OSC_FREQ_RANGE
                        call    #_mult
                        shr     y, #11
                        add     y, #OSC_FREQ_MIN_HZ

                        mov     x, OSC_1HZ_STEP_FXP_16_16
                        call    #_mult

                        add     angle_16_16_fxp, y
                        mov     sin, angle_16_16_fxp
                        shr     sin, #16                                          '  Convert from 16.16 fixed point angle to integer angle (where $1fff = 360 degrees)
                        call    #_getsin

                        shl     sin, #14                                          ' Ouput at 1/2 max signal amplitude

                        '------------------------------------
                        'Output Audio
                        '------------------------------------
                        wrlong  sin, p_socket_audio_out
                        

                        jmp     #_frame_sync

'------------------------------------
'Get sine/cosine                                    
'------------------------------------
' 
'
'       quadrant:    1            2            3            4
'          angle:    $0000..$07FF $0800..$0FFF $1000..$17FF $1800..$1FFF
'    table index:    $0000..$07FF $0800..$0001 $0000..$07FF $0800..$0001
'         mirror:    +offset      -offset      +offset      -offset
'           flip:    +sample      +sample      -sample      -sample
'
' on entry: sin[12..0] holds angle (0° to just under 360°)
' on exit: sin holds signed value ranging from $0000FFFF ('1') to
' $FFFF0001 ('-1')
'------------------------------------ 
_getcos                 add     sin,sin_90      'for cosine, add 90°
_getsin                 test    sin,sin_90 wc   'get quadrant 2|4 into c
                        test    sin,sin_180 wz  'get quadrant 3|4 into nz
                        negc    sin,sin         'if quadrant 2|4, negate offset
                        or      sin,sin_table   'or in sin table address >> 1
                        shl     sin,#1          'shift left to get final word address
                        rdword  sin,sin         'read word sample from $E000 to $F000
                        negnz   sin,sin         'if quadrant 3|4, negate sample
_getsin_ret
_getcos_ret             ret                     '39..54 clocks
                                                '(variance due to HUB sync on RDWORD)

sin_90                  long    $0800
sin_180                 long    $1000
sin_table               long    $E000 >> 1      'sine table base shifted right
sin                     long    0



'------------------------------------
'Multiply                                    
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
'Divide                                    
'------------------------------------
' Divide x[31..0] by y[15..0] (y[16] must be 0)
' on exit, quotient is in x[15..0] and remainder is in x[31..16]
'------------------------------------  
_divide                 shl y,#15               'get divisor into y[30..15]
                        mov t,#16               'ready for 16 quotient bits
                        
_div_loop               cmpsub x,y wc           'if y =< x then subtract it, set C
                        rcl x,#1                'rotate c into quotient, shift dividend 
                        djnz t,#_div_loop       'loop until done
                        
_divide_ret             ret                     'quotient in x[15..0], rem. in x[31..16]

'------------------------------------
'Initialized Data                                      
'------------------------------------
OSC_FREQ_RANGE              long  OSC_FREQ_MAX_HZ -  OSC_FREQ_MIN_HZ
OSC_1HZ_STEP_FXP_16_16      long  hw#ANG_360 * hw#INT_TO_FXP_16_16 / hw#AUDIO_SAMPLE_RATE 

HALF_MAX                    long  $FFFF
WORD_MASK                   long  $0000ffff
WORD_NEG                    long  $80000000
BLINK_BIT                   long  $00001000
SIGNAL_TRUE                 long  $40000000
KNOB_POSITION_MAX           long  hw#KNOB_POSITION_MAX
ANGLE_STEP_MIN_16_16_FXP    long  $00001fff

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
angle_16_16_fxp           res     1
lfo                       res     1
x                         res     1
y                         res     1
t                         res     1

p_system_state_block      res     1
p_module_control_block    res     1
previous_microframe       res     1
current_microframe        res     1
p_ss_overrun_detect       res     1   

p_frame_counter           res     1
p_socket_audio_out        res     1 
p_socket_freq             res     1 
p_socket_bypass           res     1 
p_socket_on               res     1

blink_counter             res     1



sawtooth_value            res     1
sawtooth_rising           res     1
capture_count             res     1

                          fit                 