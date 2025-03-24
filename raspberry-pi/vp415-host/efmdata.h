/************************************************************************

    efmdata.h

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

#ifndef EFM_DATA_H
#define EFM_DATA_H

#include <QObject>
#include <QFile>
#include <QByteArray>
#include <QDebug>

class EfmData : public QObject
{
    Q_OBJECT

public:
    explicit EfmData(QObject *parent = nullptr);
    ~EfmData();

    bool openEfmData(QString efmDataFilename);
    void closeEfmData();

    bool hasEfmData() const { return m_hasEfmData; }
    QByteArray getEfmSectorData(uint16_t sectorNumber) const;

private:
    bool m_hasEfmData;
    QByteArray m_efmData[256];
    QFile *m_efmFile;
};

#endif // EFM_DATA_H