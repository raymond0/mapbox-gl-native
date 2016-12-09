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

UrtVectorTileWaterFeature::UrtVectorTileWaterFeature( Region *region_ )
: mbgl::UrtVectorTileFeature( NULL, region_, false )
{
    
}


unique_ptr<GeometryTileFeature> UrtVectorTileWaterFeature::clone()
{
    auto other = make_unique<UrtVectorTileWaterFeature>( region );
    other->landAreas = landAreas;
    other->waterAreas = waterAreas;
    return move(other);
}


void UrtVectorTileWaterFeature::addLandArea( MapItem *landArea, bool fromProxyTile )
{
    landAreas.emplace_back( landArea, fromProxyTile );
}


void UrtVectorTileWaterFeature::addWaterAreas( vector<pair<MapItem *, bool> >::iterator first, vector<pair<MapItem *, bool> >::iterator last )
{
    waterAreas.insert( waterAreas.end(), first, last );
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


/*long long GeomArea(GeometryCoordinates c)
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
 }*/


GeometryCollection UrtVectorTileWaterFeature::getGeometries() const
{
    GeometryCollection lines;
    
    //
    //  Add a border of 1 all around the edge. Tangent edges on valid polygons *sometimes* blow
    //  something up further down the line without this, and invalidate all land areas.
    //  Docs do state we need to avoid tanget edges.
    //
    GeometryCoordinates line;
    line.emplace_back( GeometryCoordinate(0 - 1,0 - 1) );
    line.emplace_back( GeometryCoordinate(0 - 1,util::EXTENT + 1) );
    line.emplace_back( GeometryCoordinate(util::EXTENT + 1, util::EXTENT + 1) );
    line.emplace_back( GeometryCoordinate(util::EXTENT + 1, 0 - 1) );
    
    lines.emplace_back( line );
    if ( landAreas.size() == 0 )
        return lines;
    
    bool totalLandCoverage = false;
    
    for ( auto &landArea : landAreas )
    {
        if ( totalLandCoverage )
        {
            break;
        }
        
        if ( landArea.second )      // Is proxy tile
        {
            GeometryCollection clippedPolyResults = ClippedPolygonInLocalCoords(landArea.first);
            for ( auto &poly : clippedPolyResults )
            {
                assert( poly.size() >= 3 );
                
                if ( poly.size() == 4 )
                {
                    if ( PolygonMatchesExtent( poly ) )
                    {
                        totalLandCoverage = true;
                        lines.clear();
                        break;
                    }
                }
                
                if ( poly.front() != poly.back() )
                {
                    poly.emplace_back(poly.front());
                }
                
                lines.emplace_back( poly );
            }
        }
        else
        {
            NSInteger nrCoords = [landArea.first lengthOfCoordinatesWithData:nil];
            GeometryCoordinates landCoords = GetMapboxCoordinatesInRange( landArea.first, CoordRange( 0, nrCoords ) );
            
            if ( landCoords.size() < 3 )
            {
                continue;
            }
            
            lines.emplace_back( landCoords );
        }
    }
    
    
    for ( auto &waterArea : waterAreas )
    {
        if ( waterArea.second )      // Is proxy tile
        {
            GeometryCollection clippedPolyResults = ClippedPolygonInLocalCoords(waterArea.first);
            for ( auto &poly : clippedPolyResults )
            {
                assert( poly.size() >= 3 );
                reverse( poly.begin(), poly.end() );
            }
            
            if ( clippedPolyResults.size() > 0 )
            {
                lines.insert( lines.end(), clippedPolyResults.begin(), clippedPolyResults.end() );
            }
        }
        else
        {
            NSInteger nrCoords = [waterArea.first lengthOfCoordinatesWithData:nil];
            GeometryCoordinates polyCoords = GetMapboxCoordinatesInRange( waterArea.first, CoordRange( 0, nrCoords ) );
            if ( polyCoords.size() < 3 )
            {
                continue;
            }
            reverse( polyCoords.begin(), polyCoords.end() );
            lines.emplace_back( polyCoords );
        }
    }
    
#ifdef DUMP_POLYGON_INFO
    printf("========== Land Polygons start ==========\n");
    
    for ( auto &polygon : lines )
    {
        printf("---------- Land Polygon start ---------- Area: %lld\n", GeomArea(polygon));
        for ( auto &coord : polygon )
        {
            printf( "Coord: %d, %d\n", coord.x, coord.y );
        }
    }
#endif
    
    
#ifdef DUMP_POLYGON_INTERSECTIONS
    for ( size_t i = lines.size() - 1; i > 0; i-- )
    {
        auto &firstPolygonCoords = lines[i];
        vector<coord> firstPolygon;
        
        for ( auto c : firstPolygonCoords )
        {
            struct coord coord = { c.x, c.y };
            firstPolygon.emplace_back(coord);
        }
        
        for ( size_t j = i -1; j > 1; j-- )
        {
            auto &secondPolygon = lines[j];
            
            for ( auto &testCoord : secondPolygon )
            {
                struct coord coord = { testCoord.x, testCoord.y };
                if ( rayclipper::PointIsInsidePolygon(firstPolygon, coord) )
                {
                    printf( "Intersection Coord: %d, %d\n", coord.x, coord.y );
                    //lines.erase( lines.begin() + j );
                    //j--;
                    //break;
                }
            }
        }
    }
#endif
    
    return lines;
}
    
}
