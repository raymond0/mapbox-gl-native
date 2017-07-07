//
//  urt_tile.hpp
//  mbgl
//
//  Created by Ray Hunter on 29/11/2016.
//
//

#pragma once

class UrtTileData
{
public:
    UrtTileData( void *data, void *tilename );
    ~UrtTileData();
    void *maptilesPtr();
    void *tilenameNSString();
    
private:
    void *data;
    void *tilename;
};
