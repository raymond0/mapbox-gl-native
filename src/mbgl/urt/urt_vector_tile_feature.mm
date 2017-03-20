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
            case type_poly_water_land_hole:
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
    
    rayclipper::rect rect = {region.minimum.coord, region.maximum.coord};
    auto outPolygons = RayClipPolygon( inputPolygon, rect );
    
    for ( auto &outPolygon : outPolygons )
    {
        auto localPolygon = ConvertToMapboxCoordinates( outPolygon );
        if ( localPolygon.size() >= 3 )
        {
            lines.emplace_back( localPolygon );
        }
    }
    
    return lines;
}
    
    
int UrtVectorTileFeature::PointInPolygon( const GeometryCoordinates &polygon, const GeometryCoordinate &coordinate ) const
{
    //returns 0 if false, +1 if true, -1 if coordinate ON polygon boundary
    int result = 0;
    size_t cnt = polygon.size();
    if (cnt < 3) return 0;
    GeometryCoordinate ip = polygon[0];
    
    for(size_t i = 1; i <= cnt; ++i)
    {
        GeometryCoordinate ipNext = (i == cnt ? polygon[0] : polygon[i]);
        if (ipNext.y == coordinate.y)
        {
            if ((ipNext.x == coordinate.x) || (ip.y == coordinate.y &&
                ((ipNext.x > coordinate.x) == (ip.x < coordinate.x)))) return -1;
        }
        if ((ip.y < coordinate.y) != (ipNext.y < coordinate.y))
        {
            if (ip.x >= coordinate.x)
            {
                if (ipNext.x > coordinate.x) result = 1 - result;
                else
                {
                    double d = (double)(ip.x - coordinate.x) * (ipNext.y - coordinate.y) -
                    (double)(ipNext.x - coordinate.x) * (ip.y - coordinate.y);
                    if (!d) return -1;
                    if ((d > 0) == (ipNext.y > ip.y)) result = 1 - result;
                }
            } else
            {
                if (ipNext.x > coordinate.x)
                {
                    double d = (double)(ip.x - coordinate.x) * (ipNext.y - coordinate.y) -
                    (double)(ipNext.x - coordinate.x) * (ip.y - coordinate.y);
                    if (!d) return -1;
                    if ((d > 0) == (ipNext.y > ip.y)) result = 1 - result;
                }
            }
        }
        ip = ipNext;
    } 
    return result;
}
    
typedef enum
{
    EdgeTop = 0,
    EdgeRight = 1,
    EdgeBottom = 2,
    EdgeLeft = 3,
    EdgeNotAnEdge = 4
} EdgeType;

    
EdgeType EdgeForCoord( const GeometryCoordinate &coord )
{
    if ( coord.x == 0 && coord.y == 0 )
    {
        return EdgeTop;
    }
    
    if ( coord.x == util::EXTENT && coord.y == 0 )
    {
        return EdgeRight;
    }

    if ( coord.x == util::EXTENT && coord.y == util::EXTENT )
    {
        return EdgeBottom;
    }
    
    if ( coord.x == 0 && coord.y == util::EXTENT )
    {
        return EdgeLeft;
    }
    
    if ( coord.y == 0 ) return EdgeTop;
    if ( coord.x == util::EXTENT ) return EdgeRight;
    if ( coord.y == util::EXTENT ) return EdgeBottom;
    if ( coord.x == 0 ) return EdgeLeft;
    
    //assert ( false );
    return EdgeNotAnEdge;    // Some compiler configs shout error otherwise
}
    
    
bool PointPreceedsOnEdge( EdgeType edge, GeometryCoordinate first, GeometryCoordinate second )
{
    switch ( edge )
    {
        case EdgeTop:
            assert( first.y == second.y );
            return first.x <= second.x;
        case EdgeRight:
            assert( first.x == second.x );
            return first.y <= second.y;
        case EdgeBottom:
            assert( first.y == second.y );
            return second.x <= first.x;
        case EdgeLeft:
            assert( first.x == second.x );
            return second.y <= first.y;
        case EdgeNotAnEdge:
            assert( false );
            return false;
    }
}
    
    
int IndexOfEdgeCoordinateInPolygon( const GeometryCoordinates &polygon, const GeometryCoordinate coordinate )
{
    assert ( EdgeForCoord( coordinate ) != EdgeNotAnEdge );
    
    EdgeType targetEdge = EdgeForCoord( coordinate );
    
    for ( size_t i = 0; i < polygon.size(); i++ )
    {
        const GeometryCoordinate &first = polygon[i];
        const GeometryCoordinate &second = polygon[(i == polygon.size() - 1) ? 0 : (i + 1)];

        // Both points must be on an edge, first point must be on targetEdge
        
        if ( EdgeForCoord( first ) == EdgeNotAnEdge )
        {
            continue;
        }
        
        if ( EdgeForCoord( second ) == EdgeNotAnEdge )
        {
            continue;
        }

        EdgeType firstEdge = EdgeForCoord( first );
        
        if ( firstEdge != targetEdge )
        {
            continue;
        }
        
        assert( firstEdge == targetEdge );
        
        if ( ! PointPreceedsOnEdge( targetEdge, first, coordinate) )
        {
            continue;
        }
        
        EdgeType secondEdge = EdgeForCoord( second );
        
        if ( secondEdge != targetEdge || PointPreceedsOnEdge(targetEdge, coordinate, second ) )
        {
            return (int) i;
        }
    }
    
    assert(false);
    return -1;
}
    

//
//  EmbedEdgeHolesIntoParent - Earcut seems to have bugs with holes that touch the boundaries. Also it's faster
//  for us to handle these here, as it's less work for earcut to do that otherwise (AFAICT).
//
void EmbedEdgeHolesIntoParent( GeometryCoordinates &parent, GeometryCollection &holes )
{
    for ( size_t holeIdx = 0; holeIdx < holes.size(); holeIdx++ )
    {
        auto &hole = holes[holeIdx];
        
        if ( EdgeForCoord( hole[0] ) == EdgeNotAnEdge )
        {
            continue;
        }
     
        int insertionIndex = IndexOfEdgeCoordinateInPolygon( parent, hole[0] );
        if ( insertionIndex == -1 )
        {
            printf("Parent polygon does not contain child polygon\n");
            continue;
        }
        
        int endInsertionIndex = IndexOfEdgeCoordinateInPolygon( parent, hole.back() );
        if ( endInsertionIndex == -1 )
        {
            printf("Parent polygon END does not contain child polygon, but start did???\n");
            continue;
        }

        if ( insertionIndex < endInsertionIndex )
        {
            // We cut 1+ corners
            __unused int nrCutCorners = endInsertionIndex - insertionIndex;
            assert( nrCutCorners < 4 );
            
            parent.erase( parent.begin() + insertionIndex + 1, parent.begin() + endInsertionIndex );
        }
        else if ( endInsertionIndex < insertionIndex )
        {
            // We're inserting over the start/end boundary of the parent while cutting corners
            size_t nrCutCornersEnd = parent.size() - insertionIndex - 1;
            size_t nrCutCornersStart = endInsertionIndex + 1;
            
            assert (nrCutCornersStart + nrCutCornersEnd < 4);
            assert (nrCutCornersStart > 0);
            
            if ( nrCutCornersEnd > 0 )
            {
                parent.erase( parent.begin() + insertionIndex + 1, parent.end() );
            }
            
            parent.erase( parent.begin(), parent.begin() + nrCutCornersStart );
        }
        
        //
        //  Remove corners if we are chopping off part of a rectangle. i.e. the top part in a rectangle that
        //  should render only the bottom part
        //
        while ( parent[insertionIndex] == hole.front() )
        {
            if ( parent.size() < 2 || hole.size() < 2 )
            {
                //
                // Will not happen with valid, corrently clipped data. Could blow up with bad data.
                //
                printf( "EmbedEdgeHolesIntoParent: Edge case for bad data handled\n" );
                break;
            }
            
            int nextParentIndex = insertionIndex > 0 ? insertionIndex - 1 : (int) parent.size() - 1;
            EdgeType parentNextEdge = EdgeForCoord( parent[nextParentIndex] );
            EdgeType holeNextEdge = EdgeForCoord( hole[1] );
            
            if ( parentNextEdge != holeNextEdge )
            {
                break;
            }
            
            parent.erase( parent.begin() + insertionIndex );
            hole.erase( hole.begin() );

            insertionIndex--;
            if ( insertionIndex < 0 ) insertionIndex = (int) parent.size() - 1;
        }
        
        parent.insert( parent.begin() + insertionIndex + 1, hole.begin(), hole.end() );
        
        holes.erase( holes.begin() + holeIdx );
        holeIdx--;
    }
}
    

void UrtVectorTileFeature::AssignHolesToOuterPolygons( const GeometryCollection &outerPolygons, const GeometryCollection &holes,
                                                       GeometryCollection &completed ) const
{
    vector<vector<int> > polygonHoles(outerPolygons.size());
    
    for ( int holeIdx = 0; holeIdx < (int) holes.size(); holeIdx++ )
    {
        auto &hole = holes[holeIdx];
        
        for ( size_t polygonIdx = 0; polygonIdx < outerPolygons.size(); polygonIdx++ )
        {
            int pointInPoly = PointInPolygon( outerPolygons[polygonIdx], hole[0] );
            
            if ( pointInPoly == -1 )
            {
                pointInPoly = PointInPolygon( outerPolygons[polygonIdx], hole[hole.size() / 2] );
            }
            
            if ( pointInPoly != 0 )
            {
                polygonHoles[polygonIdx].emplace_back(holeIdx);
                break;
            }
        }
    }
    
    for ( size_t polygonIdx = 0; polygonIdx < outerPolygons.size(); polygonIdx++ )
    {
        auto outer = outerPolygons[polygonIdx];
        GeometryCollection holesForOuter;
        
        for ( int holeIdx : polygonHoles[polygonIdx] )
        {
            holesForOuter.emplace_back( holes[holeIdx] );
        }
        
        EmbedEdgeHolesIntoParent( outer, holesForOuter );
        
        completed.emplace_back( outer );
        completed.insert( completed.end(), holesForOuter.begin(), holesForOuter.end() );
    }
}


GeometryCollection UrtVectorTileFeature::getGeometries() const
{
    //
    //  Should handle everything except roads
    //
    
    //
    //  Complex case - tile have been combined. We need to clip the item to the tile.
    //  If the item is a polygon, we could end up with multiple polygons. If there are holes,
    //  we need to clip those too. We also need to assign each hole to a polygon such that all
    //  polygons are followed by their reversed holes.
    //
    if ( mapItem.itemType >= type_area && fromProxyTile )
    {
        GeometryCollection outerPolygons = ClippedPolygonInLocalCoords(mapItem);        
        GeometryCollection holes;
        for ( MapItem *hole in mapItem.polygonHoles )
        {
            GeometryCollection holeLines = ClippedPolygonInLocalCoords(hole);
            for ( auto &holeLine : holeLines )
            {
                std::reverse(holeLine.begin(), holeLine.end());
                holes.emplace_back( holeLine );
            }
        }
        
        if ( outerPolygons.size() > 1 && holes.size() > 0 )
        {
            GeometryCollection lines;
            AssignHolesToOuterPolygons( outerPolygons, holes, lines );
            return lines;
        }
        else
        {
            EmbedEdgeHolesIntoParent( outerPolygons[0], holes ); // Calls AssignHolesToOuterPolygons
            outerPolygons.insert( outerPolygons.end(), holes.begin(), holes.end() );
            return outerPolygons;
        }
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

