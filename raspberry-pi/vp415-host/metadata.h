/************************************************************************

    metadata.h

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

#ifndef METADATA_H
#define METADATA_H

#include <QObject>
#include <QString>
#include <QFile>
#include <QJsonObject>
#include <QByteArray>
#include <QJsonDocument>

class Metadata : public QObject
{
    Q_OBJECT

public:
    explicit Metadata(QObject *parent = nullptr);
    ~Metadata();

    bool loadMetadata(QString metadataFile);

    uint16_t getDscDensityCode() const { return m_dscDensityCode; }
    uint16_t getDscBlockSize() const { return m_dscBlockSize; }
    uint16_t getDscListFormatCode() const { return m_dscListFormatCode; }
    uint16_t getDscCylinderCount() const { return m_dscCylinderCount; }
    uint16_t getDscDataHeadCount() const { return m_dscDataHeadCount; }
    uint16_t getDscSectorsPerTrack() const { return m_dscSectorsPerTrack; }
    uint16_t getDscReducedWriteCurrentCylinder() const { return m_dscReducedWriteCurrentCylinder; }
    uint16_t getDscWritePrecompensationCylinder() const { return m_dscWritePrecompensationCylinder; }
    uint16_t getDscLandingZonePosition() const { return m_dscLandingZonePosition; }
    uint16_t getDscStepPulseOutputRateCode() const { return m_dscStepPulseOutputRateCode; }

    QString getAivDisplayName() const { return m_aivDisplayName; }
    QString getAivVideo() const { return m_aivVideo; }
    QString getAivData() const { return m_aivData; }
    uint16_t getAivDataOffset() const { return m_aivDataOffset; }
    QString getAivUserCode() const { return m_aivUserCode; }

    void showMetadata();

private:
    uint16_t m_dscDensityCode;
    uint16_t m_dscBlockSize;
    uint16_t m_dscListFormatCode;
    uint16_t m_dscCylinderCount;
    uint16_t m_dscDataHeadCount;
    uint16_t m_dscSectorsPerTrack;
    uint16_t m_dscReducedWriteCurrentCylinder;
    uint16_t m_dscWritePrecompensationCylinder;
    uint16_t m_dscLandingZonePosition;
    uint16_t m_dscStepPulseOutputRateCode;

    QString m_aivDisplayName;
    QString m_aivVideo;
    QString m_aivData;
    uint16_t m_aivDataOffset;
    QString m_aivUserCode;
};


#endif // METADATA_H