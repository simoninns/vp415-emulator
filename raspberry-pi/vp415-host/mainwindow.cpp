/************************************************************************

    mainwindow.cpp

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

#include "mainwindow.h"
#include "./ui_mainwindow.h"

// https://doc.qt.io/vscodeext/vscodeext-tutorials-qt-widgets.html

MainWindow::MainWindow(QWidget *parent, QString serialDeviceName)
    : QMainWindow(parent), ui(new Ui::MainWindow) {
    ui->setupUi(this);

    // Add a status bar
    statusBar = new QStatusBar();
    setStatusBar(statusBar);

    // Connect the PicoComs dataReceived signal to the MainWindow slot
    connect(&m_picoComs, &PicoComs::dataReceived, this, [this](const QByteArray &data) {
        commandReceived(data);
    });

    // Open the serial port
    if (!m_picoComs.openSerialPort(serialDeviceName)) {
        qDebug() << "MainWindow::MainWindow() - Failed to open serial port: " << serialDeviceName;
        exit(EXIT_FAILURE);
    }
}

MainWindow::~MainWindow() { delete ui; }

void MainWindow::on_pushButton_clicked() {
    qDebug() << "MainWindow::on_pushButton_clicked() - Button clicked";
}

void MainWindow::commandReceived(const QByteArray &data) {
    uint8_t command = static_cast<uint8_t>(data[0]);
    qDebug() << "MainWindow::dataReceived() - Command received: " << command;

    // Process the command
    switch(command) {
        case 0x01: // PIC_SET_MOUNT_STATE:
            qDebug() << "MainWindow::dataReceived() - PIC_SET_MOUNT_STATE";
            commandSetMountState(data[1]);
            break;
        case 0x02: // PIC_GET_MOUNT_STATE:
            qDebug() << "MainWindow::dataReceived() - PIC_GET_MOUNT_STATE";
            commandGetMountState();
            break;
        default:
            qDebug() << "MainWindow::dataReceived() - Unknown command: " << data[0];
            break;
    }
}

void MainWindow::commandSetMountState(uint8_t state) {
    qDebug() << "MainWindow::commandSetMountState() - State: " << state;
    m_picoComs.writeData(QByteArray(1, 0x00));
}

void MainWindow::commandGetMountState() {
    qDebug() << "MainWindow::commandGetMountState()";
    m_picoComs.writeData(QByteArray(1, 0x00));
}