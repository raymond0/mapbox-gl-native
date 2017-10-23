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
        switch ( itemType )
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
    
    
UrtVectorTileFeature::UrtVectorTileFeature( unsigned int itemType_, URRegion region_, bool fromProxyTile_ )
{
    itemType = itemType_;
    region = region_;
    fromProxyTile = fromProxyTile_;
}
    
    
void UrtVectorTileFeature::addMapItem( MapItem *mapItem )
{
    geometryCollection = getGeometriesForMapItem(mapItem);
}

    
UrtVectorTileFeature::~UrtVectorTileFeature()
{

}
    

unique_ptr<GeometryTileFeature> UrtVectorTileFeature::clone()
{
    auto other = unique_ptr<UrtVectorTileFeature>(new UrtVectorTileFeature(itemType, region, fromProxyTile));
    other->properties = GetMapboxTags();
    other->geometryCollection = geometryCollection;
    return move(other);
}


FeatureType UrtVectorTileFeature::getType() const
{
    assert ( itemType >= type_area );
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
        if ( URRegionContainsCoord(region, coords[0]) )
        {
            validRanges.emplace_back(CoordRange(0,1,CoordRange::Internal));
        }
        return validRanges;
    }
    
    bool currentlyValid = false;
    NSInteger segmentStart = 0;
    NSInteger segmentEnd = 0;
    
    for ( NSInteger i = 1; i < nrCoords; i++ )
    {
        if (  URRegionContainsCoord( region, coords[i-1] ) || URRegionContainsCoord( region, coords[i] ) )
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
                validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1, CoordRange::Internal));
                
                currentlyValid = false;
            }
            else if ( URRegionIntersectsLine( region, coords[i-1], coords[i] ) )
            {
                validRanges.emplace_back(CoordRange(i-1, 2, CoordRange::Intersection));
            }
        }
    }
    
    if ( currentlyValid )
    {
        validRanges.emplace_back(CoordRange(segmentStart, segmentEnd - segmentStart + 1, CoordRange::Internal));
        
        currentlyValid = false;
    }
    
    return validRanges;
}
    
    
inline void AddGeometryCoordinate( GeometryCoordinates &output, GeometryCoordinate &outputCoord )
{
    if ( output.size() > 0 )
    {
        const auto &back = output.back();
        
        if ( back.x == outputCoord.x && back.y == outputCoord.y )
        {
            return;
        }
        
        if ( output.size() >= 2 )
        {
            const auto &penultimate = output[output.size() - 2];
            
            //
            //  Don't go somewhere to come back
            //
            if ( penultimate.x == outputCoord.x && penultimate.y == outputCoord.y )
            {
                output.pop_back();
                return;
            }
            
            //
            //  Multiple points sharing an axis should be reduced to first / last points
            //  on that access.
            //
            if ( ( penultimate.x == back.x && back.x == outputCoord.x ) ||
                 ( penultimate.y == back.y && back.y == outputCoord.y )    )
            {
                output[output.size() - 1] = outputCoord;
                
                //
                // back has just changed.
                // We are now looking at point a -> b -> a
                //
                if ( back == penultimate )
                {
                    output.pop_back();
                }
                
                return;
            }
        }
    }
    
    output.emplace_back( outputCoord );
}
    
    
inline void TidyEnds( GeometryCoordinates &output )
{
    //
    // Prune the front and back
    //
    while (output.size() >= 4)
    {
        const auto &first =       output[0];
        const auto &second =      output[1];
        const auto &penultimate = output[output.size() - 2];
        const auto &last =        output[output.size() - 1];
        
        if ( second.x == penultimate.x && second.y == penultimate.y &&
            first.x == last.x && first.y == last.y )
        {
            output.pop_back();
            output.erase(output.begin());
        }
        else
        {
            return;
        }
    }
}


GeometryCoordinates UrtVectorTileFeature::ConvertToMapboxCoordinates( const vector<coord> &globalCoords ) const
{
    static const double extent = util::EXTENT;
    const double latExtent = region.maximum.y - region.minimum.y;
    const double lonExtent = region.maximum.x - region.minimum.x;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    GeometryCoordinates output;
    
    for ( const auto &coord : globalCoords )
    {
        struct coord localCoord = LocalCoordWithOrigin( coord, region.minimum );
        
        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        AddGeometryCoordinate(output, outputCoord);
    }
    
    TidyEnds( output );
    return output;
}

    
GeometryCoordinates UrtVectorTileFeature::GetMapboxCoordinatesInRange( MapItem *item, CoordRange coordRange ) const
{
    GeometryCoordinates output;

    if ( coordRange.rangeType == CoordRange::Empty )
    {
        return output;
    }
    
    static const double extent = util::EXTENT;
    const double latExtent = region.maximum.y - region.minimum.y;
    const double lonExtent = region.maximum.x - region.minimum.x;
    
    const double latMultiplier = extent / latExtent;
    const double lonMultiplier = extent / lonExtent;
    
    coord *coords;
    __unused NSInteger nrCoords = [item lengthOfCoordinatesWithData:&coords];
    
    assert( coordRange.index + coordRange.length <= nrCoords );
    
    //
    //  Handle intersection case
    //
    if ( coordRange.rangeType == CoordRange::Intersection )
    {
        assert( coordRange.length == 2 );
        coord firstGlobalCoord = coords[ coordRange.index ];
        coord secondGlobalCoord = coords[ coordRange.index + 1 ];
        struct rayclipper::rect rect;
        rect.l = region.minimum;
        rect.h = region.maximum;
        rect.l.x -= 10;
        rect.l.y -= 10;     // Decent overlap so corners are not rounded off
        rect.h.x += 10;     // too soon.
        rect.h.y += 10;
        
        auto intersections = rayclipper::LineClippedToRect(firstGlobalCoord, secondGlobalCoord, rect);
        assert( intersections.size() == 2 );
        coord firstLocal = LocalCoordWithOrigin( intersections[0], region.minimum );
        coord secondLocal = LocalCoordWithOrigin( intersections[1], region.minimum );
        
        double firstTileX = ((double) firstLocal.x ) * lonMultiplier;
        double firstTileY = ((double) firstLocal.y ) * latMultiplier;
        output.emplace_back( GeometryCoordinate( firstTileX, extent - firstTileY ) );
        
        double secondTileX = ((double) secondLocal.x ) * lonMultiplier;
        double secondTileY = ((double) secondLocal.y ) * latMultiplier;
        output.emplace_back( GeometryCoordinate ( secondTileX, extent - secondTileY ) );

        return output;
    }
    
    //
    //  Points inside, first and last might not be
    //
    assert( coordRange.rangeType == CoordRange::Internal );
    for ( NSInteger i = 0; i < coordRange.length; i++ )
    {
        assert( coordRange.index + i < nrCoords );
        coord localCoord = LocalCoordWithOrigin( coords[ coordRange.index + i ], region.minimum );
        
        double tileX = ((double) localCoord.x ) * lonMultiplier;
        double tileY = ((double) localCoord.y ) * latMultiplier;
        
        while ( tileX <= -extent || tileX >= (extent * 2.0) || tileY <= -extent || tileY >= (extent * 2.0) )
        {
            assert( coordRange.length > 1 );
            assert ( i == 0 || i == coordRange.length - 1 );
            NSInteger adjacentIndex = i == 0 ? 1 : coordRange.length - 2;
            coord adjacentCoord = LocalCoordWithOrigin( coords[ coordRange.index + adjacentIndex ], region.minimum );

            double adjacentTileX = ((double) adjacentCoord.x ) * lonMultiplier;
            double adjacentTileY = ((double) adjacentCoord.y ) * latMultiplier;
            
            assert( 0 <= adjacentTileX && adjacentTileX <= extent && 0 <= adjacentTileY && adjacentTileY <= extent );
            
            tileX = ( tileX + adjacentTileX ) / 2.0;
            tileY = ( tileY + adjacentTileY ) / 2.0;
        }
        
        GeometryCoordinate outputCoord( tileX, extent - tileY );
        AddGeometryCoordinate( output, outputCoord );
    }
    
    TidyEnds( output );
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
    
    for ( MapItem *hole in item.polygonHoles )
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
    
    rayclipper::rect rect = {region.minimum, region.maximum};
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
    return geometryCollection;
}


GeometryCollection UrtVectorTileFeature::getGeometriesForMapItem(MapItem *mapItem) const
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
    if ( mapItem.itemType >= type_area )
    {
        if (  fromProxyTile )
        {
            GeometryCollection outerPolygons = ClippedPolygonInLocalCoords(mapItem);
            return outerPolygons;
        }
        else
        {
            //
            //  Simple case - 1 item, 0 or more holes (in case of a polygon). All holes belong to main item.
            //
            GeometryCollection lines;
            NSInteger nrCoords = [mapItem lengthOfCoordinatesWithData:nil];
            auto allUnclippedCoords = GetMapboxCoordinatesInRange( mapItem, CoordRange( 0, nrCoords, CoordRange::Internal ) );
            
            lines.emplace_back( allUnclippedCoords );
            
            for ( MapItem *hole in mapItem.polygonHoles )
            {
                NSInteger nrCoordsHole = [hole lengthOfCoordinatesWithData:nil];
                auto allUnclippedCoordsHole = GetMapboxCoordinatesInRange( hole, CoordRange( 0, nrCoordsHole, CoordRange::Internal ) );
                std::reverse(allUnclippedCoordsHole.begin(), allUnclippedCoordsHole.end());
                lines.emplace_back( allUnclippedCoordsHole );
            }

            return lines;
        }
    }
    
    
    auto coordinateRanges = RelevantCoordinateRangesInTileRect( mapItem );
    
    GeometryCollection lines;
    for ( auto range : coordinateRanges )
    {
        auto coords = GetMapboxCoordinatesInRange( mapItem, range );
        lines.emplace_back( coords );
    }
    
    return lines;
}
    
}
