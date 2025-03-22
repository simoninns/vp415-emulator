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
        qDebug() << "MainWindow::dataReceived() - Data received: " << data;
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

void MainWindow::dataReceived(const QByteArray &data) {
    qDebug() << "MainWindow::dataReceived() - Data received: " << data;
}