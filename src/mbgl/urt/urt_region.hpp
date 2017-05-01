//
//  urt_region.hpp
//  mbgl
//
//  Created by Ray Hunter on 01/05/2017.
//
//

#pragma once

#include <stdio.h>
#include "UrtFile/UrtFile.h"

typedef struct URRegion
{
    coord minimum;
    coord maximum;
} URRegion;

URRegion URRegionMake( Region *region );
URRegion URRegionForTileName( const char *tilename );
bool URRegionContainsCoord( const URRegion &region, const coord &coord );
bool URRegionIntersectsLine( const URRegion &region, const coord &first, const coord &second );
void URRegionExpand( URRegion &region, const coord c );
coord URRegionCenter( const URRegion &region );


inline coord LocalCoordWithOrigin( const coord &globalCoord, const coord &origin )
{
    coord c;
    c.x = globalCoord.x - origin.x;
    c.y = globalCoord.y - origin.y;
    return c;
}
