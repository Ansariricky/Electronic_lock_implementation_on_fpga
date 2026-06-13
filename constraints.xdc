## =============================================================================
## Constraints file for: password_lock_top
## Board : Arty-S7 (Spartan-7, xc7s50csga324-1)
## Clock : 12 MHz onboard oscillator  (pin F14)
##
## PMOD JA (keypad) pinout:
##   JA pins 1-4  (L17/L18/M14/N14)  -> col[0..3]  (column INPUTS, active-low)
##   JA pins 5-8  (M16/M17/M18/N18)  -> row[0..3]  (row OUTPUTS,  active-low)
##
## PMOD JB (outputs) pinout:
##   JB pin 1 (P17) -> green_led
##   JB pin 2 (P18) -> red_led
##   JB pin 3 (R18) -> blue_led
##   JB pin 4 (T18) -> buzzer
##   JB pin 5 (P14) -> relay
## =============================================================================


## ----------------------------------------------------------------------------
## Clock  (12 MHz onboard oscillator)
## FIX 2: Added -waveform for clean STA.
## NOTE: Also update timer instantiation in password_lock_top.v to:
##         timer #(.CLK_FREQ(12_000_000)) t ( ... );
## ----------------------------------------------------------------------------
set_property PACKAGE_PIN F14 [get_ports clk]
set_property IOSTANDARD LVCMOS33 [get_ports clk]
create_clock -period 83.333 -waveform {0.000 41.667} -name sys_clk_pin [get_ports clk]


## ----------------------------------------------------------------------------
## Buttons  (active-high, on-board tactile switches)
## btn[0]=start  btn[1]=enter  btn[2]=clear  btn[3]=rst
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN G15   IOSTANDARD LVCMOS33 } [get_ports { start_btn }]
set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { enter_btn }]
set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { clear_btn }]
set_property -dict { PACKAGE_PIN H13   IOSTANDARD LVCMOS33 } [get_ports { rst       }]


## ----------------------------------------------------------------------------
## PMOD JA  - 4x4 Hex Keypad
##
## FIX 1 (CRITICAL): Original file had `ja[0]`..`ja[3]` as port names.
##   Those ports DO NOT exist in password_lock_top.v.  Vivado would error:
##     "ERROR: [Vivado 12-507] No ports matched 'ja[0]'"
##   AND col[0..3] would remain unconstrained, blocking bitstream generation.
##   Fix: Renamed to col[0]..col[3] to match the top-level port declaration.
##
## Wiring (connect keypad columns to JA pins 1-4, rows to JA pins 5-8):
##   JA_P1 (L17) -> col[0]    JA_P3 (M16) -> row[0]
##   JA_N1 (L18) -> col[1]    JA_N3 (M17) -> row[1]
##   JA_P2 (M14) -> col[2]    JA_P4 (M18) -> row[2]
##   JA_N2 (N14) -> col[3]    JA_N4 (N18) -> row[3]
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN L17   IOSTANDARD LVCMOS33 } [get_ports { col[0] }]
set_property -dict { PACKAGE_PIN L18   IOSTANDARD LVCMOS33 } [get_ports { col[1] }]
set_property -dict { PACKAGE_PIN M14   IOSTANDARD LVCMOS33 } [get_ports { col[2] }]
set_property -dict { PACKAGE_PIN N14   IOSTANDARD LVCMOS33 } [get_ports { col[3] }]

set_property -dict { PACKAGE_PIN M16   IOSTANDARD LVCMOS33 } [get_ports { row[0] }]
set_property -dict { PACKAGE_PIN M17   IOSTANDARD LVCMOS33 } [get_ports { row[1] }]
set_property -dict { PACKAGE_PIN M18   IOSTANDARD LVCMOS33 } [get_ports { row[2] }]
set_property -dict { PACKAGE_PIN N18   IOSTANDARD LVCMOS33 } [get_ports { row[3] }]


## ----------------------------------------------------------------------------
## PMOD JB  - LED / Buzzer / Relay outputs
## FIX 3: Removed extra leading space in green_led port name.
## ----------------------------------------------------------------------------
set_property -dict { PACKAGE_PIN P17   IOSTANDARD LVCMOS33 } [get_ports { green_led }]
set_property -dict { PACKAGE_PIN P18   IOSTANDARD LVCMOS33 } [get_ports { red_led   }]
set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { blue_led  }]
set_property -dict { PACKAGE_PIN T18   IOSTANDARD LVCMOS33 } [get_ports { buzzer    }]
set_property -dict { PACKAGE_PIN P14   IOSTANDARD LVCMOS33 } [get_ports { relay     }]


## ----------------------------------------------------------------------------
## Timing exceptions for asynchronous inputs
## FIX 4: cut timing paths from off-chip async inputs (keypad columns and
##   push-buttons).  These are already handled by 2-stage synchronizers in
##   the RTL, so Vivado must not try to time the setup/hold of these paths.
##   Without these, Vivado will issue timing-violation errors that can block
##   bitstream generation when timing is not met.
## ----------------------------------------------------------------------------
set_false_path -from [get_ports {col[*]}]
set_false_path -from [get_ports {start_btn}]
set_false_path -from [get_ports {enter_btn}]
set_false_path -from [get_ports {clear_btn}]
set_false_path -from [get_ports {rst}]


## ----------------------------------------------------------------------------
## Bitstream / configuration options (Arty-S7 standard settings)
## ----------------------------------------------------------------------------
set_property BITSTREAM.CONFIG.CONFIGRATE   50      [current_design]
set_property CONFIG_VOLTAGE                3.3     [current_design]
set_property CFGBVS                        VCCO    [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4       [current_design]
set_property CONFIG_MODE                   SPIx4   [current_design]
set_property BITSTREAM.GENERAL.COMPRESS    TRUE    [current_design]

## Required to use pin M5 (SW3) as ordinary I/O - internal VREF for bank 34
set_property INTERNAL_VREF 0.675 [get_iobanks 34]
