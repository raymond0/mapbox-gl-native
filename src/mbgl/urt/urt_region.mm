//
//  urt_region.cpp
//  mbgl
//
//  Created by Ray Hunter on 01/05/2017.
//
//

#include "urt_region.hpp"

URRegion URRegionMake( Region *region )
{
    URRegion urregion = { region.minimum.coord, region.maximum.coord };
    return urregion;
}


URRegion URRegionForTileName( const char *tilename )
{
    coord c;
    coord min = WORLD_MIN;
    coord max = WORLD_MAX;
    
    while (*tilename)
    {
        c.x = (min.x + max.x) / 2;
        c.y = (min.y + max.y) / 2;
        
        switch (*tilename) {
            case 'a':
                min.x = c.x;
                min.y = c.y;
                break;
            case 'b':
                max.x = c.x;
                min.y = c.y;
                break;
            case 'c':
                min.x = c.x;
                max.y = c.y;
                break;
            case 'd':
                max.x = c.x;
                max.y = c.y;
                break;
        }
        tilename++;
    }
    
    URRegion urregion = { min, max };
    return urregion;
}


bool URRegionContainsCoord( const URRegion &region, const coord &coord )
{
    if ( coord.y < region.minimum.y ) { return false; }
    if ( coord.y > region.maximum.y ) { return false; }
    if ( coord.x < region.minimum.x ) { return false; }
    if ( coord.x > region.maximum.x ) { return false; }
    
    return true;
}


bool URRegionIntersectsLine( const URRegion &region, const coord &first, const coord &second )
{
    if ( first.x < region.minimum.x && second.x < region.minimum.x ) return false;
    if ( first.x > region.maximum.x && second.x > region.maximum.x ) return false;
    if ( first.y < region.minimum.y && second.y < region.minimum.y ) return false;
    if ( first.y > region.maximum.y && second.y > region.maximum.y ) return false;
    
    double dx = second.x - first.x;
    double dy = second.y - first.y;
    
    if ( dx != 0 )
    {
        // Left
        int32_t yIntersect = first.y + ( region.minimum.x - first.x ) *dy/dx;
        if ( region.minimum.y <= yIntersect && yIntersect <= region.maximum.y ) return true;
        
        // Right
        yIntersect = first.y + ( region.maximum.x - first.x ) *dy/dx;
        if ( region.minimum.y <= yIntersect && yIntersect <= region.maximum.y ) return true;
    }
    
    if ( dy != 0 )
    {
        // Top
        int32_t xIntersect = first.x + ( region.minimum.y - first.y ) *dx/dy;
        if ( region.minimum.x <= xIntersect && xIntersect <= region.maximum.x ) return true;
        
        // Bottom
        xIntersect = first.x + ( region.maximum.y - first.y ) *dx/dy;
        if ( region.minimum.x <= xIntersect && xIntersect <= region.maximum.x ) return true;
    }
    
    return false;
}


void URRegionExpand( URRegion &region, const coord c )
{
    if ( c.y < region.minimum.y )
    {
        region.minimum.y = c.y;
    }
    if ( c.x < region.minimum.x )
    {
        region.minimum.x = c.x;
    }
    if ( c.y > region.maximum.y )
    {
        region.maximum.y = c.y;
    }
    if ( c.x > region.maximum.x )
    {
        region.maximum.x = c.x;
    }
}


coord URRegionCenter( const URRegion &region )
{
    coord c = { ( region.minimum.x + region.maximum.x ) / 2, ( region.minimum.y + region.maximum.y ) / 2 };
    return c;
}
