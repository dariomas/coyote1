''=======================================================================  
'' TITLE: COYOTE1_MODULE_Tremolo.spin        
''
'' DESCRIPTION:
''   A Tremolo effect.
''   The output volume is modulated by a LFO(Low Frequency Oscillator)
''   whose rate and depth can be controlled.
''
''   INPUTS:
''      IN:           Audio In
''      RATE:         Controls the frequency of the LFO.
''      DEPTH:        Controls the amplitude of the LFO modulation of
''                    the output signal.
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
''  1.1.0  08-15-08  Improve "Depth" behavior.
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
                        long    $03_80_00_00                                           'Module Signature
                        long    $00_01_01_00                                           'Module revision  (xx_AA_BB_CC = a.b.c)
                        long    0                                                      'Microframe requirement
                        long    0                                                      'SRAM requirement (heap)
                        long    0                                                      'RAM  requirement (internal propeller RAM)
                        long    0                                                      '(RESERVED0) - set to zero to ensure compatability with future OS versions
                        long    0                                                      '(RESERVED1) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED2) - set to zero to ensure compatability with future OS versions 
                        long    0                                                      '(RESERVED3) - set to zero to ensure compatability with future OS versions 
                        long    6                                                      'Number of sockets
                                                                                        
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
                        byte    "Rate",0                                               'Name
                        long    2 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "mSec",0                                               'Units  
                        long    LFO_PERIOD_MIN_MSEC                                    'Range Low
                        long    LFO_PERIOD_MAX_MSEC                                    'Range High
                        long    500                                                    'Default Value

                        'Socket 3
                        byte    "Depth",0                                              'Name                                                                                                             
                        long    3 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    "%",0                                                  'Units  
                        long    0                                                      'Range Low            
                        long    100                                                    'Range High
                        long    100                                                    'Default Value

                        'Socket 4
                        byte    "+Bypass",0                                            'Name                                                                                                           
                        long    5 | hw#SOCKET_FLAG__INPUT                              'Flags and ID
                        byte    0  {null string}                                       'Units   
                        long    0                                                      'Range Low          
                        long    1                                                      'Range High         
                        long    0                                                      'Default Value

                        'Socket 5
                        byte    "+On",0                                                'Name                                                                                                         
                        long    6                                                      'Flags and ID
                        byte    0  {null string}                                       'Units 
                        long    0                                                      'Range Low
                        long    1                                                      'Range High
                        long    1                                                      'Default Value

                        byte    "Tremolo",0                                            'Module name
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
                        mov     p_socket_rate,      p_module_control_block
                        add     p_socket_rate,      #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (2 << 2)) 
                        mov     p_socket_depth,     p_module_control_block
                        add     p_socket_depth,     #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (3 << 2)) 
                        mov     p_socket_bypass,    p_module_control_block
                        add     p_socket_bypass,    #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (4 << 2)) 
                        mov     p_socket_on,        p_module_control_block
                        add     p_socket_on,        #(hw#MCB_OFFSET__SOCKET_EXCHANGE + (5 << 2)) 

'------------------------------------
'Effect processing loop
'------------------------------------

                        '------------------------------------
                        'Init
                        '------------------------------------ 
                        mov     angle_16_16_fxp, #0

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
        if_c_or_z       mov     r2, 0
        if_nc_and_nz    mov     r2, SIGNAL_TRUE        
                        wrlong  r2, p_socket_on
                        
                        'If bypassed, then just pass audio through
        if_c_or_z       wrlong  audio_in_sample, p_socket_audio_out
        if_c_or_z       jmp     #_frame_sync
                        
                        '------------------------------------
                        'Generate LFO (Low Frequency Oscillator)
                        '------------------------------------

                        'Read the RATE socket and use the value to determine the angular step per sample
                        rdlong  x, p_socket_rate
                        shr     x, #21
                        add     x, #1
                        mov     y, LFO_PERIOD_RANGE
                        call    #_mult
                        shr     y, #10
                        add     y, #LFO_PERIOD_MIN_MSEC

                        mov     x, LFO_CALCULATION_NUMERATOR
                        call    #_div19
                        and     x, QUOTIENT_MASK                                ' x now contains the 16.16 Fixed point angular step  

                        'Increment the LFO angle and calculate the sin   
                        add     angle_16_16_fxp, x                              ' Increment the current angle, based on LFO rate                                    
                        mov     sin, angle_16_16_fxp                                                                                                                
                        shr     sin, #16                                        ' Convert from 16.16 fixed point angle to integer angle (where $1fff = 360 degrees) 
                        call    #_getsin                                        ' Get the sin of the angle (returned in sin, as a signed value)                                  
                        add     sin, HALF_SIN_RANGE                             ' Convert result to a 17 bit positive integer                                       
                        shr     sin, #1                                         ' Shift result one bit to get a 16 bit positive integer                             

                        'Now scale the LFO amplitude by the "depth" setting 
                        rdlong  r1, p_socket_depth                              ' r1 = *p_socket_depth;
                        shr     r1, #15                                         ' r1 >>= 15;
                        mov     x, r1                                           ' x = r1;
                        mov     y, sin                                          ' y = sin;
                        call    #_mult                                          ' y = x * y;
                        shr     y, #16                                          ' y <<= 16;

                        'Add back the inverse of the "depth" setting, so that the LFO value always has a maximum of 0xffff.
                        'In other words, if depth_16 is the 16 bit representation of the depth knob, then
                        'when done...
                        '    y = (0xffff - depth_16) + sin(<current angle>) * depth_16
                        '    
                        mov     x, WORD_MASK                                    ' x = 0xffff;
                        sub     x, r1                                           ' x -= r1;
                        add     y, x                                            ' y += x;

                        '------------------------------------
                        'Modulate input with LFO
                        '------------------------------------
                        
                        'Get sample
                        mov     x, audio_in_sample

                        'Signed multiply y<signed 32> = (x<signed 32> * y<unsigned 16>)
                        test    x, SIGN_BIT  wz
                 if_nz  neg     x, x
                        shr     x, #16
                        call    #_mult
                        shl     y, #1
                 if_nz  neg     y, y

_modulate_done
                        wrlong  y, p_socket_audio_out

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
'19-Bit Divide (19 bit quotient, 13 bit denominator)
'------------------------------------
' Divide x[31..0] by y[12..0] (y[13] must be 0)
' on exit, quotient is in x[18..0] and remainder is in x[31..19]
'------------------------------------  
_div19                  shl y,#18               'get divisor into y[30..18]
                        mov t,#19               'ready for 19 quotient bits
                        
_div19_loop             cmpsub x,y wc           'if y =< x then subtract it, set C
                        rcl x,#1                'rotate c into quotient, shift dividend 
                        djnz t,#_div19_loop     'loop until done
                        
_div19_ret              ret                     'quotient in x[18..0], rem. in x[31..19]

'------------------------------------
'Initialized Data                                      
'------------------------------------
LFO_PERIOD_RANGE            long  LFO_PERIOD_MAX_MSEC -  LFO_PERIOD_MIN_MSEC
LFO_CALCULATION_NUMERATOR   long  $00BA2E8B
                                  'NOTE: This value is equavalent to the calculation: hw#MSEC_PER_SEC * hw#ANG_360 * hw#INT_TO_FXP_16_16 / hw#AUDIO_SAMPLE_RATE,
                                  '      but the IDE compiler does not have sufficient numerical resolution to evaluate it without overflowing, so it
                                  '      has been expressed as a pre-evaluated constant.


HALF_SIN_RANGE              long  $0000ffff
WORD_MASK                   long  $0000ffff
QUOTIENT_MASK               long  $0007ffff   'Divide returns 19 bit quotient
WORD_NEG                    long  $80000000
SIGNAL_TRUE                 long  $40000000
KNOB_POSITION_MAX           long  hw#KNOB_POSITION_MAX
ANGLE_STEP_MIN_16_16_FXP    long  $00001fff
SIGN_BIT                    long  $80000000

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

audio_in_sample           res     1

p_system_state_block      res     1
p_module_control_block    res     1
previous_microframe       res     1
current_microframe        res     1
p_ss_overrun_detect       res     1   

p_frame_counter           res     1  
p_socket_audio_in         res     1 
p_socket_audio_out        res     1 
p_socket_rate             res     1 
p_socket_depth            res     1 
p_socket_bypass           res     1 
p_socket_on               res     1

                          fit                 