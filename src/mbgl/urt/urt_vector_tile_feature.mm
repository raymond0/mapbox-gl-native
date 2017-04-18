//
//  urt_vector_tile_feature.cpp
//  mbgl
//
//  Created by Ray Hunter on 09/12/2016.
//
//

#include "urt_vector_tile_feature.hpp"
#import <mbgl/util/constants.hpp>
#import "rayclipper.h"
#import <iostream>

namespace mbgl

{

UrtVectorTileFeature::MapboxTagsPtr UrtVectorTileFeature::GetMapboxTags() const
{
    auto classAndType = [=]() -> pair<string, string>
    {
        switch ( mapItem.itemType )
        {
            case type_poly_wood:
            case type_poly_park:
                return pair<string, string>("park", "garden");
            case type_poly_ocean:
            case type_poly_water:
            case type_poly_inner_hole:
#ifdef DENSITY_DEBUGGING
            case type_poly_debug_city_boundary:
#endif
                return pair<string, string>("", "");
            default:
                assert( false );
                return pair<string, string>("", "");
        }
    }();
    
    MapboxTagsPtr mapboxTags( new MapboxTags() );
    
    if ( classAndType.first.length() > 0 )
    {
        mapboxTags->insert({"class", (string) classAndType.first});
    }
    
    if ( classAndType.second.length() > 0 )
    {
        mapboxTags->insert({"type", (string) classAndType.second});
    }
    
    return mapboxTags;
}


UrtVectorTileFeature::UrtVectorTileFeature(MapItem *mapItem_, Region *region_, bool fromProxyTile_)
{
    properties = nullptr;
    mapItem = mapItem_;
    region = region_;
    fromProxyTile = fromProxyTile_;
}


unique_ptr<GeometryTileFeature> UrtVectorTileFeature::clone()
{
    auto other = make_unique<UrtVectorTileFeature>(mapItem, region, fromProxyTile);
    other->properties = GetMapboxTags();
    return move(other);
}


FeatureType UrtVectorTileFeature::getType() const
{
    assert ( mapItem.itemType >= type_area );
    return FeatureType::Polygon;
}


optional<Value> UrtVectorTileFeature::getValue(const std::string& key) const {
    if ( properties == nullptr )
    {
        return optional<Value>();
    }
    
    auto result = properties->find(key);
    if (result == properties->end()) {
        return optional<Value>();
    }
    
    return result->second;
}


std::unordered_map<std::string,Value> UrtVectorTileFeature::getProperties() const
{
    return *properties;
}


optional<FeatureIdentifier> UrtVectorTileFeature::getID() const
{
    return optional<FeatureIdentifier>();
}


vector<UrtVectorTileFeature::CoordRange> UrtVectorTileFeature::RelevantCoordinateRangesInTileRect( MapItem *item ) const
{
    vector<CoordRange> validRanges;
    coord *coords;
    NSInteger nrCoords = [item lengthOfCoordinatesWithData:&coords];
    
    if ( nrCoords == 1 )
    {
        if ( [region containsCoord:coords[0]] )
        {
            validRanges.emplace_back(CoordRange(0,1));
        }
        return validRanges;
    }
    
    bool currentlyValid = false;
    NSInteger segmentStart = 0;
    NSInteger segmentEnd = 0;
    
    for ( NSInteger i = 1; i < nrCoords; i++ )
    {
        if (  [region containsOrIntersetsFrom:coords[i-1] to:coords[i]] )
        {
            if ( currentlyValid )
            {
                segmentEnd = i;
            }
            else
            {
                segmentStart = i - 1;
                segmentEnd = i;
                currentlyValid = true;
            }
        }
        else
        {
            if ( currentlyValid )
            {
                validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1));
                
                currentlyValid = false;
            }
        }
    }
    
    if ( currentlyValid )
    {
        validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1));
        
        currentlyValid = false;
    }
    
    return validRanges;
}


GeometryCoordinates UrtVectorTileFeature::ConvertToMapboxCoordinates( const vector<coord> &globalCoords ) const
{
    Coordinate *origin = region.minimum;
    static const double extent = util::EXTENT;
    const double latExtent = region.height;
    const double lonExtent = region.width;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    GeometryCoordinates output;
    
    for ( const auto &coord : globalCoords )
    {
        struct coord localCoord = [origin localCoordinateFrom:coord];
        
        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        
        if ( output.size() > 0 )
        {
            if ( output.back().x == outputCoord.x &&  output.back().y == outputCoord.y )
            {
                continue;
            }
        }
        
        output.emplace_back( outputCoord );
    }
    
    return output;
}


GeometryCoordinates UrtVectorTileFeature::GetMapboxCoordinatesInRange( MapItem *item, CoordRange coordRange ) const
{
    Coordinate *origin = region.minimum;
    static const double extent = util::EXTENT;
    const double latExtent = region.height;
    const double lonExtent = region.width;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    coord *coords;
    __unused unsigned int nrCoords = (unsigned int) [item lengthOfCoordinatesWithData:&coords];
    
    GeometryCoordinates output;
    
    for ( uint32_t i = 0; i < coordRange.second; i++ )
    {
        assert( coordRange.first + i < nrCoords );
        coord localCoord = [origin localCoordinateFrom:coords[ coordRange.first + i ]];
        
        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        
        if ( i > 0 )
        {
            if ( output.back().x == outputCoord.x &&  output.back().y == outputCoord.y )
            {
                continue;
            }
        }
        
        output.emplace_back( outputCoord );
    }
    
    return output;
}


GeometryCollection UrtVectorTileFeature::ClippedPolygonInLocalCoords( MapItem *item ) const
{
    GeometryCollection lines;
    coord *coords = nil;
    NSInteger nrCoords = [item lengthOfCoordinatesWithData:&coords];
    
    rayclipper::Polygon inputPolygon;
    inputPolygon.resize( nrCoords );
    
    for ( NSInteger i = 0; i < nrCoords; i++ )
    {
        inputPolygon[i] = coords[i];
    }
    
    for ( MapItem *hole in mapItem.polygonHoles )
    {
        coord *holeCoords = nil;
        NSInteger nrHoleCoords = [hole lengthOfCoordinatesWithData:&holeCoords];

        rayclipper::Polygon polygonHole;
        polygonHole.resize( nrHoleCoords );
        for ( NSInteger i = 0; i < nrHoleCoords; i++ )
        {
            polygonHole[i] = holeCoords[i];
        }

        std::reverse(polygonHole.begin(), polygonHole.end());
        inputPolygon.holes.emplace_back( polygonHole );
    }
    
    rayclipper::rect rect = {region.minimum.coord, region.maximum.coord};
    vector<rayclipper::Polygon> outputPolygons;
    RayClipPolygon( inputPolygon, rect, outputPolygons );
    
    for ( auto &outPolygon : outputPolygons )
    {
        auto localPolygon = ConvertToMapboxCoordinates( outPolygon );
        
        if ( localPolygon.size() < 3 )
        {
            continue;
        }
        
        lines.emplace_back( localPolygon );
        
        for ( auto &hole : outPolygon.holes )
        {
            auto localHole = ConvertToMapboxCoordinates( hole );
            if ( localHole.size() < 3 )
            {
                continue;
            }
            
            lines.emplace_back( localHole );
        }

    }
    
    return lines;
}
    
    
void WriteMapItemCoords( MapItem *item, bool writeHoles, int nrHoles, FILE *fout )
{
    coord *coords = nil;
    int nrCoords = (int) [item lengthOfCoordinatesWithData:&coords];
    
    fwrite(&nrCoords, sizeof(int), 1, fout);
    if ( writeHoles )
    {
        fwrite(&nrHoles, sizeof(int), 1, fout);
    }
    
    fwrite(coords, sizeof(coord), nrCoords, fout);
    fflush(fout);
}
    
    
void WriteMapItem( rayclipper::rect rect, MapItem *mapItem )
{
    static FILE *fout = NULL;
    if ( fout == NULL )
    {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *basePath = paths.firstObject;
        NSString *fullPath = [basePath stringByAppendingPathComponent:@"DebugPolys.bin"];
        fout = fopen( fullPath.UTF8String, "wb" );
    }
    
    fwrite(&rect, sizeof(rect), 1, fout);
    
    WriteMapItemCoords(mapItem, true, (int) mapItem.polygonHoles.count, fout);
    
    for ( MapItem *hole in mapItem.polygonHoles )
    {
        WriteMapItemCoords(hole, false, 0, fout);
    }
}


GeometryCollection UrtVectorTileFeature::getGeometries() const
{
    //
    //  Should handle everything except roads
    //
    /*if ( mapItem.polygonHoles.count > 0 )
    {
        rayclipper::rect rect = {region.minimum.coord, region.maximum.coord};
        WriteMapItem( rect, mapItem);
    }*/
    
    //
    //  Complex case - tile have been combined. We need to clip the item to the tile.
    //  If the item is a polygon, we could end up with multiple polygons. If there are holes,
    //  we need to clip those too. We also need to assign each hole to a polygon such that all
    //  polygons are followed by their reversed holes.
    //
    if ( mapItem.itemType >= type_area && fromProxyTile )
    {
        GeometryCollection outerPolygons = ClippedPolygonInLocalCoords(mapItem);
        return outerPolygons;
    }
    
    //
    //  Simple case - 1 item, 0 or more holes (in case of a polygon). All holes belong to main item.
    //
    GeometryCollection lines;
    NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:nil];
    auto allUnclippedCoords = GetMapboxCoordinatesInRange( mapItem, CoordRange( 0, nrCoords ) );
    
    lines.emplace_back( allUnclippedCoords );
    
    for ( MapItem *hole in mapItem.polygonHoles )
    {
        NSInteger nrCoordsHole = [hole lengthOfCoordinatesWithData:nil];
        auto allUnclippedCoordsHole = GetMapboxCoordinatesInRange( hole, CoordRange( 0, nrCoordsHole ) );
        std::reverse(allUnclippedCoordsHole.begin(), allUnclippedCoordsHole.end());
        lines.emplace_back( allUnclippedCoordsHole );
    }
    
    return lines;
}
    
}

