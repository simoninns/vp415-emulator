/************************************************************************

    efmdata.cpp

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

#include "efmdata.h"

EfmData::EfmData(QObject *parent) : QObject(parent) {
    m_hasEfmData = false;
}

EfmData::~EfmData() {
    closeEfmData();
}

bool EfmData::openEfmData(QString efmDataFilename) {
    m_efmFile = new QFile(efmDataFilename);
    if (!m_efmFile->open(QIODevice::ReadOnly)) {
        qDebug() << "EfmData::loadEfmData() - Failed to open EFM data file: " << efmDataFilename;
        return false;
    }

    // Show the file size in debug (in sectors)
    qDebug() << "EfmData::loadEfmData() - Opened EFM data file" << efmDataFilename << "containing" << m_efmFile->size() / 256 << "sectors";

    m_hasEfmData = true;
    return true;
}

void EfmData::closeEfmData() {
    if (m_hasEfmData) {
        m_hasEfmData = false;
        m_efmFile->close();
        qDebug() << "EfmData::closeEfmData() - Closed EFM data file";
    }
}

QByteArray EfmData::getEfmSectorData(uint16_t sectorNumber) const {
    QByteArray efmSectorData;

    if (m_hasEfmData) {
        m_efmFile->seek(sectorNumber * 256);
        efmSectorData = m_efmFile->read(256);
    }

    return efmSectorData;
}