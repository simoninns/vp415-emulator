/************************************************************************

    usbdevice.h

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

#ifndef USBDEVICE_H
#define USBDEVICE_H

#include <libusb-1.0/libusb.h>
#include <QObject>
#include <QDebug>
#include <QTimer>

class UsbDevice : public QObject
{
    Q_OBJECT

public:
    explicit UsbDevice(QObject *parent = nullptr);
    ~UsbDevice();

    // Initialize USB monitoring for specified VID/PID
    bool initialize(uint16_t vendorId, uint16_t productId);
    
    // Check if device is currently connected
    bool isDeviceConnected() const { return m_deviceConnected; }
    
    // Get device handle (nullptr if not connected)
    libusb_device_handle* getDeviceHandle() const { return m_deviceHandle; }

public slots:
    // Start/stop device polling
    void startPolling(int pollIntervalMs = 250);
    void stopPolling();

signals:
    // Device connection status signals
    void deviceConnected();
    void deviceDisconnected();
    void errorOccurred(const QString& errorMessage);

private slots:
    void pollForEvents();

private:
    // Device connection/disconnection handling
    bool openDevice();
    void closeDevice();
    void listConnectedDevices();
    
    // libusb context and device handling
    libusb_context* m_usbContext;
    libusb_device_handle* m_deviceHandle;
    
    // Device identifiers
    uint16_t m_vendorId;
    uint16_t m_productId;
    
    // State tracking
    bool m_initialized;
    bool m_deviceConnected;
    
    // Polling timer
    QTimer m_pollTimer;
};

#endif  // USBDEVICE_H