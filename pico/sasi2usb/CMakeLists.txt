add_executable(sasi2usb
        src/main.c
)

# pull in common dependencies
target_link_libraries(sasi2usb pico_stdlib)

# create map/bin/hex/uf2 file etc.
pico_add_extra_outputs(sasi2usb)