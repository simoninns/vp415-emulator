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

    return true;
}

void PicoComs::closeSerialPort() {
    if (m_isSerialPortOpen) {
        m_serialPort->close();
        m_isSerialPortOpen = false;
        qDebug() << "PicoComs::closeSerialPort() - Serial port closed:" << m_serialPortName;
    }
}

void PicoComs::readData()
{
    if (m_isSerialPortOpen) {
        QByteArray data = m_serialPort->readAll();
        if (!data.isEmpty()) {
            qDebug() << "PicoComs::readData() - Data received:" << data;
            emit dataReceived(data);
        }
    }
}