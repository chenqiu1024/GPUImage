//
//  MadvMP4BoxParser.cpp
//  SimpleVideoFileFilter
//
//  Created by QiuDong on 2018/8/16.
//  Copyright © 2018年 Red Queen Coder, LLC. All rights reserved.
//

#include "MadvMP4BoxParser.hpp"

#include <ISOBMFF/ISOBMFF.h>
#import <MADVPanoFramework_macOS/MADVPanoFramework_macOS.h>
#include <iostream>
#include <fstream>
#include <cstring>
#include <stdlib.h>

inline int32_t readLittleEndianInt32(const void* ptr) {
    const uint8_t* bytes = (const uint8_t*)ptr;
    int32_t ret = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    return ret;
}

inline int32_t readBigEndianInt32(const void* ptr) {
    const uint8_t* bytes = (const uint8_t*)ptr;
    int32_t ret = bytes[3] | (bytes[2] << 8) | (bytes[1] << 16) | (bytes[0] << 24);
    return ret;
}

inline int16_t readLittleEndianInt16(const void* ptr) {
    const uint8_t* bytes = (const uint8_t*)ptr;
    int32_t ret = bytes[0] | (bytes[1] << 8);
    return (int16_t)ret;
}

inline int16_t readBigEndianInt16(const void* ptr) {
    const uint8_t* bytes = (const uint8_t*)ptr;
    int32_t ret = bytes[1] | (bytes[0] << 8);
    return (int16_t)ret;
}

void enumerateInBoxes(const void* data, int size, void(*callback)(void* context, uint32_t boxType, uint8_t* boxData, int boxSize, bool* stop), void* context);

void handleBox(void* context, uint32_t boxType, uint8_t* boxData, int boxSize, bool* stop);

void enumerateInBoxes(const void* data, int size, void(*callback)(void* context, uint32_t boxType, uint8_t* boxData, int boxSize, bool* stop), void* context) {
    bool stop = false;
    uint8_t* pRead = (uint8_t*)data;
    for (int iRead = 0; iRead < size;)
    {
        uint32_t* pReadInt = (uint32_t*)pRead;
        int boxSize = readBigEndianInt32(pReadInt++);
        uint32_t boxType = (uint32_t)readLittleEndianInt32(pReadInt++);
        
        if (NULL != callback)
        {
            callback(context, boxType, (uint8_t*)pReadInt, boxSize - 2 * (int)sizeof(uint32_t), &stop);
            if (stop)
                break;
        }
        
        pRead += boxSize;
        iRead += (2 * (int)sizeof(uint32_t) + boxSize);
    }
}

void handleBox(void* context, uint32_t boxType, uint8_t* boxData, int boxSize, bool* stop) {
    printf("boxType=0x%x, boxSize=%d, boxData=0x%lx, context=0x%lx\n", boxType, boxSize, (long)boxData, (long)context);
    MadvMP4Boxes* pBoxes = (MadvMP4Boxes*)context;
    *stop = false;
    switch (boxType)
    {
        case MADV_MP4_USERDATA_MADV:
            enumerateInBoxes(boxData, boxSize, handleBox, context);
            break;
        case MADV_MP4_USERDATA_TAG_TYPE:
            break;
        case MADV_MP4_USERDATA_BEAUTY_TYPE:
            break;
        case MADV_MP4_USERDATA_CAMERA_INFO_TYPE:
            break;
        case MADV_MP4_USERDATA_GPS_TYPE:
            break;
        case MADV_MP4_USERDATA_LUT_TYPE:
        {
            MADV_MP4_USERDATA_LUT_t* pLUTStruct = (MADV_MP4_USERDATA_LUT_t*)boxData;
            printf("LUT size = %d\n", pLUTStruct->size);
            if (pBoxes)
            {
                if (pBoxes->lutData) free(pBoxes->lutData);
                pBoxes->lutData = malloc(boxSize);
                memcpy(pBoxes->lutData, boxData, boxSize);
                pBoxes->lutDataSize = boxSize;
            }
        }
            break;
        case MADV_MP4_USERDATA_GYRO_TYPE:
            if (pBoxes && boxSize > 0 && NULL != boxData)
            {
                if (pBoxes->gyroData) free(pBoxes->gyroData);
                pBoxes->gyroData = malloc(boxSize);
                memcpy(pBoxes->gyroData, boxData, boxSize);
                pBoxes->gyroDataSize = boxSize;
            }
            break;
        default:
            break;
    }
}

using namespace ISOBMFF;

class CustomBox: public ISOBMFF::Box
{
public:
    
    CustomBox( void ): Box( "caif" )
    {}
    
    void ReadData( ISOBMFF::Parser & parser, ISOBMFF::BinaryStream & stream )
    {
        /* Read box data here... */
        std::cout << *(parser.GetFile()) << std::endl;
        stream.DeleteBytes(0);
    }
    
    std::vector< std::pair< std::string, std::string > > GetDisplayableProperties( void ) const
    {
        /* Returns box properties, to support output... */
        return {};
    }
};

MadvMP4Boxes* createMadvMP4Boxes(const char* mp4Path) {
    MadvMP4Boxes* pBoxes = new MadvMP4Boxes;
    pBoxes->gyroData = NULL;
    pBoxes->lutData = NULL;
    
    ISOBMFF::Parser parser;
    try
    {
        parser.AddOption( ISOBMFF::Parser::Options::SkipMDATData );
        parser.RegisterBox( "caif", [ = ]( void ) -> std::shared_ptr< CustomBox > { return std::make_shared< CustomBox >(); } );
        parser.Parse(mp4Path);
    }
    catch( const std::runtime_error & e )
    {
        std::cerr << e.what() << std::endl;
        return NULL;
    }
    
    std::shared_ptr< ISOBMFF::File > file = parser.GetFile();
    std::vector<std::shared_ptr< ISOBMFF::Box > > boxes = file->GetBoxes();
    for (std::shared_ptr< ISOBMFF::Box > box : boxes)
    {
        std::cout << "Box '" << box->GetName().c_str() << "': " << *box << std::endl;
        if (0 == strcmp(box->GetName().c_str(), "moov"))
        {
            ISOBMFF::ContainerBox* containerBox = static_cast<ISOBMFF::ContainerBox*>(box.get());
            std::vector< std::shared_ptr< Box > > subBoxes = containerBox->GetBoxes();
            for (std::shared_ptr< ISOBMFF::Box > subBox : subBoxes)
            {
                if (0 == strcmp(subBox->GetName().c_str(), "udta"))
                {
                    std::vector<uint8_t> userData = subBox->GetData();
                    int boxBytesSize = (int)userData.size();
                    std::cout << "udta length = " << boxBytesSize << std::endl;
                    enumerateInBoxes(userData.data(), boxBytesSize, handleBox, pBoxes);
                    return pBoxes;
                }
            }
        }
    }
    return pBoxes;
}

void releaseMadvMP4Boxes(MadvMP4Boxes* pBoxes) {
    if (!pBoxes) return;
    if (pBoxes->lutData)
    {
        free(pBoxes->lutData);
        pBoxes->lutData = NULL;
    }
    if (pBoxes->gyroData)
    {
        free(pBoxes->gyroData);
        pBoxes->gyroData = NULL;
    }
    delete pBoxes;
}
