## This file is a general .xdc for the Arty S7-50 Rev. E
## To use it in a project:
## - uncomment the lines corresponding to used pins
## - rename the used ports (in each line, after get_ports) according to the top level signal names in the project

## Clock Signals
## Main 100MHz system clock
set_property -dict {PACKAGE_PIN R2 IOSTANDARD SSTL135} [get_ports clk100mhz]
create_clock -period 10.000 -name sys_clk_pin -waveform {0.000 5.000} -add [get_ports clk100mhz]
## Allow non-dedicated clock routing to resolve placement conflict
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets u_pll/clkref_buffered_w]

## LEDs (LD0-1 are RGB, using LD2-5 for simple LEDs)
#set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {led[0]}]  # LD0 RGB - not used
#set_property -dict {PACKAGE_PIN F18 IOSTANDARD LVCMOS33} [get_ports {led[1]}]  # LD1 RGB - not used  
set_property -dict {PACKAGE_PIN E18 IOSTANDARD LVCMOS33} [get_ports {led[0]}];
set_property -dict {PACKAGE_PIN F13 IOSTANDARD LVCMOS33} [get_ports {led[1]}];
set_property -dict {PACKAGE_PIN E13 IOSTANDARD LVCMOS33} [get_ports {led[2]}];
set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports {led[3]}];

## Buttons
# set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports i_rst]
# set_property -dict { PACKAGE_PIN K16   IOSTANDARD LVCMOS33 } [get_ports { btn[0] }];
# set_property -dict { PACKAGE_PIN J16   IOSTANDARD LVCMOS33 } [get_ports { btn[1] }];
# set_property -dict { PACKAGE_PIN H13   IOSTANDARD LVCMOS33 } [get_ports { btn[2] }];

# set_property -dict { PACKAGE_PIN H14   IOSTANDARD LVCMOS33 } [get_ports { sw[0] }];
# set_property -dict { PACKAGE_PIN H18   IOSTANDARD LVCMOS33 } [get_ports { sw[1] }];
# set_property -dict { PACKAGE_PIN G18   IOSTANDARD LVCMOS33 } [get_ports { sw[2] }];
# set_property -dict { PACKAGE_PIN M5    IOSTANDARD SSTL135 } [get_ports { sw[3] }];


## USB-UART Interface
set_property -dict {PACKAGE_PIN R12 IOSTANDARD LVCMOS33} [get_ports { uart_rxd_out }];
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports { uart_txd_in }];
#set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33 } [get_ports { uart_rxd_out }]; #IO_L19N_T3_VREF_16 Sch=uart_rxd_outs

##Quad SPI Flash - moved to unused button pins to avoid conflicts
set_property -dict { PACKAGE_PIN U11   IOSTANDARD LVCMOS33 } [get_ports { qspi_sck }];
set_property -dict { PACKAGE_PIN V15   IOSTANDARD LVCMOS33 } [get_ports { qspi_cs }];

## Configuration options, can be used for all designs
set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]
set_property BITSTREAM.CONFIG.SPI_BUSWIDTH 4 [current_design]
set_property CONFIG_MODE SPIx4 [current_design]

## Matrix Display Pins (HUB75 interface)
## Data lines (level shifter 1)
set_property -dict { PACKAGE_PIN T14  IOSTANDARD LVCMOS33 } [get_ports { matrix[14] }];  # JA1 -> R1
set_property -dict { PACKAGE_PIN U17  IOSTANDARD LVCMOS33 } [get_ports { matrix[13] }];  # JA2 -> G1
set_property -dict { PACKAGE_PIN R16  IOSTANDARD LVCMOS33 } [get_ports { matrix[12] }];  # JA3 -> B1
set_property -dict { PACKAGE_PIN R17  IOSTANDARD LVCMOS33 } [get_ports { matrix[11] }];  # JA4 -> R2
set_property -dict { PACKAGE_PIN U18  IOSTANDARD LVCMOS33 } [get_ports { matrix[10] }];  # JA7 -> G2
set_property -dict { PACKAGE_PIN V17  IOSTANDARD LVCMOS33 } [get_ports { matrix[9] }];  # JA8 -> B2
set_property -dict { PACKAGE_PIN U16  IOSTANDARD LVCMOS33 } [get_ports { matrix[8]  }];  # JA9 -> E (row addr bit 4)
set_property -dict { PACKAGE_PIN R15  IOSTANDARD LVCMOS33 } [get_ports { matrix[7]  }];  # JA10 -> A (row addr bit 0)

## Control / address (level shifter 2)
set_property -dict { PACKAGE_PIN P13  IOSTANDARD LVCMOS33 } [get_ports { matrix[6]  }];  # JB1 -> B
set_property -dict { PACKAGE_PIN T15  IOSTANDARD LVCMOS33 } [get_ports { matrix[5]  }];  # JB2 -> C
set_property -dict { PACKAGE_PIN R13  IOSTANDARD LVCMOS33 } [get_ports { matrix[4]  }];  # JB3 -> D
set_property -dict { PACKAGE_PIN H16  IOSTANDARD LVCMOS33 } [get_ports { matrix[3] }];  # JB4 -> CLK (panel shift clock)
set_property -dict { PACKAGE_PIN V14  IOSTANDARD LVCMOS33 } [get_ports { matrix[2] }];  # JB7 -> LAT
set_property -dict { PACKAGE_PIN H17  IOSTANDARD LVCMOS33 } [get_ports { matrix[1]  }];  # JB8 -> OE (panel)

## ARCADE CONTROLLER PINS
set_property -dict { PACKAGE_PIN U12 IOSTANDARD LVCMOS33 } [get_ports { arcade[0] }]; # ck_io32 -> ARC1
set_property -dict { PACKAGE_PIN V13 IOSTANDARD LVCMOS33 } [get_ports { arcade[1] }]; # ck_io31 -> ARC2
set_property -dict { PACKAGE_PIN T12 IOSTANDARD LVCMOS33 } [get_ports { arcade[2] }]; # ck_io30 -> ARC3
set_property -dict { PACKAGE_PIN T13 IOSTANDARD LVCMOS33 } [get_ports { arcade[3] }]; # ck_io29 -> ARC4
set_property -dict { PACKAGE_PIN R11 IOSTANDARD LVCMOS33 } [get_ports { arcade[4] }]; # ck_io28 -> ARC5
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports { arcade[5] }]; # ck_io27 -> ARC6
set_property -dict { PACKAGE_PIN R14 IOSTANDARD LVCMOS33 } [get_ports { arcade[6] }]; # ck_io3 -> ARC7
set_property -dict { PACKAGE_PIN L16 IOSTANDARD LVCMOS33 } [get_ports { arcade[7] }]; # ck_io2 -> ARC8
set_property -dict { PACKAGE_PIN N13 IOSTANDARD LVCMOS33 } [get_ports { arcade[8] }]; # ck_io1 -> ARC9
set_property -dict { PACKAGE_PIN L13 IOSTANDARD LVCMOS33 } [get_ports { arcade[9] }]; # ck_io0 -> ARC10

set_property -dict { PACKAGE_PIN K14 IOSTANDARD LVCMOS33 } [get_ports { flag }]; # ck_io12  -> flag

## Level shifter OE (separate from panel OE)
set_property -dict { PACKAGE_PIN G16  IOSTANDARD LVCMOS33 } [get_ports { matrix[0] }];  # JB9 -> LS_OE

## SW3 is assigned to a pin M5 in the 1.35v bank. This pin can also be used as
## the VREF for BANK 34. To ensure that SW3 does not define the reference voltage
## and to be able to use this pin as an ordinary I/O the following property must
## be set to enable an internal VREF for BANK 34. Since a 1.35v supply is being
## used the internal reference is set to half that value (i.e. 0.675v). Note that
## this property must be set even if SW3 is not used in the design.
set_property INTERNAL_VREF 0.675 [get_iobanks 34]


