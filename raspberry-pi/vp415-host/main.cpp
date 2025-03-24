/************************************************************************

    main.cpp

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

#include <QApplication>
#include <QDebug>
#include <QtGlobal>
#include <QCommandLineParser>

#include "mainwindow.h"

int main(int argc, char *argv[]) {
    QApplication app(argc, argv);

    // Set application name and version
    QCoreApplication::setApplicationName("vp415-host");
    QCoreApplication::setApplicationVersion(
            QString("Branch: %1 / Commit: %2").arg(APP_BRANCH, APP_COMMIT));
    QCoreApplication::setOrganizationDomain("domesday86.com");

    // Set up the command line parser
    QCommandLineParser parser;
    parser.setApplicationDescription(
            "vp415-host - VP415 Emulator host\n"
            "\n"
            "(c)2025 Simon Inns\n"
            "GPLv3 Open-Source - github: https://github.com/simoninns/efm-tools");
    parser.addHelpOption();
    parser.addVersionOption();

    // Add an option for specifying the JSON file of the initial disc to open
    QCommandLineOption jsonFileOption(QStringList() << "j" << "json",
        QCoreApplication::translate("main", "Specify the JSON file of the initial disc to open"),
        QCoreApplication::translate("main", "file"));
    parser.addOption(jsonFileOption);

    // -- Positional arguments --
    parser.addPositionalArgument("serialport",
        QCoreApplication::translate("main", "Specify serial port device to use"));
    
    // Process the command line options and arguments given by the user
    parser.process(app);

    // Get the JSON file argument from the parser
    QString jsonFilename = parser.value(jsonFileOption);

    // Get the filename arguments from the parser
    QString serialDeviceName;
    QStringList positionalArguments = parser.positionalArguments();

    if (positionalArguments.count() != 1) {
        qWarning() << "You must specify the serial device name";
        return 1;
    }
    serialDeviceName = positionalArguments.at(0);

    // Get on with the main window
    MainWindow mainWindow(nullptr, serialDeviceName, jsonFilename);
    mainWindow.show();

    return app.exec();
}
