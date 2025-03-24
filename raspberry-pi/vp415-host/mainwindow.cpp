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

MainWindow::MainWindow(QWidget *parent, QString serialDeviceName, QString jsonFilename)
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

    // Open the initial disc
    if (jsonFilename != "") {
        openDisc(jsonFilename);
    } else {
        qDebug() << "MainWindow::MainWindow() - For BETA you must specify a JSON filename";
        exit(EXIT_FAILURE);
    }

    // Initial command states
    m_mountState = false;
}

MainWindow::~MainWindow() { delete ui; }

void MainWindow::on_pushButton_clicked() {
    qDebug() << "MainWindow::on_pushButton_clicked() - Button clicked";
}

void MainWindow::commandReceived(const QByteArray &data) {
    uint8_t command = static_cast<uint8_t>(data[0]);

    // Process the command
    switch(command) {
        case 0x01: // PIC_SET_MOUNT_STATE:
            qDebug() << "MainWindow::dataReceived() - Command received: PIC_SET_MOUNT_STATE";
            commandSetMountState(data[1]);
            break;
        case 0x02: // PIC_GET_MOUNT_STATE:
            qDebug() << "MainWindow::dataReceived() - Command received: PIC_GET_MOUNT_STATE";
            commandGetMountState();
            break;
        case 0x03: // PIC_GET_EFM_DATA_PRESENT:
            qDebug() << "MainWindow::dataReceived() - Command received: PIC_GET_EFM_DATA_PRESENT";
            commandGetEfmDataPresent();
            break;
        case 0x04: // PIC_GET_USER_CODE:
            qDebug() << "MainWindow::dataReceived() - Command received: PIC_GET_USER_CODE";
            commandGetUserCode();
            break;
        default:
            qDebug() << "MainWindow::dataReceived() - Unknown command: " << data[0];
            break;
    }
}

// Open the disc specified by the JSON filename
bool MainWindow::openDisc(QString jsonFilename) {
    if (!m_metadata.loadMetadata(jsonFilename)) {
        qDebug() << "MainWindow::openDisc() - Failed to load metadata for: " << jsonFilename;
        return false;
    }

    m_metadata.showMetadata();

    // Get the EFM data filename from the metadata
    QString efmDataFilename = m_metadata.getAivData();

    // The EFM data file is relative to the JSON file, so we need to extract the path
    QFileInfo jsonFileInfo(jsonFilename);
    efmDataFilename = jsonFileInfo.path() + "/" + efmDataFilename;

    if (!m_efmData.openEfmData(efmDataFilename)) {
        qDebug() << "MainWindow::openDisc() - Failed to open EFM data file: " << efmDataFilename;
        return false;
    }

    return true;
}

// Commands ---------------------------------------------------------------


void MainWindow::commandSetMountState(uint8_t state) {
    bool newState = (state == 0x01) ? true : false;
    if (m_mountState != newState) {
        m_mountState = newState;
        qDebug() << "MainWindow::commandSetMountState() - State: " << state;
        m_picoComs.writeData(QByteArray(1, 0x01));
    } else {
        qDebug() << "MainWindow::commandSetMountState() - State already set to: " << state;
        m_picoComs.writeData(QByteArray(1, 0x00));
    }
}

void MainWindow::commandGetMountState() {
    if (m_mountState == false) {
        qDebug() << "MainWindow::commandGetMountState() - EFM data is not mounted";
        m_picoComs.writeData(QByteArray(1, 0x00));
    } else {
        qDebug() << "MainWindow::commandGetMountState() - EFM data is mounted";
        m_picoComs.writeData(QByteArray(1, 0x01));
    }    
}

void MainWindow::commandGetEfmDataPresent() {
    if (m_efmData.hasEfmData()) {
        qDebug() << "MainWindow::commandGetEfmDataPresent() - EFM data is present";
        m_picoComs.writeData(QByteArray(1, 0x01));
    } else {
        qDebug() << "MainWindow::commandGetEfmDataPresent() - EFM data is not present";
        m_picoComs.writeData(QByteArray(1, 0x00));
    }
}

void MainWindow::commandGetUserCode() {
    QString userCode = m_metadata.getAivUserCode();
    qDebug() << "MainWindow::commandGetUserCode() - User code: " << userCode;
    m_picoComs.writeData(userCode.toUtf8());
}