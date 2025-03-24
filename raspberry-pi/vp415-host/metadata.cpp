/************************************************************************

    metadata.cpp

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

#include "metadata.h"

Metadata::Metadata(QObject *parent) : QObject(parent) {
    m_dscDensityCode = 0;
    m_dscBlockSize = 0;
    m_dscListFormatCode = 0;
    m_dscCylinderCount = 0;
    m_dscDataHeadCount = 0;
    m_dscSectorsPerTrack = 0;
    m_dscReducedWriteCurrentCylinder = 0;
    m_dscWritePrecompensationCylinder = 0;
    m_dscLandingZonePosition = 0;
    m_dscStepPulseOutputRateCode = 0;

    m_aivDisplayName = "";
    m_aivVideo = "";
    m_aivData = "";
    m_aivDataOffset = 0;
    m_aivUserCode = "";
}

Metadata::~Metadata() {}

bool Metadata::loadMetadata(QString metadataFile) {
    QFile file(metadataFile);
    if (!file.open(QIODevice::ReadOnly)) {
        qDebug() << "Metadata::loadMetadata() - Failed to open metadata file: " << metadataFile;
        return false;
    }

    QByteArray data = file.readAll();
    file.close();

    QJsonDocument doc = QJsonDocument::fromJson(data);
    QJsonObject obj = doc.object();

    // Read the DSC section from the JSON data
    QJsonObject dsc = obj["dsc"].toObject();
    m_dscDensityCode = dsc["densityCode"].toInt();
    m_dscBlockSize = dsc["blockSize"].toInt();
    m_dscListFormatCode = dsc["listFormatCode"].toInt();
    m_dscCylinderCount = dsc["cylinderCount"].toInt();
    m_dscDataHeadCount = dsc["dataHeadCount"].toInt();
    m_dscSectorsPerTrack = dsc["sectorsPerTrack"].toInt();
    m_dscReducedWriteCurrentCylinder = dsc["reducedWriteCurrentCylinder"].toInt();
    m_dscWritePrecompensationCylinder = dsc["writePrecompensationCylinder"].toInt();
    m_dscLandingZonePosition = dsc["landingZonePosition"].toInt();
    m_dscStepPulseOutputRateCode = dsc["stepPulseOutputRateCode"].toInt();

    // Read the AIV section from the JSON data
    QJsonObject aiv = obj["aiv"].toObject();
    m_aivDisplayName = aiv["displayName"].toString();
    m_aivVideo = aiv["video"].toString();
    m_aivData = aiv["data"].toString();
    m_aivDataOffset = aiv["dataOffset"].toInt();
    m_aivUserCode = aiv["userCode"].toString();

    qDebug() << "Metadata::loadMetadata() - Metadata loaded successfully for" << m_aivDisplayName;

    return true;
}

// Show the metadata in the debug output
void Metadata::showMetadata() {
    qDebug() << "Metadata::showMetadata() - Metadata:";
    qDebug() << "  DSC:";
    qDebug() << "    Density Code: " << m_dscDensityCode;
    qDebug() << "    Block Size: " << m_dscBlockSize;
    qDebug() << "    List Format Code: " << m_dscListFormatCode;
    qDebug() << "    Cylinder Count: " << m_dscCylinderCount;
    qDebug() << "    Data Head Count: " << m_dscDataHeadCount;
    qDebug() << "    Sectors Per Track: " << m_dscSectorsPerTrack;
    qDebug() << "    Reduced Write Current Cylinder: " << m_dscReducedWriteCurrentCylinder;
    qDebug() << "    Write Precompensation Cylinder: " << m_dscWritePrecompensationCylinder;
    qDebug() << "    Landing Zone Position: " << m_dscLandingZonePosition;
    qDebug() << "    Step Pulse Output Rate Code: " << m_dscStepPulseOutputRateCode;
    qDebug() << "  AIV:";
    qDebug() << "    Display Name: " << m_aivDisplayName;
    qDebug() << "    Video: " << m_aivVideo;
    qDebug() << "    Data: " << m_aivData;
    qDebug() << "    Data Offset: " << m_aivDataOffset;
    qDebug() << "    User Code: " << m_aivUserCode;
}