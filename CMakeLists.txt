cmake_minimum_required(VERSION 3.16)
project(vp415-emulator)

# Add FPGA subdirectory if the required tools are present
find_program(YOSYS yosys)
find_program(NEXTPNR nextpnr-ice40)
find_program(ICETIME icetime)
find_program(ICEPACK icepack)

if(YOSYS AND NEXTPNR AND ICETIME AND ICEPACK)
    add_subdirectory(fpga/videothru)
    add_subdirectory(fpga/beebthru)
else()
    message(WARNING "FPGA tools not found - skipping FPGA build")
    message(STATUS "Required tools: yosys, nextpnr-ice40, icetime, icepack")
endif()