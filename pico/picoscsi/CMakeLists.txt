add_executable(picoscsi
        src/main.c
        src/debug.c
        src/hostadapter.c
        src/statusled.c
        src/filesystem.c
        src/fcode.c
        src/scsi.c
)

# Enable USB output for debugging
pico_enable_stdio_usb(picoscsi 1)
pico_enable_stdio_uart(picoscsi 0)

# pull in common dependencies
target_link_libraries(picoscsi pico_stdlib hardware_pio)

# create map/bin/hex/uf2 file etc.
pico_add_extra_outputs(picoscsi)