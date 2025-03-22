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

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent), ui(new Ui::MainWindow) {
    ui->setupUi(this);

    // Add a status bar
    statusBar = new QStatusBar();
    setStatusBar(statusBar);
    usb_device_detached();

    // Handle the USB device
    usbDevice.initialize(0x1D50, 0x7504);
    //connect(&usbDevice, &UsbDevice::deviceConnected, this, &MainWindow::usb_device_attached);
    //connect(&usbDevice, &UsbDevice::deviceDisconnected, this, &MainWindow::usb_device_detached);
    usbDevice.startPolling(500);
}

MainWindow::~MainWindow() { delete ui; }

void MainWindow::on_pushButton_clicked() {
    qDebug() << "MainWindow::on_pushButton_clicked() - Button clicked";
}

void MainWindow::usb_device_attached(uint16_t vid, uint16_t pid) {
    qDebug() << "MainWindow::usb_device_attached() - USB device attached: VID="
             << QString("0x%1").arg(vid, 4, 16, QChar('0'))
             << " PID=" << QString("0x%1").arg(pid, 4, 16, QChar('0'));
    statusBar->showMessage(
        "USB device ready: VID=" + QString("0x%1").arg(vid, 4, 16, QChar('0')) +
        " PID=" + QString("0x%1").arg(pid, 4, 16, QChar('0')));
}

void MainWindow::usb_device_detached() {
    qDebug() << "MainWindow::usb_device_detached() - USB device detached";
    statusBar->showMessage("No USB device attached");
}