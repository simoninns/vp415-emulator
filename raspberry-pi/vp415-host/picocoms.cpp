/************************************************************************

    picocoms.cpp

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

#include "picocoms.h"
#include <QDebug>

PicoComs::PicoComs(QObject *parent) : QObject(parent) {
    m_isSerialPortOpen = false;
    m_serialPortName = "";
    
    // Initialize the serial port
    m_serialPort = new QSerialPort(this);
    
    // Connect the readyRead signal to our slot
    connect(m_serialPort, &QSerialPort::readyRead, this, &PicoComs::readData);
}

PicoComs::~PicoComs() {
    if (m_isSerialPortOpen) {
        closeSerialPort();
    }
    
    delete m_serialPort;
}

bool PicoComs::openSerialPort(QString serialPortDeviceName) {
    if (m_isSerialPortOpen) {
        closeSerialPort();
    }
    
    m_serialPortName = serialPortDeviceName;
    
    // Configure the serial port
    m_serialPort->setPortName(m_serialPortName);
    m_serialPort->setBaudRate(QSerialPort::Baud115200); // Set appropriate baud rate
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);
    
    // Try to open the serial port
    if (m_serialPort->open(QIODevice::ReadWrite)) {
        m_isSerialPortOpen = true;
        qDebug() << "PicoComs::openSerialPort() - Serial port opened:" << m_serialPortName;
    } else {
        qDebug() << "PicoComs::openSerialPort() - Failed to open serial port:" << m_serialPortName 
                 << "- Error:" << m_serialPort->errorString();
        return false;
    }

    // Flush the serial port
    m_serialPort->clear(QSerialPort::AllDirections);

    return true;
}

void PicoComs::closeSerialPort() {
    if (m_isSerialPortOpen) {
        m_serialPort->close();
        m_isSerialPortOpen = false;
        qDebug() << "PicoComs::closeSerialPort() - Serial port closed:" << m_serialPortName;
    }
}

// The underlying communication function is simple.  First 2 bytes are received representing
// a uint16_t length of the data to be sent from the pico.  Then the data is received.  We will then
// respond with a uint16_t length of the data to be sent.  The data is then sent
// Note: The maximum length of data that can be sent or received is 512 bytes.
// Note: The txLength and rxLength do not include the 2 bytes used to represent the length.
//
// We will continue to read data until we have received the expected number of bytes, then we will
// emit a signal to the main window to process the data.  The main window will then respond with the
// data to be sent back to the pico.
void PicoComs::readData() {
    // Read the first 2 bytes to get the length of the data to be received
    if (m_serialPort->bytesAvailable() < 2) {
        return;
    }
    
    QByteArray rxData = m_serialPort->read(2);
    uint16_t rxLength = (static_cast<uint16_t>(rxData[0]) << 8) | static_cast<uint16_t>(rxData[1]);

    qDebug() << "PicoComs::readData() - Expecting data length: " << rxLength << " rxData[0]: " << static_cast<uint16_t>(rxData[0]) << " rxData[1]: " << static_cast<uint16_t>(rxData[1]);
    
    // Read the data
    while (m_serialPort->bytesAvailable() < rxLength) {
        if (!m_serialPort->waitForReadyRead(1000)) {
            qDebug() << "PicoComs::readData() - Timed out waiting for data";
            return;
        }
    }
    
    rxData = m_serialPort->read(rxLength);
    
    // Emit the signal to the main window to process the data
    emit dataReceived(rxData);
}

void PicoComs::writeData(QByteArray txData) {
    // Write the length of the data to be sent
    uint16_t txLength = txData.length();
    QByteArray txLengthData;

    txLengthData.append((txLength >> 8) & 0xFF);
    txLengthData.append(txLength & 0xFF);
    
    m_serialPort->write(txLengthData);
    m_serialPort->write(txData);
}
