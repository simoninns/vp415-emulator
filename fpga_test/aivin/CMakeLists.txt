cmake_minimum_required(VERSION 3.16)
project(Domesday-Player-FPGA)

# Define FPGA parameters
set(FPGA_TYPE hx8k)
set(FPGA_PKG ct256)
set(PCF_FILE ${CMAKE_CURRENT_SOURCE_DIR}/pcf/ice40hx8k-evb.pcf)
set(TARGET_NAME aivin)

# Define Verilog source files directory
set(VERILOG_SRC_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src)
set(SRC_MODULES
    ${VERILOG_SRC_DIR}/${TARGET_NAME}.v
    ${VERILOG_SRC_DIR}/nreset.v
    ${VERILOG_SRC_DIR}/statusleds.v
)

# Target JSON file
add_custom_command(
    OUTPUT ${TARGET_NAME}.json
    COMMAND yosys -ql ${TARGET_NAME}-yosys.log -p "synth_ice40 -top top -json ${TARGET_NAME}.json" ${SRC_MODULES}
    DEPENDS ${SRC_MODULES}
    COMMENT "Running Yosys synthesis"
    VERBATIM
)

# Target ASC file
add_custom_command(
    OUTPUT ${TARGET_NAME}.asc
    COMMAND nextpnr-ice40 --${FPGA_TYPE} --package ${FPGA_PKG} --json ${TARGET_NAME}.json --pcf ${PCF_FILE} --asc ${TARGET_NAME}.asc
    DEPENDS ${TARGET_NAME}.json ${PCF_FILE}
    COMMENT "Running NextPNR for place & route"
    VERBATIM
)

# Timing report
add_custom_command(
    OUTPUT ${TARGET_NAME}.rpt
    COMMAND icetime -d ${FPGA_TYPE} -mtr ${TARGET_NAME}.rpt ${TARGET_NAME}.asc
    DEPENDS ${TARGET_NAME}.asc
    COMMENT "Running icetime timing analysis"
    VERBATIM
)

# Bitstream generation
add_custom_command(
    OUTPUT ${TARGET_NAME}.bin
    COMMAND icepack ${TARGET_NAME}.asc ${TARGET_NAME}.bin
    DEPENDS ${TARGET_NAME}.asc
    COMMENT "Generating FPGA bitstream"
    VERBATIM
)

# Define build targets
add_custom_target(${TARGET_NAME}-synth ALL DEPENDS ${TARGET_NAME}.json)
add_custom_target(${TARGET_NAME}-pnr ALL DEPENDS ${TARGET_NAME}.asc)
add_custom_target(${TARGET_NAME}-report ALL DEPENDS ${TARGET_NAME}.rpt)
add_custom_target(${TARGET_NAME}-bitstream ALL DEPENDS ${TARGET_NAME}.bin)

# GUI target
add_custom_target(${TARGET_NAME}-gui
    COMMAND nextpnr-ice40 --gui --${FPGA_TYPE} --package ${FPGA_PKG} --json ${TARGET_NAME}.json --pcf ${PCF_FILE} --asc ${TARGET_NAME}.asc
    DEPENDS ${TARGET_NAME}.json
    COMMENT "Launching NextPNR GUI"
    VERBATIM
)

# Program the FPGA
add_custom_target(${TARGET_NAME}-fpga-upload
    COMMAND iceprogduino ${TARGET_NAME}.bin
    DEPENDS ${TARGET_NAME}.bin
    COMMENT "Uploading bitstream to FPGA"
    VERBATIM
)
