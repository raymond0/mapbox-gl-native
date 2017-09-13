//
//  urt_vector_tile_water_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_water_feature.hpp"
#import <mbgl/util/constants.hpp> 

namespace mbgl {

UrtVectorTileWaterFeature::UrtVectorTileWaterFeature( URRegion region_ )
: mbgl::UrtVectorTileFeature( 0, region_, false )
{
    
}
    
    
void UrtVectorTileWaterFeature::addMapItem( MapItem *mapItem )
{
    geometryCollection = getGeometriesForMapItem(mapItem);
};



unique_ptr<GeometryTileFeature> UrtVectorTileWaterFeature::clone()
{
    auto other = make_unique<UrtVectorTileWaterFeature>( region );
    other->geometryCollection = geometryCollection;
    return move(other);
}


FeatureType UrtVectorTileWaterFeature::getType() const
{
    return FeatureType::Polygon;
}


bool PolygonMatchesExtent( const GeometryCoordinates &polygon )
{
    if ( polygon.size() != 4 )
    {
        return false;
    }
    
    size_t origin = SIZE_MAX;
    
    for ( size_t i = 0; i < 4; i++ )
    {
        if ( polygon[i].x == 0 && polygon[i].y == 0 )
        {
            origin = i;
            break;
        }
    }
    
    if ( origin == SIZE_MAX )
    {
        return false;
    }
    
    if ( polygon[(origin + 1) % 4].x != util::EXTENT || polygon[(origin + 1) % 4].y != 0 ||
        polygon[(origin + 2) % 4].x != util::EXTENT || polygon[(origin + 2) % 4].y != util::EXTENT ||
        polygon[(origin + 3) % 4].x != 0 || polygon[(origin + 3) % 4].y != util::EXTENT )
    {
        return false;
    }
    
    return true;
}

//#define DUMP_POLYGON_INFO
#ifdef DUMP_POLYGON_INFO

long long GeomArea(GeometryCoordinates c)
{
    long long area=0;
    size_t i,j=0;
    for ( i=0 ; i < c.size(); i++ )
    {
        if (++j == c.size())
            j=0;
        area+=(long long)(c[i].x+c[j].x)*(c[i].y-c[j].y);
    }
    return area/2;
}
#endif


GeometryCollection UrtVectorTileWaterFeature::getGeometries() const
{
    GeometryCollection lines;
    
    //
    //  Add a border of 1 all around the edge. Tangent edges on valid polygons *sometimes* blow
    //  something up further down the line without this, and invalidate all land areas.
    //  Docs do state we need to avoid tanget edges.
    //
    GeometryCoordinates line;
    line.emplace_back( GeometryCoordinate(0 ,0) );
    line.emplace_back( GeometryCoordinate(0,util::EXTENT) );
    line.emplace_back( GeometryCoordinate(util::EXTENT, util::EXTENT) );
    line.emplace_back( GeometryCoordinate(util::EXTENT, 0) );
    
    lines.emplace_back( line );
    
    //
    // NB - We no longer handle water/land areas like this. Maybe we should still use this method if land
    // is completely contained within the tile though?
    //
    return lines;
}
    
}
