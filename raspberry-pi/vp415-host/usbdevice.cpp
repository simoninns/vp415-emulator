/************************************************************************

    usbdevice.cpp

    VP415-host - A host application for the VP415 Emulator
    VP415-Emulator
    Copyright (C) 2025 Simon Inns

    This file is part of VP415-Emulator.

    This is free software: you can redistribute it and/or
    modify it under the terms of the GNU General Public License as
    published by the Free Software Foundation, either version 3 of the
    License, or (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

    Email: simon.inns@gmail.com

************************************************************************/

#include "usbdevice.h"

UsbDevice::UsbDevice(QObject *parent) :
    QObject(parent),
    m_usbContext(nullptr),
    m_deviceHandle(nullptr),
    m_vendorId(0),
    m_productId(0),
    m_initialized(false),
    m_deviceConnected(false)
{
    // Connect timer signal
    connect(&m_pollTimer, &QTimer::timeout, this, &UsbDevice::pollForEvents);
}

UsbDevice::~UsbDevice()
{
    // Clean up resources
    stopPolling();
    
    if (m_deviceConnected) {
        closeDevice();
    }
    
    if (m_initialized) {
        libusb_exit(m_usbContext);
        m_usbContext = nullptr;
        m_initialized = false;
        qDebug() << "USB: libusb context released";
    }
}

bool UsbDevice::initialize(uint16_t vendorId, uint16_t productId)
{
    qDebug() << "USB: Initializing with VID:" << QString("0x%1").arg(vendorId, 4, 16, QChar('0'))
             << "PID:" << QString("0x%1").arg(productId, 4, 16, QChar('0'));
    
    // Store device identifiers
    m_vendorId = vendorId;
    m_productId = productId;
    
    // Initialize libusb
    int result = libusb_init(&m_usbContext);
    if (result < 0) {
        QString errorMessage = QString("Failed to initialize libusb: %1").arg(libusb_error_name(result));
        emit errorOccurred(errorMessage);
        qDebug() << "USB:" << errorMessage;
        return false;
    }
    
    // Enable debug output
    #ifdef QT_DEBUG
    libusb_set_option(m_usbContext, LIBUSB_OPTION_LOG_LEVEL, LIBUSB_LOG_LEVEL_WARNING);
    #endif
    
    // List all USB devices for debugging - this helps identify if the device is visible at all
    listConnectedDevices();
    
    m_initialized = true;
    qDebug() << "USB: Successfully initialized libusb";
    
    return true;
}

// Add this new method to list all connected USB devices
void UsbDevice::listConnectedDevices() 
{
    if (m_usbContext == nullptr) {
        qDebug() << "USB: Cannot list devices - context not initialized";
        return;
    }
    
    qDebug() << "USB: Listing all connected USB devices:";
    
    libusb_device **devs;
    ssize_t cnt = libusb_get_device_list(m_usbContext, &devs);
    
    if (cnt < 0) {
        qDebug() << "USB: Failed to get device list:" << libusb_error_name(static_cast<int>(cnt));
        return;
    }
    
    qDebug() << "USB: Found" << cnt << "USB devices";
    
    for (ssize_t i = 0; i < cnt; i++) {
        libusb_device *device = devs[i];
        struct libusb_device_descriptor desc;
        
        int r = libusb_get_device_descriptor(device, &desc);
        if (r < 0) {
            qDebug() << "USB: Failed to get device descriptor";
            continue;
        }
        
        uint8_t busNum = libusb_get_bus_number(device);
        uint8_t devAddr = libusb_get_device_address(device);
        
        qDebug() << "USB: Device" << i 
                 << "Bus:" << busNum 
                 << "Address:" << devAddr
                 << "VID:" << QString("0x%1").arg(desc.idVendor, 4, 16, QChar('0'))
                 << "PID:" << QString("0x%1").arg(desc.idProduct, 4, 16, QChar('0'));
                 
        // Check if this is our target device
        if (desc.idVendor == m_vendorId && desc.idProduct == m_productId) {
            qDebug() << "USB: *** Target device found in device list! ***";
        }
    }
    
    libusb_free_device_list(devs, 1);
}

void UsbDevice::startPolling(int pollIntervalMs)
{
    if (!m_initialized) {
        qDebug() << "USB: Cannot start polling - not initialized";
        return;
    }
    
    qDebug() << "USB: Starting device polling with interval" << pollIntervalMs << "ms";
    
    // Stop any existing timer
    if (m_pollTimer.isActive()) {
        m_pollTimer.stop();
    }
    
    // Start polling timer
    m_pollTimer.start(pollIntervalMs);
    
    // Do an initial poll
    pollForEvents();
}

void UsbDevice::stopPolling()
{
    if (m_pollTimer.isActive()) {
        m_pollTimer.stop();
        qDebug() << "USB: Polling stopped";
    }
}

void UsbDevice::pollForEvents()
{
    if (!m_initialized) {
        return;
    }
    
    // Process any pending USB events
    struct timeval tv = {0, 0};
    libusb_handle_events_timeout(m_usbContext, &tv);
    
    // Check device connection state
    if (m_deviceConnected) {
        // Check if device is still connected by performing a simple control transfer
        uint8_t buffer[1];
        int result = libusb_control_transfer(
            m_deviceHandle,
            LIBUSB_ENDPOINT_IN | LIBUSB_REQUEST_TYPE_STANDARD | LIBUSB_RECIPIENT_DEVICE,
            LIBUSB_REQUEST_GET_STATUS,
            0, 0, buffer, 1, 10);
        
        if (result < 0) {
            qDebug() << "USB: Device disconnected, error:" << libusb_error_name(result);
            closeDevice();
            emit deviceDisconnected();
        }
    } else {
        // Try to open the device if not already connected
        if (openDevice()) {
            qDebug() << "USB: Device connected";
            emit deviceConnected();
        } else {
            // Refresh the device list periodically to see if the device appears
            static int refreshCount = 0;
            if (refreshCount++ % 100 == 0) {
                listConnectedDevices();
            }
        }
    }
}

bool UsbDevice::openDevice()
{
    if (!m_initialized || m_deviceConnected) {
        return false;
    }
    
    qDebug() << "USB: Attempting to open device with VID:"
             << QString("0x%1").arg(m_vendorId, 4, 16, QChar('0'))
             << "PID:" << QString("0x%1").arg(m_productId, 4, 16, QChar('0'));
    
    // Try to open the device with the specified VID/PID
    m_deviceHandle = libusb_open_device_with_vid_pid(m_usbContext, m_vendorId, m_productId);
    if (m_deviceHandle == nullptr) {
        // Device not found, only log this occasionally to avoid flooding console
        static int missCount = 0;
        if (missCount++ % 20 == 0) {
            qDebug() << "USB: Device not found - please check:";
            qDebug() << "     1. Is the device connected?";
            qDebug() << "     2. Do you have correct permissions? (try running with sudo)";
            qDebug() << "     3. Is the VID/PID correct?";
            
            // Refresh device list occasionally
            listConnectedDevices();
        }
        return false;
    }
    
    qDebug() << "USB: Found device with VID:"
             << QString("0x%1").arg(m_vendorId, 4, 16, QChar('0'))
             << "PID:" << QString("0x%1").arg(m_productId, 4, 16, QChar('0'));
    
    // Get device information
    libusb_device* dev = libusb_get_device(m_deviceHandle);
    uint8_t busNum = libusb_get_bus_number(dev);
    uint8_t devAddr = libusb_get_device_address(dev);
    qDebug() << "USB: Device located at bus:" << busNum << "address:" << devAddr;
    
    // Get configuration info
    struct libusb_config_descriptor *config;
    int result = libusb_get_active_config_descriptor(dev, &config);
    if (result < 0) {
        qDebug() << "USB: Failed to get config descriptor:" << libusb_error_name(result);
    } else {
        qDebug() << "USB: Device has" << (int)config->bNumInterfaces << "interfaces";
        libusb_free_config_descriptor(config);
    }
    
    // Check if kernel driver is active and detach it if needed
    int interface = 0;
    if (libusb_kernel_driver_active(m_deviceHandle, interface) == 1) {
        qDebug() << "USB: Kernel driver active, attempting to detach";
        result = libusb_detach_kernel_driver(m_deviceHandle, interface);
        if (result < 0) {
            qDebug() << "USB: Failed to detach kernel driver:" << libusb_error_name(result);
            // Continue anyway, might still work
        } else {
            qDebug() << "USB: Kernel driver detached successfully";
        }
    }
    
    // Try to set configuration
    result = libusb_set_configuration(m_deviceHandle, 1); // Use configuration 1
    if (result < 0) {
        qDebug() << "USB: Warning - Failed to set configuration:" << libusb_error_name(result);
        // Continue anyway, might still work with default configuration
    }
    
    // Claim interface 0 (the default interface)
    result = libusb_claim_interface(m_deviceHandle, interface);
    if (result < 0) {
        qDebug() << "USB: Failed to claim interface:" << libusb_error_name(result);
        
        // More detailed error reporting
        switch (result) {
            case LIBUSB_ERROR_BUSY:
                qDebug() << "USB: Interface is already claimed by another program";
                break;
            case LIBUSB_ERROR_NO_DEVICE:
                qDebug() << "USB: Device has been disconnected";
                break;
            case LIBUSB_ERROR_ACCESS:
                qDebug() << "USB: Insufficient permissions - try running as sudo";
                break;
            default:
                break;
        }
        
        libusb_close(m_deviceHandle);
        m_deviceHandle = nullptr;
        
        QString errorMessage = QString("Failed to claim interface: %1").arg(libusb_error_name(result));
        emit errorOccurred(errorMessage);
        return false;
    }
    
    // Successfully opened device
    m_deviceConnected = true;
    qDebug() << "USB: Device opened and interface claimed successfully";
    return true;
}

void UsbDevice::closeDevice()
{
    if (!m_deviceConnected || m_deviceHandle == nullptr) {
        return;
    }
    
    qDebug() << "USB: Closing device connection";
    
    // Release interface
    libusb_release_interface(m_deviceHandle, 0);
    
    // Close device
    libusb_close(m_deviceHandle);
    m_deviceHandle = nullptr;
    m_deviceConnected = false;
    
    qDebug() << "USB: Device closed";
}

