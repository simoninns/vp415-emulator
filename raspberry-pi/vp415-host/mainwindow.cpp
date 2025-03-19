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

#include <QDebug>

#include "mainwindow.h"
#include "./ui_mainwindow.h"

// https://doc.qt.io/vscodeext/vscodeext-tutorials-qt-widgets.html

MainWindow::MainWindow(QWidget *parent)
    : QMainWindow(parent)
    , ui(new Ui::MainWindow)
{
    ui->setupUi(this);

    // Add a status bar
    statusBar = new QStatusBar();
    setStatusBar(statusBar);
    usb_device_detached();
}

MainWindow::~MainWindow()
{
    delete ui;
}

void MainWindow::on_pushButton_clicked()
{
    qDebug() << "Button clicked";
}

void MainWindow::usb_device_attached()
{
    qDebug() << "USB device attached";
    statusBar->showMessage("USB device ready");
}

void MainWindow::usb_device_detached()
{
    qDebug() << "USB device detached";
    statusBar->showMessage("No USB device attached");
}