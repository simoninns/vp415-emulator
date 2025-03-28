/************************************************************************

    mainwindow.h

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

#ifndef MAINWINDOW_H
#define MAINWINDOW_H

#include <QDebug>
#include <QMainWindow>
#include <QFileInfo>

#include "picocoms.h"
#include "metadata.h"
#include "efmdata.h"

QT_BEGIN_NAMESPACE
namespace Ui {
class MainWindow;
}
QT_END_NAMESPACE

class MainWindow : public QMainWindow {
    Q_OBJECT

public:
    MainWindow(QWidget *parent = nullptr, QString serialDeviceName = "", QString jsonFilename = "");
    ~MainWindow();

private slots:
    void on_pushButton_clicked();
    void commandReceived(const QByteArray &data);

private:
    Ui::MainWindow *ui;

    QStatusBar *statusBar;
    PicoComs m_picoComs;
    Metadata m_metadata;
    EfmData m_efmData;

    bool openDisc(QString jsonFilename);

    // Command variables
    bool m_mountState;

    // Commands
    void commandSetMountState(uint8_t state);
    void commandGetMountState();
    void commandGetEfmDataPresent();
    void commandGetUserCode();
};
#endif  // MAINWINDOW_H
