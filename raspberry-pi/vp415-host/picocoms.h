/************************************************************************

    picocoms.h

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

#ifndef PICOCOMS_H
#define PICOCOMS_H

#include <QObject>
#include <QString>
#include <QSerialPort>

class PicoComs : public QObject
{
    Q_OBJECT

public:
    explicit PicoComs(QObject *parent = nullptr);
    ~PicoComs();
    
    bool openSerialPort(QString serialPortDeviceName);
    void closeSerialPort();

    void writeData(QByteArray txData);

signals:
    void dataReceived(const QByteArray &data);

private slots:
    void readData();

private:
    bool m_isSerialPortOpen;
    QString m_serialPortName;
    QSerialPort *m_serialPort;
};

#endif // PICOCOMS_H