//
//  urt_tile.cpp
//  mbgl
//
//  Created by Ray Hunter on 29/11/2016.
//
//


#include "urt_tile_data.hpp"
#include <stdio.h>
#include <UrtFile/UrtFile.h>

UrtTileData::UrtTileData( void *data_, void *tilename_ )
{
    data = data_;
    tilename = tilename_;
}


UrtTileData::~UrtTileData()
{
    if ( data != NULL )
    {
        __unused NSArray *d = ( __bridge_transfer NSArray * ) data;
        data = NULL;
        
        //NSLog(@"Freeing %@", d);
    }


    if ( tilename != NULL )
    {
        __unused NSString *n = ( __bridge_transfer NSString * ) tilename;
        tilename = NULL;
        
        //NSLog(@"Freeing %@", n);
    }
}


void *UrtTileData::maptilesPtr()
{
    return data;
}


void *UrtTileData::tilenameNSString()
{
    return tilename;
}

